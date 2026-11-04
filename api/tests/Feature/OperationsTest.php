<?php

namespace Tests\Feature;

use App\Models\AppNotification;
use App\Models\Event;
use App\Models\EventDuty;
use App\Models\EventRegistration;
use App\Models\EventStaff;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\RoleAssignment;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OperationsTest extends TestCase
{
    use RefreshDatabase;

    private int $seq = 0;
    private User $admin;
    private Event $event;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
        $this->admin = $this->member('Pranay');
        RoleAssignment::create(['user_id' => $this->admin->id, 'role' => 'state_admin', 'org_unit_id' => OrgUnit::where('name', 'Telangana')->value('id')]);
        $this->event = Event::create([
            'title' => 'Pranth Adhiveshan', 'category' => 'conference', 'venue' => 'Warangal',
            'starts_at' => now()->addDays(3)->setTime(3, 0), 'ends_at' => now()->addDays(4)->setTime(12, 0),
            'org_unit_id' => OrgUnit::where('name', 'Telangana')->value('id'), 'organiser_id' => $this->admin->id,
        ]);
        $this->event->forceFill(['status' => 'published'])->save();
    }

    private function member(string $name, bool $registered = false): User
    {
        $this->seq++;
        $user = User::create(['mobile' => '+9198000'.str_pad((string) $this->seq, 5, '0', STR_PAD_LEFT)]);
        $p = new MemberProfile(['full_name' => $name, 'org_unit_id' => OrgUnit::where('name', 'Osmania University')->value('id')]);
        $p->user_id = $user->id;
        $p->member_id = 'M'.$this->seq;
        $p->membership_status = 'approved';
        $p->save();
        if ($registered) {
            EventRegistration::create(['event_id' => $this->event->id, 'user_id' => $user->id, 'status' => 'registered']);
        }

        return $user;
    }

    private function duty(array $over = []): array
    {
        return $over + [
            'title' => 'Registration desk', 'location' => 'Gate 3', 'instructions' => 'Verify passes.',
            'starts_at' => $this->event->starts_at->copy()->addHour()->toIso8601String(),
            'ends_at' => $this->event->starts_at->copy()->addHours(5)->toIso8601String(),
        ];
    }

    public function test_coordinator_builds_teams_and_assigns_duties(): void
    {
        $lead = $this->member('Srinivas', true);
        $a = $this->member('Anusha', true);
        $b = $this->member('Ravi', true);
        Sanctum::actingAs($this->admin);

        $team = $this->postJson("/api/v1/admin/events/{$this->event->id}/teams", ['name' => 'Registration', 'lead_member_id' => $lead->profile->member_id])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/admin/events/{$this->event->id}/duties", $this->duty(['team_id' => $team, 'member_ids' => [$a->profile->member_id, $b->profile->member_id]]))
            ->assertCreated()->assertJsonPath('data.created', 2);

        $this->getJson("/api/v1/admin/events/{$this->event->id}/teams")->assertJsonPath('data.0.duties', 2)->assertJsonPath('data.0.lead.name', 'Srinivas');
        $this->assertSame(1, AppNotification::where('user_id', $a->id)->where('type', 'duty_assigned')->count());

        Sanctum::actingAs($a);
        $this->getJson('/api/v1/me/duties')->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.report_to.name', 'Srinivas')
            ->assertJsonPath('data.0.report_to.phone', $lead->mobile);
    }

    public function test_only_participants_get_duties_and_clashes_are_flagged(): void
    {
        $outsider = $this->member('Not registered');
        $a = $this->member('Anusha', true);
        Sanctum::actingAs($this->admin);

        $this->postJson("/api/v1/admin/events/{$this->event->id}/duties", $this->duty(['member_ids' => [$outsider->profile->member_id]]))
            ->assertStatus(422)->assertJsonPath('error.code', 'NOT_PARTICIPANT');

        $this->postJson("/api/v1/admin/events/{$this->event->id}/duties", $this->duty(['member_ids' => [$a->profile->member_id]]))->assertCreated();
        $clash = $this->postJson("/api/v1/admin/events/{$this->event->id}/duties", $this->duty(['title' => 'Stage support', 'member_ids' => [$a->profile->member_id]]))
            ->assertStatus(409)->assertJsonPath('error.code', 'DUTY_CLASH');
        $this->assertSame('Registration desk', $clash->json('clashes.0.duty'));

        $this->postJson("/api/v1/admin/events/{$this->event->id}/duties", $this->duty(['title' => 'Stage support', 'member_ids' => [$a->profile->member_id], 'force' => true]))
            ->assertCreated()->assertJsonPath('data.clashes_ignored', 1);
    }

    public function test_decline_tells_the_lead_and_reassign_tells_both(): void
    {
        $lead = $this->member('Srinivas', true);
        $a = $this->member('Anusha', true);
        $b = $this->member('Ravi', true);
        Sanctum::actingAs($this->admin);
        $team = $this->postJson("/api/v1/admin/events/{$this->event->id}/teams", ['name' => 'Hospitality', 'lead_member_id' => $lead->profile->member_id])->json('data.id');
        $this->postJson("/api/v1/admin/events/{$this->event->id}/duties", $this->duty(['team_id' => $team, 'member_ids' => [$a->profile->member_id]]));
        $duty = EventDuty::first();

        Sanctum::actingAs($a);
        $this->postJson("/api/v1/duties/{$duty->id}/respond", ['response' => 'decline'])->assertStatus(422);
        $this->postJson("/api/v1/duties/{$duty->id}/respond", ['response' => 'decline', 'reason' => 'I have an exam that morning'])->assertJsonPath('data.status', 'declined');
        $this->assertSame(1, AppNotification::where('user_id', $lead->id)->where('type', 'duty_declined')->count());

        Sanctum::actingAs($this->admin);
        $this->getJson("/api/v1/admin/events/{$this->event->id}/duties?status=problems")->assertJsonCount(1, 'data');
        $this->patchJson("/api/v1/admin/events/{$this->event->id}/duties/{$duty->id}", ['member_id' => $b->profile->member_id])
            ->assertJsonPath('data.status', 'assigned')->assertJsonPath('data.assignee.name', 'Ravi');
        $this->assertSame(1, AppNotification::where('user_id', $a->id)->where('type', 'duty_removed')->count());
        $this->assertSame(1, AppNotification::where('user_id', $b->id)->where('type', 'duty_assigned')->count());
    }

    public function test_progress_by_holder_and_lead_but_not_others(): void
    {
        $lead = $this->member('Srinivas', true);
        $a = $this->member('Anusha', true);
        $other = $this->member('Other', true);
        Sanctum::actingAs($this->admin);
        $team = $this->postJson("/api/v1/admin/events/{$this->event->id}/teams", ['name' => 'Parking', 'lead_member_id' => $lead->profile->member_id])->json('data.id');
        $this->postJson("/api/v1/admin/events/{$this->event->id}/duties", $this->duty(['team_id' => $team, 'member_ids' => [$a->profile->member_id]]));
        $duty = EventDuty::first();

        Sanctum::actingAs($a);
        $this->postJson("/api/v1/duties/{$duty->id}/respond", ['response' => 'accept'])->assertJsonPath('data.status', 'accepted');
        $this->postJson("/api/v1/duties/{$duty->id}/progress", ['status' => 'in_progress'])->assertJsonPath('data.status', 'in_progress');
        $this->postJson("/api/v1/duties/{$duty->id}/progress", ['status' => 'blocked', 'note' => 'Gate 2 lot is full'])->assertOk();
        $this->assertSame(1, AppNotification::where('user_id', $lead->id)->where('type', 'duty_blocked')->count());

        Sanctum::actingAs($other);
        $this->postJson("/api/v1/duties/{$duty->id}/progress", ['status' => 'done'])->assertStatus(403);

        Sanctum::actingAs($lead);
        $this->getJson('/api/v1/me/teams')->assertJsonPath('data.0.duties.0.status', 'blocked');
        $this->postJson("/api/v1/duties/{$duty->id}/progress", ['status' => 'done'])->assertJsonPath('data.status', 'done');
    }

    public function test_help_requests_reach_coordinators_and_get_replies(): void
    {
        $coord = $this->member('Coordinator');
        EventStaff::create(['event_id' => $this->event->id, 'user_id' => $coord->id, 'role' => 'coordinator']);
        $a = $this->member('Anusha', true);
        $stranger = $this->member('Stranger');

        Sanctum::actingAs($stranger);
        $this->postJson("/api/v1/events/{$this->event->id}/help", ['category' => 'food', 'message' => 'No lunch coupons'])->assertStatus(403);

        Sanctum::actingAs($a);
        $id = $this->postJson("/api/v1/events/{$this->event->id}/help", ['category' => 'medical', 'message' => 'Someone fainted near Hall B', 'location' => 'Hall B'])
            ->assertCreated()->assertJsonPath('data.status', 'open')
            ->assertJsonPath('data.emergency_note', 'For a medical emergency call 108 now. This request also alerts the event team.')->json('data.id');
        $this->assertSame(1, AppNotification::where('user_id', $coord->id)->where('type', 'help_request')->count());

        Sanctum::actingAs($coord);
        $this->getJson("/api/v1/admin/events/{$this->event->id}/help")->assertJsonPath('data.0.category', 'medical');
        $this->postJson("/api/v1/help/$id/reply", ['body' => 'First-aid team is on the way.'])->assertJsonPath('data.status', 'in_progress');
        $this->patchJson("/api/v1/admin/events/{$this->event->id}/help/$id", ['status' => 'resolved'])->assertJsonPath('data.status', 'resolved');

        Sanctum::actingAs($a);
        $this->getJson('/api/v1/me/help')->assertJsonPath('data.0.replies.0.body', 'First-aid team is on the way.')->assertJsonPath('data.0.replies.0.from_team', true);
    }

    public function test_announcements_go_to_the_chosen_audience(): void
    {
        $a = $this->member('Anusha', true);
        $b = $this->member('Ravi', true);
        Sanctum::actingAs($this->admin);
        $this->postJson("/api/v1/admin/events/{$this->event->id}/duties", $this->duty(['member_ids' => [$a->profile->member_id]]));

        $this->postJson("/api/v1/admin/events/{$this->event->id}/announcements", ['title' => 'Volunteers: briefing at 7 AM', 'body' => 'Main stage.', 'audience' => 'team_only'])
            ->assertJsonPath('data.recipients', 1);
        $this->postJson("/api/v1/admin/events/{$this->event->id}/announcements", ['title' => 'Lunch moved to 1:30 PM', 'body' => 'Dining hall B.', 'audience' => 'everyone'])
            ->assertJsonPath('data.recipients', 2);

        $this->assertSame(2, AppNotification::where('user_id', $a->id)->where('type', 'event_announcement')->count());
        $this->assertSame(1, AppNotification::where('user_id', $b->id)->where('type', 'event_announcement')->count());

        Sanctum::actingAs($b);
        $this->getJson("/api/v1/events/{$this->event->id}/announcements")->assertJsonCount(2, 'data');
        $this->getJson("/api/v1/admin/events/{$this->event->id}/live")->assertStatus(403);

        Sanctum::actingAs($this->admin);
        $this->getJson("/api/v1/admin/events/{$this->event->id}/live")->assertJsonPath('data.duties.assigned', 1);
    }

    public function test_other_districts_cannot_run_operations(): void
    {
        $warangal = $this->member('Warangal admin');
        RoleAssignment::create(['user_id' => $warangal->id, 'role' => 'district_admin', 'org_unit_id' => OrgUnit::where('name', 'Warangal')->value('id')]);
        Sanctum::actingAs($warangal);

        $this->getJson("/api/v1/admin/events/{$this->event->id}/duties")->assertStatus(403);
        $this->postJson("/api/v1/admin/events/{$this->event->id}/announcements", ['title' => 'x', 'body' => 'y', 'audience' => 'everyone'])->assertStatus(403);
    }
}
