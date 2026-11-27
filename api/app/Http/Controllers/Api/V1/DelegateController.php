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

    /** Set by the admin panel: an admin may fill or change a delegate form even when registration is closed. */
    public bool $byAdmin = false;

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
            'prefill' => $this->prefill($user),
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
        // The app's form: surname, first name, mobile, email, gender, prant, responsibility, arrival,
        // departure and travel. The older website form (full name, food, emergency contact) still works.
        $new = $request->filled('first_name');
        $data = $request->validate([
            'first_name' => ['nullable', 'string', 'min:1', 'max:60'],
            'surname' => [$new ? 'required' : 'nullable', 'string', 'max:60'],
            'full_name' => [$new ? 'nullable' : 'required', 'string', 'min:2', 'max:100'],
            'mobile' => [$new ? 'required' : 'nullable', 'string', 'regex:/^[0-9+ -]{10,16}$/'],
            'email' => ['nullable', 'email', 'max:190'],
            'responsibility' => [$new ? 'required' : 'nullable', 'string', 'max:120'],
            'gender' => ['required', 'in:male,female,other'],
            'prant' => ['required', 'string', 'max:80'],
            'institution' => ['nullable', 'string', 'max:150'],
            'food' => [$new ? 'nullable' : 'required', 'in:'.implode(',', array_keys(self::FOOD))],
            'emergency_name' => [$new ? 'nullable' : 'required', 'string', 'max:100'],
            'emergency_phone' => [$new ? 'nullable' : 'required', 'string', 'regex:/^[0-9+ -]{6,20}$/'],
            'mode' => ['required', 'in:'.implode(',', array_keys(self::MODES))],
            'reference' => ['nullable', 'string', 'max:60'],
            'arriving_at' => ['required', 'date'],
            'arrival_point' => ['required', 'string', 'max:120'],
            'departing_at' => [$new ? 'required' : 'nullable', 'date', 'after:arriving_at'],
            'needs_pickup' => ['sometimes', 'boolean'],
            'needs_stay' => ['sometimes', 'boolean'],
            'notes' => ['nullable', 'string', 'max:500'],
        ], [
            'emergency_phone.regex' => 'Enter a phone number with digits only.',
            'mobile.regex' => 'Enter a valid mobile number.',
            'departing_at.after' => 'Departure must be after arrival.',
        ]);
        if ($new) {
            $data['full_name'] = trim($data['first_name'].' '.$data['surname']);
        }
        $data += ['needs_pickup' => false, 'needs_stay' => true];
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
                'first_name' => $data['first_name'] ?? null, 'surname' => $data['surname'] ?? null,
                'mobile' => $data['mobile'] ?? $user->mobile, 'email' => $data['email'] ?? null,
                'responsibility' => $data['responsibility'] ?? null,
                'gender' => $data['gender'], 'prant' => $data['prant'], 'institution' => $data['institution'] ?? null,
                'food' => $data['food'] ?? null, 'emergency_name' => $data['emergency_name'] ?? null, 'emergency_phone' => $data['emergency_phone'] ?? null,
            ];
            $reg->save();

            $travel = EventTravel::updateOrCreate(['event_id' => $event->id, 'user_id' => $user->id], [
                'mode' => $data['mode'], 'reference' => $data['reference'] ?? null,
                'arriving_at' => Carbon::parse($data['arriving_at'])->utc(), 'arrival_point' => $data['arrival_point'],
                'departing_at' => isset($data['departing_at']) ? Carbon::parse($data['departing_at'])->utc() : null,
                'needs_pickup' => $data['needs_pickup'], 'needs_stay' => $data['needs_stay'], 'notes' => $data['notes'] ?? null,
            ]);

            // Remember the basics for next time.
            foreach (['gender', 'prant', 'institution', 'email'] as $f) {
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

    /** Pre-fill from the account and profile; a saved form wins. */
    private function prefill(\App\Models\User $user): array
    {
        $name = trim((string) ($user->profile?->full_name ?: $user->name));
        $parts = preg_split('/\s+/', $name) ?: [];
        $surname = count($parts) > 1 ? array_pop($parts) : '';

        return [
            'full_name' => $name,
            'first_name' => implode(' ', $parts) ?: $name,
            'surname' => $surname,
            'mobile' => preg_replace('/^\+91/', '', (string) $user->mobile),
            'email' => $user->email,
            'gender' => $user->profile?->gender ?? $user->gender,
            'prant' => $user->prant ?? $user->profile?->orgUnit?->ancestorOfType('state')?->name,
            'institution' => $user->profile?->institution ?? $user->institution,
            'responsibility' => $user->responsibilities()->first()?->title ?? null,
        ];
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
        if (! $forView && ! $this->byAdmin && (! $event->delegate_registration_open || $event->ends_at->isPast())) {
            throw new ApiException('REGISTRATION_CLOSED', 'Delegate registration for this event is not open.', 403);
        }
    }
}
