<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\EventRegistration as Reg;
use App\Models\EventTravel;
use App\Models\GuideItem;
use App\Services\EventService;
use App\Support\ApiException;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Delegate registration for a big conference: anyone with an account fills one form with who
 * they are, how they arrive and whether they need a bed, and gets a pass.
 */
class DelegateController extends Controller
{
    public const MODES = ['train' => 'Train', 'bus' => 'Bus', 'flight' => 'Flight', 'own' => 'Own vehicle', 'other' => 'Other'];

    public const FOOD = ['veg' => 'Vegetarian', 'jain' => 'Jain (no onion, no garlic)', 'any' => 'No preference'];

    public function __construct(private EventService $events) {}

    public function show(Request $request, Event $event)
    {
        $this->open($event, forView: true);
        $user = $request->user();
        $reg = Reg::where('event_id', $event->id)->where('user_id', $user->id)->first();
        $travel = EventTravel::where('event_id', $event->id)->where('user_id', $user->id)->first();

        return $this->ok([
            'event' => ['id' => $event->id, 'title' => $event->title, 'venue' => $event->venue, 'starts_at' => $event->starts_at->toIso8601String(), 'ends_at' => $event->ends_at->toIso8601String()],
            'open' => $event->delegate_registration_open && $event->ends_at->isFuture(),
            'registration' => $reg && ! in_array($reg->status, [Reg::CANCELLED, Reg::REJECTED], true) ? $this->present($reg, $travel) : null,
            // Pre-fill from the sign-up details.
            'prefill' => ['full_name' => $user->profile?->full_name ?? $user->name, 'gender' => $user->profile?->gender ?? $user->gender, 'prant' => $user->prant, 'institution' => $user->profile?->institution ?? $user->institution],
            'options' => [
                'prants' => config('abvp.prants'),
                'arrival_points' => GuideItem::where('event_id', $event->id)->where('kind', 'arrival')->orderBy('sort')->pluck('title'),
                'modes' => collect(self::MODES)->map(fn ($l, $k) => ['key' => $k, 'label' => $l])->values(),
                'food' => collect(self::FOOD)->map(fn ($l, $k) => ['key' => $k, 'label' => $l])->values(),
            ],
        ]);
    }

    public function save(Request $request, Event $event)
    {
        $this->open($event);
        $data = $request->validate([
            'full_name' => ['required', 'string', 'min:2', 'max:100'],
            'gender' => ['required', 'in:male,female,other'],
            'prant' => ['required', 'string', 'max:80'],
            'institution' => ['nullable', 'string', 'max:150'],
            'food' => ['required', 'in:'.implode(',', array_keys(self::FOOD))],
            'emergency_name' => ['required', 'string', 'max:100'],
            'emergency_phone' => ['required', 'string', 'regex:/^[0-9+ -]{6,20}$/'],
            'mode' => ['required', 'in:'.implode(',', array_keys(self::MODES))],
            'reference' => ['nullable', 'string', 'max:60'],
            'arriving_at' => ['required', 'date'],
            'arrival_point' => ['required', 'string', 'max:120'],
            'departing_at' => ['nullable', 'date', 'after:arriving_at'],
            'needs_pickup' => ['required', 'boolean'],
            'needs_stay' => ['required', 'boolean'],
            'notes' => ['nullable', 'string', 'max:500'],
        ], [
            'emergency_phone.regex' => 'Enter a phone number with digits only.',
            'departing_at.after' => 'Departure must be after arrival.',
        ]);
        $user = $request->user();

        [$reg, $travel] = DB::transaction(function () use ($data, $event, $user) {
            $event = Event::whereKey($event->id)->lockForUpdate()->first();
            $reg = Reg::where('event_id', $event->id)->where('user_id', $user->id)->first();
            $isActive = $reg && in_array($reg->status, [Reg::REGISTERED, Reg::WAITLISTED, Reg::PENDING], true);

            if (! $isActive) {
                $full = $event->capacity !== null && $event->seatsTaken() >= $event->capacity;
                if ($full && ! $event->waitlist_enabled) {
                    throw new ApiException('EVENT_FULL', 'Delegate places are full. Please contact the helpline.', 409);
                }
                $reg ??= new Reg(['event_id' => $event->id, 'user_id' => $user->id]);
                $reg->kind = $reg->kind === 'member' && $reg->exists ? 'member' : 'delegate';
                $reg->status = $full ? Reg::WAITLISTED : Reg::REGISTERED;
            }
            $reg->guest_name = $data['full_name'];
            $reg->guest_organisation = $data['prant'];
            $reg->details = [
                'gender' => $data['gender'], 'prant' => $data['prant'], 'institution' => $data['institution'] ?? null,
                'food' => $data['food'], 'emergency_name' => $data['emergency_name'], 'emergency_phone' => $data['emergency_phone'],
            ];
            $reg->save();

            $travel = EventTravel::updateOrCreate(['event_id' => $event->id, 'user_id' => $user->id], [
                'mode' => $data['mode'], 'reference' => $data['reference'] ?? null,
                'arriving_at' => Carbon::parse($data['arriving_at'])->utc(), 'arrival_point' => $data['arrival_point'],
                'departing_at' => isset($data['departing_at']) ? Carbon::parse($data['departing_at'])->utc() : null,
                'needs_pickup' => $data['needs_pickup'], 'needs_stay' => $data['needs_stay'], 'notes' => $data['notes'] ?? null,
            ]);

            // Remember the basics for next time.
            foreach (['gender', 'prant', 'institution'] as $f) {
                if (empty($user->{$f}) && ! empty($data[$f])) {
                    $user->{$f} = $data[$f];
                }
            }
            if (empty($user->name)) {
                $user->name = $data['full_name'];
            }
            $user->save();

            return [$reg, $travel];
        });

        return $this->ok($this->present($reg->fresh(), $travel), $reg->wasRecentlyCreated ? 201 : 200);
    }

    public function cancel(Request $request, Event $event)
    {
        $reg = Reg::where('event_id', $event->id)->where('user_id', $request->user()->id)
            ->whereIn('status', [Reg::REGISTERED, Reg::WAITLISTED, Reg::PENDING])->first()
            ?? throw new ApiException('NOT_REGISTERED', 'You are not registered for this event.', 404);
        if ($reg->checked_in_at) {
            throw new ApiException('ALREADY_ARRIVED', 'You have already checked in at this event.');
        }
        $this->events->cancel($reg);

        return $this->ok(['cancelled' => true]);
    }

    private function present(Reg $reg, ?EventTravel $t): array
    {
        return [
            'id' => $reg->id,
            'status' => $reg->status,
            'kind' => $reg->kind,
            'full_name' => $reg->displayName(),
            'details' => $reg->details ?? [],
            'pass_token' => $reg->status === Reg::REGISTERED ? $this->events->passToken($reg) : null,
            'checked_in_at' => $reg->checked_in_at?->toIso8601String(),
            'travel' => $t ? [
                'mode' => $t->mode, 'reference' => $t->reference, 'arrival_point' => $t->arrival_point,
                'arriving_at' => $t->arriving_at?->toIso8601String(), 'departing_at' => $t->departing_at?->toIso8601String(),
                'needs_pickup' => $t->needs_pickup, 'needs_stay' => $t->needs_stay, 'notes' => $t->notes,
            ] : null,
        ];
    }

    private function open(Event $event, bool $forView = false): void
    {
        abort_unless($event->status === 'published', 404);
        if (! $forView && (! $event->delegate_registration_open || $event->ends_at->isPast())) {
            throw new ApiException('REGISTRATION_CLOSED', 'Delegate registration for this event is not open.', 403);
        }
    }
}
