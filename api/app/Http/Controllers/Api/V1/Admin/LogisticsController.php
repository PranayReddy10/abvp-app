<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\LogisticsController as MemberLogistics;
use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Event;
use App\Models\EventRoom;
use App\Models\EventStay;
use App\Models\EventTravel;
use App\Models\EventVehicle;
use App\Models\MealServing;
use App\Models\MealSession;
use App\Models\MemberProfile;
use App\Models\RoomAllocation;
use App\Models\User;
use App\Services\Audit;
use App\Services\EventService;
use App\Services\LogisticsService;
use App\Support\ApiException;
use App\Support\Mobile;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/** Coordinators: stay, food, transport, arrivals and shared locations for one event. */
class LogisticsController extends Controller
{
    public function __construct(private EventService $events, private LogisticsService $logistics) {}

    public function overview(Request $request, Event $event)
    {
        $this->guard($request, $event);
        $entitled = $this->events->participantIds($event)->count();

        $stays = EventStay::where('event_id', $event->id)->with('rooms.allocations.user.profile')->get();
        $needStay = EventTravel::where('event_id', $event->id)->where('needs_stay', true)->pluck('user_id');
        $allocated = RoomAllocation::where('event_id', $event->id)->pluck('user_id');

        return $this->ok([
            'participants' => $entitled,
            'stay' => [
                'beds' => $stays->sum(fn ($s) => $s->rooms->sum('capacity')),
                'allocated' => $allocated->count(),
                'checked_in' => RoomAllocation::where('event_id', $event->id)->whereNotNull('checked_in_at')->whereNull('checked_out_at')->count(),
                'waiting' => $needStay->diff($allocated)->count(),
                'places' => $stays->map(fn ($s) => [
                    'id' => $s->id, 'name' => $s->name, 'address' => $s->address, 'for_gender' => $s->for_gender,
                    'beds' => $s->rooms->sum('capacity'),
                    'used' => $s->rooms->sum(fn ($r) => $r->allocations->whereNull('checked_out_at')->count()),
                    'rooms' => $s->rooms->map(fn ($r) => [
                        'id' => $r->id, 'name' => $r->name, 'capacity' => $r->capacity,
                        'people' => $r->allocations->whereNull('checked_out_at')->values()->map(fn ($a) => [
                            'allocation_id' => $a->id, 'name' => $a->user->profile?->full_name ?? $a->user->name,
                            'member_id' => $a->user->profile?->member_id, 'checked_in' => $a->checked_in_at !== null,
                        ]),
                    ]),
                ]),
            ],
            'meals' => MealSession::where('event_id', $event->id)->withCount('servings')->orderBy('starts_at')->get()->map(fn ($m) => [
                'id' => $m->id, 'name' => $m->name, 'starts_at' => $m->starts_at->toIso8601String(), 'ends_at' => $m->ends_at->toIso8601String(),
                'location' => $m->location, 'served' => $m->servings_count, 'entitled' => $entitled,
            ]),
            'vehicles' => EventVehicle::where('event_id', $event->id)->withCount([
                'passengers', 'passengers as picked_up_count' => fn ($q) => $q->where('pickup_status', 'picked_up'),
            ])->orderBy('departs_at')->get()->map(fn ($v) => [
                'id' => $v->id, 'name' => $v->name, 'capacity' => $v->capacity, 'pickup_point' => $v->pickup_point,
                'departs_at' => $v->departs_at?->toIso8601String(), 'driver_name' => $v->driver_name, 'driver_phone' => $v->driver_phone,
                'passengers' => $v->passengers_count, 'picked_up' => $v->picked_up_count,
            ]),
            'travel' => [
                'submitted' => EventTravel::where('event_id', $event->id)->count(),
                'need_pickup' => EventTravel::where('event_id', $event->id)->where('needs_pickup', true)->count(),
                'pickup_unassigned' => EventTravel::where('event_id', $event->id)->where('needs_pickup', true)->whereNull('vehicle_id')->count(),
                'picked_up' => EventTravel::where('event_id', $event->id)->where('pickup_status', 'picked_up')->count(),
            ],
            'locations' => MemberLogistics::sharedLocations($event, 'coordinators'),
        ]);
    }

    // ---- Stay ----------------------------------------------------------------

    public function storeStay(Request $request, Event $event)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'address' => ['nullable', 'string', 'max:255'],
            'map_url' => ['nullable', 'url:https', 'max:500'],
            'for_gender' => ['required', 'in:any,female,male'],
            'room_prefix' => ['required', 'string', 'max:20'],
            'room_count' => ['required', 'integer', 'min:1', 'max:500'],
            'beds_per_room' => ['required', 'integer', 'min:1', 'max:200'],
        ]);
        $this->guard($request, $event);

        $stay = DB::transaction(function () use ($event, $data) {
            $stay = EventStay::create(['event_id' => $event->id] + collect($data)->only(['name', 'address', 'map_url', 'for_gender'])->all());
            for ($i = 1; $i <= $data['room_count']; $i++) {
                EventRoom::create(['stay_id' => $stay->id, 'name' => trim($data['room_prefix']).' '.$i, 'capacity' => $data['beds_per_room']]);
            }

            return $stay;
        });

        return $this->ok(['id' => $stay->id, 'beds' => $data['room_count'] * $data['beds_per_room']], 201);
    }

    public function deleteStay(Request $request, Event $event, EventStay $stay)
    {
        $this->guard($request, $event);
        abort_unless($stay->event_id === $event->id, 404);
        $stay->delete();

        return $this->ok(['deleted' => true]);
    }

    public function allocate(Request $request, Event $event, EventRoom $room)
    {
        $data = $request->validate(['member_id' => ['nullable', 'string'], 'mobile' => ['nullable', 'string']]);
        $this->guard($request, $event);
        $user = $this->findPerson($data);
        $alloc = $this->logistics->allocate($event, $user, $room->load('stay'));
        AppNotification::sendMany([$user->id], 'stay_allocated', "Your stay: {$room->stay->name}, room {$room->name}", $event->title, ['event_id' => $event->id]);

        return $this->ok(['allocation_id' => $alloc->id], 201);
    }

    public function autoAllocate(Request $request, Event $event)
    {
        $this->guard($request, $event);
        $before = RoomAllocation::where('event_id', $event->id)->pluck('user_id');
        $result = $this->logistics->autoAllocate($event);

        $new = RoomAllocation::where('event_id', $event->id)->whereNotIn('user_id', $before)->with('room.stay')->get();
        foreach ($new as $a) {
            AppNotification::sendMany([$a->user_id], 'stay_allocated', "Your stay: {$a->room->stay->name}, room {$a->room->name}", $event->title, ['event_id' => $event->id]);
        }
        Audit::record('stay.auto_allocated', $event, null, ['allocated' => $result['allocated'], 'left' => count($result['left_without'])]);

        return $this->ok($result);
    }

    public function stayAction(Request $request, Event $event, RoomAllocation $allocation)
    {
        $data = $request->validate(['action' => ['required', 'in:check_in,check_out,remove']]);
        $this->guard($request, $event);
        abort_unless($allocation->event_id === $event->id, 404);

        match ($data['action']) {
            'check_in' => $allocation->update(['checked_in_at' => now()]),
            'check_out' => $allocation->update(['checked_out_at' => now()]),
            'remove' => $allocation->delete(),
        };

        return $this->ok(['done' => $data['action']]);
    }

    // ---- Food ----------------------------------------------------------------

    public function storeMeal(Request $request, Event $event)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:60'],
            'starts_at' => ['required', 'date'],
            'ends_at' => ['required', 'date', 'after:starts_at'],
            'location' => ['nullable', 'string', 'max:120'],
        ]);
        $this->guard($request, $event);
        $m = MealSession::create(['event_id' => $event->id, 'name' => $data['name'], 'location' => $data['location'] ?? null,
            'starts_at' => Carbon::parse($data['starts_at'])->utc(), 'ends_at' => Carbon::parse($data['ends_at'])->utc()]);

        return $this->ok(['id' => $m->id], 201);
    }

    public function deleteMeal(Request $request, Event $event, MealSession $meal)
    {
        $this->guard($request, $event);
        abort_unless($meal->event_id === $event->id, 404);
        if (MealServing::where('meal_session_id', $meal->id)->exists()) {
            throw new ApiException('MEAL_STARTED', 'People have already been served in this session.');
        }
        $meal->delete();

        return $this->ok(['deleted' => true]);
    }

    // ---- Transport and arrivals ---------------------------------------------

    public function storeVehicle(Request $request, Event $event)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:60'],
            'capacity' => ['required', 'integer', 'min:1', 'max:200'],
            'pickup_point' => ['nullable', 'string', 'max:120'],
            'departs_at' => ['nullable', 'date'],
            'driver_name' => ['nullable', 'string', 'max:80'],
            'driver_phone' => ['nullable', 'string', 'max:20'],
        ]);
        $this->guard($request, $event);
        if (! empty($data['departs_at'])) {
            $data['departs_at'] = Carbon::parse($data['departs_at'])->utc();
        }
        $v = EventVehicle::create($data + ['event_id' => $event->id]);

        return $this->ok(['id' => $v->id], 201);
    }

    public function deleteVehicle(Request $request, Event $event, EventVehicle $vehicle)
    {
        $this->guard($request, $event);
        abort_unless($vehicle->event_id === $event->id, 404);
        EventTravel::where('vehicle_id', $vehicle->id)->update(['vehicle_id' => null, 'pickup_status' => 'none']);
        $vehicle->delete();

        return $this->ok(['deleted' => true]);
    }

    /** Who is arriving when and where, and whether their pickup is sorted. */
    public function arrivals(Request $request, Event $event)
    {
        $this->guard($request, $event);
        $request->validate(['filter' => ['nullable', 'in:need_pickup,unassigned,picked_up,need_stay']]);

        $rows = EventTravel::where('event_id', $event->id)->with('user.profile.orgUnit', 'vehicle')
            ->when($request->input('filter'), fn ($q, $f) => match ($f) {
                'need_pickup' => $q->where('needs_pickup', true),
                'unassigned' => $q->where('needs_pickup', true)->whereNull('vehicle_id'),
                'picked_up' => $q->where('pickup_status', 'picked_up'),
                'need_stay' => $q->where('needs_stay', true),
            })
            ->orderByRaw('arriving_at is null')->orderBy('arriving_at')->limit(500)->get();
        $rooms = RoomAllocation::where('event_id', $event->id)->with('room.stay')->get()->keyBy('user_id');

        return $this->ok($rows->map(fn (EventTravel $t) => [
            'id' => $t->id,
            'name' => $t->user->profile?->full_name ?? $t->user->name,
            'mobile' => $t->user->mobile,
            'from' => $t->user->profile?->orgUnit?->name,
            'mode' => $t->mode, 'reference' => $t->reference,
            'arriving_at' => $t->arriving_at?->toIso8601String(), 'arrival_point' => $t->arrival_point,
            'needs_pickup' => $t->needs_pickup, 'needs_stay' => $t->needs_stay,
            'vehicle' => $t->vehicle?->name, 'pickup_status' => $t->pickup_status,
            'room' => isset($rooms[$t->user_id]) ? $rooms[$t->user_id]->room->stay->name.' · '.$rooms[$t->user_id]->room->name : null,
            'notes' => $t->notes,
        ]));
    }

    public function assignVehicle(Request $request, Event $event)
    {
        $data = $request->validate(['vehicle_id' => ['required', 'integer'], 'travel_ids' => ['required', 'array', 'min:1', 'max:200'], 'travel_ids.*' => ['integer']]);
        $this->guard($request, $event);
        $vehicle = EventVehicle::findOrFail($data['vehicle_id']);
        $n = $this->logistics->assignVehicle($event, $vehicle, $data['travel_ids']);

        $users = EventTravel::whereIn('id', $data['travel_ids'])->pluck('user_id');
        AppNotification::sendMany($users, 'pickup_assigned', "Pickup: {$vehicle->name}",
            trim(($vehicle->pickup_point ? "At {$vehicle->pickup_point}" : '').($vehicle->departs_at ? ', '.$vehicle->departs_at->timezone('Asia/Kolkata')->format('D j M, g:i A') : '')), ['event_id' => $event->id]);

        return $this->ok(['assigned' => $n]);
    }

    public function pickedUp(Request $request, Event $event, EventTravel $travel)
    {
        $this->guard($request, $event);
        abort_unless($travel->event_id === $event->id, 404);
        $travel->update(['pickup_status' => 'picked_up', 'picked_up_at' => now()]);

        return $this->ok(['pickup_status' => 'picked_up']);
    }

    private function findPerson(array $data): User
    {
        if (! empty($data['member_id'])) {
            return MemberProfile::where('member_id', strtoupper(trim($data['member_id'])))->firstOrFail()->user;
        }
        $mobile = Mobile::normalize($data['mobile'] ?? '') ?? throw new ApiException('PERSON_REQUIRED', 'Give a Member ID, or a mobile number for guests.');

        return User::where('mobile', $mobile)->firstOrFail();
    }

    private function guard(Request $request, Event $event): void
    {
        if (! $this->events->canCoordinate($request->user(), $event)) {
            throw new ApiException('FORBIDDEN_SCOPE', 'Only coordinators of this event can do this.', 403);
        }
    }
}
