<?php

namespace Tests\Feature;

use App\Models\Event;
use App\Models\EventRegistration;
use App\Models\EventRoom;
use App\Models\EventStaff;
use App\Models\EventTravel;
use App\Models\LocationPoint;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\RoleAssignment;
use App\Models\User;
use App\Services\EventService;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class LogisticsTest extends TestCase
{
    use RefreshDatabase;

    private int $seq = 0;
    private User $admin;
    private Event $event;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
        $this->admin = $this->member('Pranay', 'male', false);
        RoleAssignment::create(['user_id' => $this->admin->id, 'role' => 'state_admin', 'org_unit_id' => OrgUnit::where('name', 'Telangana')->value('id')]);
        $this->event = Event::create([
            'title' => 'Pranth Adhiveshan', 'category' => 'conference', 'venue' => 'Warangal',
            'starts_at' => now()->addDay()->setTime(3, 0), 'ends_at' => now()->addDays(3)->setTime(12, 0),
            'org_unit_id' => OrgUnit::where('name', 'Telangana')->value('id'), 'organiser_id' => $this->admin->id,
        ]);
        $this->event->forceFill(['status' => 'published'])->save();
    }

    private function member(string $name, ?string $gender = 'female', bool $registered = true): User
    {
        $this->seq++;
        $user = User::create(['mobile' => '+9198000'.str_pad((string) $this->seq, 5, '0', STR_PAD_LEFT)]);
        $p = new MemberProfile(['full_name' => $name, 'gender' => $gender, 'org_unit_id' => OrgUnit::where('name', 'Osmania University')->value('id')]);
        $p->user_id = $user->id;
        $p->member_id = 'M'.$this->seq;
        $p->membership_status = 'approved';
        $p->save();
        if ($registered) {
            EventRegistration::create(['event_id' => $this->event->id, 'user_id' => $user->id, 'status' => 'registered']);
        }

        return $user;
    }

    private function submitTravel(User $u, array $over = []): void
    {
        Sanctum::actingAs($u);
        $this->putJson("/api/v1/events/{$this->event->id}/travel", $over + [
            'mode' => 'train', 'reference' => '12723 Telangana Exp', 'arriving_at' => now()->addDay()->setTime(1, 0)->toIso8601String(),
            'arrival_point' => 'Warangal station', 'needs_pickup' => true, 'needs_stay' => true,
        ])->assertOk();
    }

    public function test_travel_details_and_arrivals_board_with_vehicle_capacity(): void
    {
        [$a, $b, $c] = [$this->member('Anusha'), $this->member('Sneha'), $this->member('Divya')];
        foreach ([$a, $b, $c] as $u) {
            $this->submitTravel($u);
        }
        Sanctum::actingAs($this->member('Outsider', 'male', false));
        $this->putJson("/api/v1/events/{$this->event->id}/travel", ['mode' => 'bus'])->assertStatus(403);

        Sanctum::actingAs($this->admin);
        $bus = $this->postJson("/api/v1/admin/events/{$this->event->id}/vehicles", ['name' => 'Bus 1', 'capacity' => 2, 'pickup_point' => 'Station exit 2', 'driver_name' => 'Ramesh', 'driver_phone' => '9876543210'])->json('data.id');
        $ids = EventTravel::pluck('id')->all();

        $this->getJson("/api/v1/admin/events/{$this->event->id}/arrivals?filter=unassigned")->assertJsonCount(3, 'data');
        $this->postJson("/api/v1/admin/events/{$this->event->id}/arrivals/assign", ['vehicle_id' => $bus, 'travel_ids' => $ids])->assertStatus(409)->assertJsonPath('error.code', 'VEHICLE_FULL');
        $this->postJson("/api/v1/admin/events/{$this->event->id}/arrivals/assign", ['vehicle_id' => $bus, 'travel_ids' => array_slice($ids, 0, 2)])->assertJsonPath('data.assigned', 2);
        $this->postJson("/api/v1/admin/events/{$this->event->id}/arrivals/{$ids[0]}/picked-up")->assertOk();
        $this->getJson("/api/v1/admin/events/{$this->event->id}/logistics")->assertJsonPath('data.travel.pickup_unassigned', 1)->assertJsonPath('data.vehicles.0.picked_up', 1);

        Sanctum::actingAs($b);
        $this->getJson("/api/v1/events/{$this->event->id}/my-logistics")
            ->assertJsonPath('data.vehicle.name', 'Bus 1')->assertJsonPath('data.vehicle.driver_phone', '9876543210');
    }

    public function test_rooms_respect_capacity_and_gender_and_auto_allocation_fills_them(): void
    {
        $women = [$this->member('Anusha'), $this->member('Sneha'), $this->member('Divya')];
        $man = $this->member('Ravi', 'male');
        foreach ([...$women, $man] as $u) {
            $this->submitTravel($u, ['needs_pickup' => false]);
        }

        Sanctum::actingAs($this->admin);
        $this->postJson("/api/v1/admin/events/{$this->event->id}/stays", ['name' => 'Girls Hostel 3', 'for_gender' => 'female', 'room_prefix' => 'G', 'room_count' => 1, 'beds_per_room' => 2])
            ->assertCreated()->assertJsonPath('data.beds', 2);
        $room = EventRoom::first();

        $this->postJson("/api/v1/admin/events/{$this->event->id}/rooms/{$room->id}/allocate", ['member_id' => $man->profile->member_id])->assertJsonPath('error.code', 'STAY_GENDER');
        $this->postJson("/api/v1/admin/events/{$this->event->id}/stays/auto-allocate")
            ->assertJsonPath('data.allocated', 2)->assertJsonCount(2, 'data.left_without');
        // Auto-allocation goes alphabetically within the unit: Anusha and Divya get the beds, Sneha does not.
        $this->postJson("/api/v1/admin/events/{$this->event->id}/rooms/{$room->id}/allocate", ['member_id' => $women[1]->profile->member_id])->assertStatus(409)->assertJsonPath('error.code', 'ROOM_FULL');

        $this->getJson("/api/v1/admin/events/{$this->event->id}/logistics")
            ->assertJsonPath('data.stay.allocated', 2)->assertJsonPath('data.stay.waiting', 2)->assertJsonCount(2, 'data.stay.places.0.rooms.0.people');

        Sanctum::actingAs($women[0]);
        $this->getJson("/api/v1/events/{$this->event->id}/my-logistics")->assertJsonPath('data.stay.place', 'Girls Hostel 3')->assertJsonPath('data.stay.room', 'G 1');
    }

    public function test_a_person_is_served_once_per_meal(): void
    {
        $a = $this->member('Anusha');
        $volunteer = $this->member('Food volunteer', 'male', false);
        EventStaff::create(['event_id' => $this->event->id, 'user_id' => $volunteer->id, 'role' => 'scanner']);
        $token = app(EventService::class)->passToken(EventRegistration::where('user_id', $a->id)->first());

        Sanctum::actingAs($this->admin);
        $lunch = $this->postJson("/api/v1/admin/events/{$this->event->id}/meal-sessions", [
            'name' => 'Day 1 Lunch', 'location' => 'Dining hall B',
            'starts_at' => now()->toIso8601String(), 'ends_at' => now()->addHours(2)->toIso8601String(),
        ])->json('data.id');

        Sanctum::actingAs($volunteer);
        $this->getJson("/api/v1/events/{$this->event->id}/meal-sessions")->assertJsonPath('data.0.is_now', true);
        $this->postJson("/api/v1/events/{$this->event->id}/meal-sessions/$lunch/serve", ['token' => $token, 'counter' => 'Counter 2'])
            ->assertJsonPath('data.already', false)->assertJsonPath('data.name', 'Anusha');
        $this->postJson("/api/v1/events/{$this->event->id}/meal-sessions/$lunch/serve", ['token' => $token])
            ->assertJsonPath('data.already', true)->assertJsonPath('data.counter', 'Counter 2');
        $this->postJson("/api/v1/events/{$this->event->id}/meal-sessions/$lunch/serve", ['token' => 'EP1.x.fake'])->assertJsonPath('error.code', 'PASS_INVALID');

        Sanctum::actingAs($a);
        $this->assertNotNull($this->getJson("/api/v1/events/{$this->event->id}/my-logistics")->json('data.meals.0.served_at'));
        $this->postJson("/api/v1/events/{$this->event->id}/meal-sessions/$lunch/serve", ['token' => $token])->assertStatus(403);
    }

    public function test_location_sharing_is_opt_in_time_limited_and_stoppable(): void
    {
        $a = $this->member('Anusha');
        $stranger = $this->member('Stranger');
        Sanctum::actingAs($a);

        $this->getJson("/api/v1/events/{$this->event->id}/my-logistics")->assertJsonPath('data.location_session', null);
        $sid = $this->postJson("/api/v1/events/{$this->event->id}/location-sessions", ['minutes' => 60, 'shared_with' => 'coordinators', 'purpose' => 'Travelling to venue by bus'])
            ->assertCreated()->json('data.id');
        $this->postJson("/api/v1/location-sessions/$sid/points", ['lat' => 17.9689, 'lng' => 79.5941, 'accuracy' => 25])->assertOk();
        $this->postJson("/api/v1/location-sessions/$sid/points", ['lat' => 17.97, 'lng' => 79.6])->assertOk();
        $this->assertSame(1, LocationPoint::count()); // at most one point a minute

        Sanctum::actingAs($stranger);
        $this->postJson("/api/v1/location-sessions/$sid/points", ['lat' => 1, 'lng' => 1])->assertStatus(403);
        $this->getJson("/api/v1/admin/events/{$this->event->id}/logistics")->assertStatus(403);

        Sanctum::actingAs($this->admin);
        $this->getJson("/api/v1/admin/events/{$this->event->id}/logistics")
            ->assertJsonPath('data.locations.0.name', 'Anusha')->assertJsonPath('data.locations.0.lat', 17.9689);

        Sanctum::actingAs($a);
        $this->postJson("/api/v1/location-sessions/$sid/stop")->assertOk();
        $this->postJson("/api/v1/location-sessions/$sid/points", ['lat' => 17.9, 'lng' => 79.5])->assertStatus(410);

        Sanctum::actingAs($this->admin);
        $this->getJson("/api/v1/admin/events/{$this->event->id}/logistics")->assertJsonCount(0, 'data.locations');

        $this->travelTo(now()->addDays(2));
        $this->artisan('abvp:prune-locations')->assertSuccessful();
        $this->assertSame(0, LocationPoint::count());
    }

    public function test_sharing_expires_on_its_own(): void
    {
        $a = $this->member('Anusha');
        Sanctum::actingAs($a);
        $sid = $this->postJson("/api/v1/events/{$this->event->id}/location-sessions", ['minutes' => 30, 'shared_with' => 'coordinators', 'purpose' => 'Lost near gate'])->json('data.id');

        $this->travelTo(now()->addMinutes(31));
        $this->postJson("/api/v1/location-sessions/$sid/points", ['lat' => 17.9, 'lng' => 79.5])->assertStatus(410)->assertJsonPath('error.code', 'SHARING_ENDED');
    }
}
