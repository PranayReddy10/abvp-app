<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Event;
use App\Models\EventDuty;
use App\Models\EventStaff;
use App\Models\EventTravel;
use App\Models\LocationPoint;
use App\Models\LocationSession;
use App\Models\MealServing;
use App\Models\MealSession;
use App\Models\RoomAllocation;
use App\Models\User;
use App\Services\EventService;
use App\Services\LogisticsService;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/** Stay, food, transport and live location, as the participant sees them. */
class LogisticsController extends Controller
{
    public function __construct(private EventService $events, private LogisticsService $logistics) {}

    public function mine(Request $request, Event $event)
    {
        $user = $request->user();
        $this->guardParticipant($user, $event);

        $travel = EventTravel::where('event_id', $event->id)->where('user_id', $user->id)->with('vehicle')->first();
        $alloc = RoomAllocation::where('event_id', $event->id)->where('user_id', $user->id)->with('room.stay')->first();
        $served = MealServing::whereIn('meal_session_id', MealSession::where('event_id', $event->id)->select('id'))
            ->where('user_id', $user->id)->pluck('served_at', 'meal_session_id');

        return $this->ok([
            'travel' => $travel ? $this->presentTravel($travel) : null,
            'stay' => $alloc ? [
                'place' => $alloc->room->stay->name,
                'address' => $alloc->room->stay->address,
                'map_url' => $alloc->room->stay->map_url,
                'room' => $alloc->room->name,
                'checked_in' => $alloc->checked_in_at !== null,
            ] : null,
            'vehicle' => $travel?->vehicle ? [
                'name' => $travel->vehicle->name,
                'pickup_point' => $travel->vehicle->pickup_point,
                'departs_at' => $travel->vehicle->departs_at?->toIso8601String(),
                'driver_name' => $travel->vehicle->driver_name,
                'driver_phone' => $travel->vehicle->driver_phone,
                'picked_up' => $travel->pickup_status === 'picked_up',
            ] : null,
            'meals' => MealSession::where('event_id', $event->id)->orderBy('starts_at')->get()->map(fn ($m) => [
                'id' => $m->id,
                'name' => $m->name,
                'starts_at' => $m->starts_at->toIso8601String(),
                'ends_at' => $m->ends_at->toIso8601String(),
                'location' => $m->location,
                'served_at' => isset($served[$m->id]) ? Carbon::parse($served[$m->id])->toIso8601String() : null,
            ]),
            'location_session' => $this->activeSession($user, $event),
        ]);
    }

    public function saveTravel(Request $request, Event $event)
    {
        $data = $request->validate([
            'mode' => ['required', 'in:train,bus,flight,own,other'],
            'reference' => ['nullable', 'string', 'max:60'],
            'arriving_at' => ['nullable', 'date'],
            'arrival_point' => ['nullable', 'string', 'max:120'],
            'departing_at' => ['nullable', 'date'],
            'needs_pickup' => ['boolean'],
            'needs_stay' => ['boolean'],
            'notes' => ['nullable', 'string', 'max:300'],
        ]);
        $this->guardParticipant($request->user(), $event);
        foreach (['arriving_at', 'departing_at'] as $k) {
            if (! empty($data[$k])) {
                $data[$k] = Carbon::parse($data[$k])->utc();
            }
        }

        $travel = EventTravel::firstOrNew(['event_id' => $event->id, 'user_id' => $request->user()->id]);
        if (! ($data['needs_pickup'] ?? false) && $travel->pickup_status !== 'picked_up') {
            $data['vehicle_id'] = null;
            $data['pickup_status'] = 'none';
        }
        $travel->fill($data)->save();

        return $this->ok($this->presentTravel($travel->fresh('vehicle')));
    }

    // ---- Food counter (event staff) ----------------------------------------

    public function meals(Request $request, Event $event)
    {
        $this->guardStaff($request->user(), $event);

        return $this->ok(MealSession::where('event_id', $event->id)->withCount('servings')->orderBy('starts_at')->get()->map(fn ($m) => [
            'id' => $m->id, 'name' => $m->name, 'starts_at' => $m->starts_at->toIso8601String(), 'ends_at' => $m->ends_at->toIso8601String(),
            'location' => $m->location, 'served' => $m->servings_count,
            'is_now' => now()->between($m->starts_at->copy()->subMinutes(30), $m->ends_at),
        ]));
    }

    public function serve(Request $request, Event $event, MealSession $meal)
    {
        $data = $request->validate(['token' => ['required', 'string', 'max:100'], 'counter' => ['nullable', 'string', 'max:40']]);
        $this->guardStaff($request->user(), $event);

        return $this->ok($this->logistics->serve($request->user(), $event, $meal, $data['token'], $data['counter'] ?? null));
    }

    // ---- Live location (opt-in) ---------------------------------------------

    public function startSharing(Request $request, Event $event)
    {
        $data = $request->validate([
            'minutes' => ['required', 'integer', 'in:30,60,120,240'],
            'shared_with' => ['required', 'in:coordinators,team_lead'],
            'purpose' => ['required', 'string', 'max:160'],
        ]);
        $user = $request->user();
        $this->guardParticipant($user, $event);

        // One active share per person per event.
        LocationSession::where('user_id', $user->id)->where('event_id', $event->id)->whereNull('stopped_at')->update(['stopped_at' => now()]);
        LocationSession::create($data + ['user_id' => $user->id, 'event_id' => $event->id, 'expires_at' => now()->addMinutes($data['minutes'])]);

        return $this->ok($this->activeSession($user, $event), 201);
    }

    public function point(Request $request, LocationSession $session)
    {
        $data = $request->validate([
            'lat' => ['required', 'numeric', 'between:-90,90'],
            'lng' => ['required', 'numeric', 'between:-180,180'],
            'accuracy' => ['nullable', 'numeric', 'min:0', 'max:10000'],
        ]);
        if ($session->user_id !== $request->user()->id) {
            throw new ApiException('FORBIDDEN', 'Not your sharing session.', 403);
        }
        if (! $session->isActive()) {
            throw new ApiException('SHARING_ENDED', 'Location sharing has ended.', 410);
        }

        // At most one point a minute: enough for coordination, light on the server.
        $last = LocationPoint::where('location_session_id', $session->id)->max('recorded_at');
        if (! $last || Carbon::parse($last)->lt(now()->subSeconds(55))) {
            LocationPoint::create(['location_session_id' => $session->id, 'lat' => $data['lat'], 'lng' => $data['lng'],
                'accuracy_m' => isset($data['accuracy']) ? (int) min(65535, $data['accuracy']) : null, 'recorded_at' => now()]);
        }

        return $this->ok(['expires_at' => $session->expires_at->toIso8601String()]);
    }

    public function stopSharing(Request $request, LocationSession $session)
    {
        if ($session->user_id !== $request->user()->id) {
            throw new ApiException('FORBIDDEN', 'Not your sharing session.', 403);
        }
        $session->update(['stopped_at' => now()]);

        return $this->ok(['stopped' => true]);
    }

    /** Team leads see members of their teams who chose to share with their team lead. */
    public function teamLocations(Request $request, Event $event)
    {
        $memberIds = EventDuty::where('event_id', $event->id)->whereHas('team', fn ($q) => $q->where('lead_user_id', $request->user()->id))->pluck('assignee_id');
        if ($memberIds->isEmpty()) {
            throw new ApiException('NOT_TEAM_LEAD', 'You do not lead a team at this event.', 403);
        }

        return $this->ok(self::sharedLocations($event, 'team_lead', $memberIds));
    }

    public static function sharedLocations(Event $event, string $audience, $onlyUserIds = null): array
    {
        return LocationSession::where('event_id', $event->id)->where('shared_with', $audience)
            ->whereNull('stopped_at')->where('expires_at', '>', now())
            ->when($onlyUserIds, fn ($q) => $q->whereIn('user_id', $onlyUserIds))
            ->with('user.profile', 'points')->get()
            ->map(function (LocationSession $s) {
                $p = $s->points->first();

                return [
                    'name' => $s->user->profile?->full_name ?? $s->user->name,
                    'purpose' => $s->purpose,
                    'expires_at' => $s->expires_at->toIso8601String(),
                    'last_seen' => $p?->recorded_at->toIso8601String(),
                    'lat' => $p?->lat,
                    'lng' => $p?->lng,
                    'accuracy_m' => $p?->accuracy_m,
                    'map_url' => $p ? "https://www.google.com/maps/search/?api=1&query={$p->lat},{$p->lng}" : null,
                ];
            })->values()->all();
    }

    private function activeSession(User $user, Event $event): ?array
    {
        $s = LocationSession::where('user_id', $user->id)->where('event_id', $event->id)->whereNull('stopped_at')->where('expires_at', '>', now())->latest('id')->first();

        return $s ? ['id' => $s->id, 'shared_with' => $s->shared_with, 'purpose' => $s->purpose, 'expires_at' => $s->expires_at->toIso8601String()] : null;
    }

    private function presentTravel(EventTravel $t): array
    {
        return [
            'mode' => $t->mode, 'reference' => $t->reference,
            'arriving_at' => $t->arriving_at?->toIso8601String(), 'arrival_point' => $t->arrival_point,
            'departing_at' => $t->departing_at?->toIso8601String(),
            'needs_pickup' => $t->needs_pickup, 'needs_stay' => $t->needs_stay,
            'pickup_status' => $t->pickup_status, 'notes' => $t->notes,
        ];
    }

    private function guardParticipant(User $user, Event $event): void
    {
        if (! $this->events->participantIds($event)->contains($user->id) && ! $this->events->canCoordinate($user, $event)) {
            throw new ApiException('NOT_PARTICIPANT', 'This is for people taking part in the event.', 403);
        }
    }

    private function guardStaff(User $user, Event $event): void
    {
        if (! $this->events->canStaff($user, $event)) {
            throw new ApiException('NOT_EVENT_STAFF', 'You are not on the team for this event.', 403);
        }
    }
}
