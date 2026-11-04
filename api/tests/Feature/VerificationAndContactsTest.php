<?php

namespace Tests\Feature;

use App\Models\AppNotification;
use App\Models\Event;
use App\Models\EventDuty;
use App\Models\EventRegistration;
use App\Models\EventTeam;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\RoleAssignment;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class VerificationAndContactsTest extends TestCase
{
    use RefreshDatabase;

    private int $seq = 0;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    private function member(string $name, string $unit = 'Osmania University'): User
    {
        $this->seq++;
        $user = User::create(['mobile' => '+9198000'.str_pad((string) $this->seq, 5, '0', STR_PAD_LEFT)]);
        $p = new MemberProfile(['full_name' => $name, 'org_unit_id' => OrgUnit::where('name', $unit)->value('id')]);
        $p->user_id = $user->id;
        $p->member_id = 'M'.$this->seq;
        $p->membership_status = 'approved';
        $p->save();

        return $user;
    }

    private function admin(string $role, string $unit): User
    {
        $u = $this->member("$role $unit");
        RoleAssignment::create(['user_id' => $u->id, 'role' => $role, 'org_unit_id' => OrgUnit::where('name', $unit)->value('id')]);

        return $u;
    }

    public function test_district_admin_verifies_and_badge_shows_everywhere(): void
    {
        $anusha = $this->member('Anusha');
        $viewer = $this->member('Viewer');

        Sanctum::actingAs($this->admin('verification_officer', 'Hyderabad'));
        $this->postJson("/api/v1/admin/members/{$anusha->profile->id}/verify", ['verified' => true])->assertStatus(403);

        Sanctum::actingAs($this->admin('district_admin', 'Warangal'));
        $this->postJson("/api/v1/admin/members/{$anusha->profile->id}/verify", ['verified' => true])->assertStatus(403);

        Sanctum::actingAs($this->admin('district_admin', 'Hyderabad'));
        $this->postJson("/api/v1/admin/members/{$anusha->profile->id}/verify", ['verified' => true, 'note' => 'College ID checked in person'])
            ->assertOk()->assertJsonPath('data.verified', true);
        $this->getJson("/api/v1/admin/members/{$anusha->profile->id}")->assertJsonPath('data.profile.verified', true)->assertJsonPath('data.verification_note', 'College ID checked in person');
        $this->assertDatabaseHas('audit_logs', ['action' => 'member.verified']);
        $this->assertSame(1, AppNotification::where('user_id', $anusha->id)->where('type', 'profile_verified')->count());

        Sanctum::actingAs($anusha);
        $this->getJson('/api/v1/auth/me')->assertJsonPath('data.profile.verified', true);

        Sanctum::actingAs($viewer);
        $this->getJson('/api/v1/members/M1')->assertJsonPath('data.verified', true);
        $this->getJson('/api/v1/directory?q=Anusha')->assertJsonPath('data.0.verified', true);
    }

    public function test_people_working_together_see_each_others_phone(): void
    {
        $lead = $this->member('Srinivas');
        $a = $this->member('Anusha');
        $b = $this->member('Ravi');
        $outsider = $this->member('Outsider');
        $admin = $this->admin('state_admin', 'Telangana');

        $event = Event::create(['title' => 'Adhiveshan', 'category' => 'conference', 'venue' => 'Warangal', 'starts_at' => now()->addDay(), 'ends_at' => now()->addDays(2),
            'org_unit_id' => OrgUnit::where('name', 'Telangana')->value('id'), 'organiser_id' => $admin->id]);
        $event->forceFill(['status' => 'published'])->save();
        foreach ([$lead, $a, $b, $outsider] as $u) {
            EventRegistration::create(['event_id' => $event->id, 'user_id' => $u->id, 'status' => 'registered']);
        }
        $team = EventTeam::create(['event_id' => $event->id, 'name' => 'Parking', 'lead_user_id' => $lead->id]);
        foreach ([$a, $b] as $u) {
            EventDuty::create(['event_id' => $event->id, 'team_id' => $team->id, 'assignee_id' => $u->id, 'title' => 'Parking', 'location' => 'North lot',
                'starts_at' => now()->addDay(), 'ends_at' => now()->addDay()->addHours(4), 'status' => 'accepted']);
        }

        Sanctum::actingAs($a);
        $this->getJson('/api/v1/members/M3')->assertJsonPath('data.mobile', $b->mobile)->assertJsonPath('data.works_with_you', true);
        $this->getJson('/api/v1/members/M4')->assertJsonPath('data.mobile', null);
        $contacts = collect($this->getJson('/api/v1/me/duties')->json('data.0.team_contacts'));
        $this->assertSame(['Team lead', 'Teammate'], $contacts->pluck('role')->all());
        $this->assertSame($lead->mobile, $contacts[0]['phone']);
        $this->assertSame($b->mobile, $contacts[1]['phone']);

        Sanctum::actingAs($lead);
        $this->getJson('/api/v1/members/M2')->assertJsonPath('data.mobile', $a->mobile);

        Sanctum::actingAs($outsider);
        $this->getJson('/api/v1/members/M2')->assertJsonPath('data.mobile', null);

        Sanctum::actingAs($admin);
        $this->getJson("/api/v1/admin/events/{$event->id}/duties")->assertJsonPath('data.0.assignee_phone', $a->mobile);

        // After the event, the exception ends and privacy applies again.
        $event->update(['ends_at' => now()->subDays(3), 'starts_at' => now()->subDays(4)]);
        Sanctum::actingAs($a);
        $this->getJson('/api/v1/members/M3')->assertJsonPath('data.mobile', null);
    }
}
