<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\EventRegistration as Reg;
use App\Models\User;
use App\Services\EventService;
use App\Support\ApiException;
use Illuminate\Http\Request;

/** Events as members and guests see them. */
class EventController extends Controller
{
    public function __construct(private EventService $events) {}

    public function index(Request $request)
    {
        $request->validate(['when' => ['nullable', 'in:upcoming,past'], 'mine' => ['nullable', 'boolean']]);
        $user = $request->user();
        $mineIds = Reg::where('user_id', $user->id)->where('status', '!=', Reg::CANCELLED)->pluck('event_id');

        $query = Event::whereIn('status', ['published', 'cancelled', 'completed'])
            ->with('orgUnit', 'rules.orgUnit', 'rules.vibhag')
            ->when($request->input('when', 'upcoming') === 'upcoming',
                fn ($q) => $q->where('ends_at', '>=', now())->orderBy('starts_at'),
                fn ($q) => $q->where('ends_at', '<', now())->orderByDesc('starts_at'));

        // Members see every published event; guests only the ones they were invited to.
        if (! $user->isApprovedMember() || $request->boolean('mine')) {
            $query->whereIn('id', $mineIds);
        } else {
            $query->where(fn ($q) => $q->where('status', 'published')->orWhereIn('id', $mineIds));
        }

        $regs = Reg::where('user_id', $user->id)->get()->keyBy('event_id');

        return $this->ok($query->limit(100)->get()->map(fn (Event $e) => $this->present($e, $user, $regs->get($e->id))));
    }

    public function show(Request $request, Event $event)
    {
        $user = $request->user();
        $reg = Reg::where('event_id', $event->id)->where('user_id', $user->id)->first();

        if ($event->status === 'draft' || (! $user->isApprovedMember() && ! $reg)) {
            throw new ApiException('NOT_FOUND', 'Not found.', 404);
        }

        return $this->ok($this->present($event, $user, $reg, true));
    }

    public function register(Request $request, Event $event)
    {
        $reg = $this->events->register($request->user(), $event);

        return $this->ok($this->present($event->fresh(), $request->user(), $reg, true), 201);
    }

    public function cancel(Request $request, Event $event)
    {
        $reg = Reg::where('event_id', $event->id)->where('user_id', $request->user()->id)
            ->whereNotIn('status', [Reg::CANCELLED, Reg::REJECTED])->first()
            ?? throw new ApiException('NOT_REGISTERED', 'You are not registered for this event.');

        if ($reg->checked_in_at) {
            throw new ApiException('ALREADY_ARRIVED', 'You have already checked in at this event.');
        }

        $this->events->cancel($reg);

        return $this->ok($this->present($event->fresh(), $request->user(), $reg->fresh(), true));
    }

    /** Every pass the person holds for events that have not ended. */
    public function passes(Request $request)
    {
        $regs = Reg::where('user_id', $request->user()->id)
            ->whereIn('status', [Reg::REGISTERED, Reg::WAITLISTED, Reg::PENDING])
            ->whereHas('event', fn ($q) => $q->where('status', 'published')->where('ends_at', '>=', now()))
            ->with('event.orgUnit')
            ->get()
            ->sortBy(fn ($r) => $r->event->starts_at)
            ->values();

        return $this->ok($regs->map(fn (Reg $r) => [
            'registration_id' => $r->id,
            'status' => $r->status,
            'kind' => $r->kind,
            'name' => $r->displayName(),
            'token' => $r->status === Reg::REGISTERED ? $this->events->passToken($r) : null,
            'checked_in_at' => $r->checked_in_at?->toIso8601String(),
            'event' => [
                'id' => $r->event->id,
                'title' => $r->event->title,
                'venue' => $r->event->venue,
                'starts_at' => $r->event->starts_at->toIso8601String(),
                'ends_at' => $r->event->ends_at->toIso8601String(),
                'instructions' => $r->event->instructions,
            ],
        ]));
    }

    public function present(Event $e, User $user, ?Reg $reg, bool $detail = false): array
    {
        [$eligible, $why] = $reg && $reg->kind === 'guest' ? [true, 'You are invited as a guest.'] : $this->events->eligibility($user, $e);
        $taken = $e->seatsTaken();
        $active = $reg && ! in_array($reg->status, [Reg::CANCELLED, Reg::REJECTED], true);

        $data = [
            'id' => $e->id,
            'title' => $e->title,
            'category' => $e->category,
            'category_label' => Event::CATEGORIES[$e->category] ?? $e->category,
            'starts_at' => $e->starts_at->toIso8601String(),
            'ends_at' => $e->ends_at->toIso8601String(),
            'venue' => $e->venue,
            'organised_by' => $e->orgUnit?->name,
            'status' => $e->status,
            'eligible' => $eligible,
            'eligibility' => $why,
            'registration_open' => $e->registrationOpen(),
            'registration_closes_at' => ($e->registration_closes_at ?? $e->starts_at)->toIso8601String(),
            'capacity' => $e->capacity,
            'seats_left' => $e->capacity === null ? null : max(0, $e->capacity - $taken),
            'registered_count' => $taken,
            'my_registration' => $reg ? [
                'status' => $reg->status,
                'kind' => $reg->kind,
                'checked_in_at' => $reg->checked_in_at?->toIso8601String(),
                'note' => $reg->decision_note,
            ] : null,
        ];

        if ($detail) {
            $data += [
                'description' => $e->description,
                'venue_map_url' => $e->venue_map_url,
                'requires_approval' => $e->requires_approval,
                // Instructions and the contact person are for people who are coming.
                'instructions' => $active ? $e->instructions : null,
                'contact' => $active && $e->contact_name ? ['name' => $e->contact_name, 'phone' => $e->contact_phone] : null,
                'waitlist_position' => $reg?->status === Reg::WAITLISTED
                    ? Reg::where('event_id', $e->id)->where('status', Reg::WAITLISTED)->where('id', '<=', $reg->id)->count()
                    : null,
            ];
        }

        return $data;
    }
}
