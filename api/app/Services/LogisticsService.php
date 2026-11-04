<?php

namespace App\Services;

use App\Models\Event;
use App\Models\EventRegistration as Reg;
use App\Models\EventRoom;
use App\Models\EventTravel;
use App\Models\EventVehicle;
use App\Models\MealServing;
use App\Models\MealSession;
use App\Models\RoomAllocation;
use App\Models\User;
use App\Support\ApiException;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;

class LogisticsService
{
    public function __construct(private EventService $events) {}

    /** Put a person in a room. Checks the room's gender rule and free beds under a lock. */
    public function allocate(Event $event, User $user, EventRoom $room): RoomAllocation
    {
        if (! $this->events->participantIds($event)->contains($user->id)) {
            throw new ApiException('NOT_PARTICIPANT', 'Only people coming to this event can be given a room.', 422);
        }
        $stay = $room->stay;
        if ($stay->event_id !== $event->id) {
            abort(404);
        }
        $gender = $user->profile?->gender;
        if ($stay->for_gender !== 'any' && $gender !== $stay->for_gender) {
            throw new ApiException('STAY_GENDER', "{$stay->name} is for ".($stay->for_gender === 'female' ? 'women' : 'men').' only.', 422);
        }

        return DB::transaction(function () use ($event, $user, $room) {
            $locked = EventRoom::whereKey($room->id)->lockForUpdate()->first();
            $taken = RoomAllocation::where('room_id', $locked->id)->where('user_id', '!=', $user->id)->whereNull('checked_out_at')->count();
            if ($taken >= $locked->capacity) {
                throw new ApiException('ROOM_FULL', "Room {$locked->name} is full.", 409);
            }

            return RoomAllocation::updateOrCreate(['event_id' => $event->id, 'user_id' => $user->id], ['room_id' => $locked->id, 'checked_in_at' => null, 'checked_out_at' => null]);
        });
    }

    /**
     * Give rooms to everyone who asked for a stay and has none, keeping people from
     * the same unit together and respecting each place's gender rule.
     *
     * @return array{allocated: int, left_without: array<int, string>}
     */
    public function autoAllocate(Event $event): array
    {
        $done = RoomAllocation::where('event_id', $event->id)->pluck('user_id');
        $waiting = EventTravel::where('event_id', $event->id)->where('needs_stay', true)->whereNotIn('user_id', $done)
            ->whereIn('user_id', $this->events->participantIds($event))
            ->with('user.profile')->get()
            ->sortBy(fn ($t) => ($t->user->profile?->org_unit_id ?? 0).'-'.$t->user->profile?->full_name)->values();

        $rooms = EventRoom::whereHas('stay', fn ($q) => $q->where('event_id', $event->id))->with('stay')->withCount([
            'allocations as used' => fn ($q) => $q->whereNull('checked_out_at'),
        ])->orderBy('stay_id')->orderBy('id')->get();

        $allocated = 0;
        $left = [];
        foreach ($waiting as $t) {
            $gender = $t->user->profile?->gender;
            $room = $rooms->first(fn ($r) => $r->used < $r->capacity && ($r->stay->for_gender === 'any' || $r->stay->for_gender === $gender));
            if (! $room) {
                $left[] = $t->user->profile?->full_name ?? $t->user->name;
                continue;
            }
            RoomAllocation::create(['event_id' => $event->id, 'room_id' => $room->id, 'user_id' => $t->user_id]);
            $room->used++;
            $allocated++;
        }

        return ['allocated' => $allocated, 'left_without' => $left];
    }

    /** Serve one meal per person per session. The database unique key is the final guard. */
    public function serve(User $staff, Event $event, MealSession $meal, string $token, ?string $counter): array
    {
        if ($meal->event_id !== $event->id) {
            abort(404);
        }
        $reg = $this->events->registrationFromToken($token)
            ?? throw new ApiException('PASS_INVALID', 'This is not a valid ABVP Connect event pass.', 422);
        if ($reg->event_id !== $event->id || $reg->status !== Reg::REGISTERED) {
            throw new ApiException('NOT_ENTITLED', 'This pass is not for this event, or the registration is not confirmed.', 422);
        }

        $existing = MealServing::where('meal_session_id', $meal->id)->where('user_id', $reg->user_id)->first();
        if (! $existing) {
            try {
                MealServing::create(['meal_session_id' => $meal->id, 'user_id' => $reg->user_id, 'served_by' => $staff->id, 'counter' => $counter, 'served_at' => now()]);

                return ['already' => false, 'name' => $reg->displayName(), 'kind' => $reg->kind, 'meal' => $meal->name];
            } catch (UniqueConstraintViolationException) {
                $existing = MealServing::where('meal_session_id', $meal->id)->where('user_id', $reg->user_id)->first();
            }
        }

        return ['already' => true, 'name' => $reg->displayName(), 'kind' => $reg->kind, 'meal' => $meal->name,
            'served_at' => $existing->served_at->toIso8601String(), 'counter' => $existing->counter];
    }

    public function assignVehicle(Event $event, EventVehicle $vehicle, array $travelIds): int
    {
        abort_unless($vehicle->event_id === $event->id, 404);

        return DB::transaction(function () use ($event, $vehicle, $travelIds) {
            $v = EventVehicle::whereKey($vehicle->id)->lockForUpdate()->first();
            $current = EventTravel::where('vehicle_id', $v->id)->whereNotIn('id', $travelIds)->count();
            if ($current + count($travelIds) > $v->capacity) {
                throw new ApiException('VEHICLE_FULL', "{$v->name} has ".max(0, $v->capacity - $current).' seats left.', 409);
            }

            return EventTravel::where('event_id', $event->id)->whereIn('id', $travelIds)
                ->update(['vehicle_id' => $v->id, 'pickup_status' => 'assigned']);
        });
    }
}
