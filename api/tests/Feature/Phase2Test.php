<?php

namespace Tests\Feature;

use App\Models\AppNotification;
use App\Models\MemberProfile;
use App\Models\Meeting;
use App\Models\MeetingInvitee;
use App\Models\MembershipApplication;
use App\Models\OrgUnit;
use App\Models\RoleAssignment;
use App\Models\User;
use App\Models\Vibhag;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class Phase2Test extends TestCase
{
    use RefreshDatabase;

    private int $seq = 0;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
        Storage::fake('local');
    }

    private function unit(string $name): OrgUnit
    {
        return OrgUnit::where('name', $name)->firstOrFail();
    }

    private function vibhag(string $code): Vibhag
    {
        return Vibhag::where('code', $code)->firstOrFail();
    }

    private function member(string $name, string $unit = 'Osmania University', array $vibhags = ['SFD'], array $profile = []): User
    {
        $this->seq++;
        $user = User::create(['mobile' => '+9198000'.str_pad((string) $this->seq, 5, '0', STR_PAD_LEFT)]);
        $p = new MemberProfile(['full_name' => $name, 'org_unit_id' => $this->unit($unit)->id] + $profile);
        $p->user_id = $user->id;
        $p->member_id = 'M'.$this->seq;
        $p->membership_status = 'approved';
        $p->approved_at = now();
        $p->save();
        $user->vibhags()->sync(collect($vibhags)->map(fn ($c) => $this->vibhag($c)->id)->all());

        return $user;
    }

    private function role(User $user, string $role, string $unit, ?string $vibhag = null): User
    {
        RoleAssignment::create(['user_id' => $user->id, 'role' => $role, 'org_unit_id' => $this->unit($unit)->id, 'vibhag_id' => $vibhag ? $this->vibhag($vibhag)->id : null]);

        return $user;
    }

    private function meetingPayload(array $over = []): array
    {
        return $over + [
            'kind' => 'meeting',
            'title' => 'SFD Zilla Baithak',
            'mode' => 'online',
            'link' => 'https://meet.google.com/kqv-ndbx-tre',
            'starts_at' => now()->addDays(2)->setTime(19, 0)->format('Y-m-d\TH:i:sP'),
            'ends_at' => now()->addDays(2)->setTime(20, 0)->format('Y-m-d\TH:i:sP'),
            'org_unit_id' => $this->unit('Hyderabad')->id,
            'vibhag_id' => $this->vibhag('SFD')->id,
        ];
    }

    public function test_district_meeting_invites_only_the_vibhag_members_in_that_district(): void
    {
        $admin = $this->role($this->member('Kiran'), 'district_admin', 'Hyderabad');
        $sfdHyd = $this->member('Anusha');
        $thinkHyd = $this->member('Ravi', 'Osmania University', ['THINK-INDIA']);
        $sfdWgl = $this->member('Sandeep', 'Kakatiya University');

        Sanctum::actingAs($admin);
        $res = $this->postJson('/api/v1/meetings', $this->meetingPayload())
            ->assertCreated()
            ->assertJsonPath('data.provider', 'google_meet')
            ->assertJsonPath('data.rsvp_counts.pending', 1);

        $id = $res->json('data.id');
        $this->assertTrue(MeetingInvitee::where('meeting_id', $id)->where('user_id', $sfdHyd->id)->exists());
        $this->assertFalse(MeetingInvitee::where('meeting_id', $id)->whereIn('user_id', [$thinkHyd->id, $sfdWgl->id])->exists());
        $this->assertSame(1, AppNotification::where('user_id', $sfdHyd->id)->where('type', 'meeting_invite')->count());

        Sanctum::actingAs($sfdHyd);
        $this->getJson("/api/v1/meetings/$id")->assertOk()->assertJsonPath('data.link', 'https://meet.google.com/kqv-ndbx-tre');
        $this->getJson('/api/v1/meetings')->assertJsonCount(1, 'data');

        Sanctum::actingAs($sfdWgl);
        $this->getJson("/api/v1/meetings/$id")->assertStatus(403)->assertJsonPath('error.code', 'NOT_INVITED');
    }

    public function test_times_from_india_are_stored_correctly(): void
    {
        $admin = $this->role($this->member('Kiran'), 'district_admin', 'Hyderabad');
        Sanctum::actingAs($admin);

        $start = now()->addDays(3)->setTimezone('Asia/Kolkata')->setTime(19, 0);
        $id = $this->postJson('/api/v1/meetings', $this->meetingPayload([
            'starts_at' => $start->format('Y-m-d\TH:i:sP'),
            'ends_at' => $start->copy()->addHour()->format('Y-m-d\TH:i:sP'),
        ]))->json('data.id');

        $this->assertSame('13:30', Meeting::find($id)->starts_at->format('H:i'));
    }

    public function test_vibhag_admin_can_only_call_meetings_for_their_vibhag(): void
    {
        $thinkAdmin = $this->role($this->member('Harsha'), 'vibhag_admin', 'Hyderabad', 'THINK-INDIA');
        Sanctum::actingAs($thinkAdmin);

        $this->postJson('/api/v1/meetings', $this->meetingPayload())->assertStatus(403)->assertJsonPath('error.code', 'FORBIDDEN_SCOPE');
        $this->postJson('/api/v1/meetings', $this->meetingPayload(['vibhag_id' => $this->vibhag('THINK-INDIA')->id]))->assertCreated();
    }

    public function test_ordinary_members_can_only_schedule_one_to_one_calls(): void
    {
        $ravi = $this->member('Ravi');
        $kiran = $this->member('Kiran');
        Sanctum::actingAs($ravi);

        $this->postJson('/api/v1/meetings', $this->meetingPayload())->assertStatus(403);

        $call = $this->postJson('/api/v1/meetings', $this->meetingPayload([
            'kind' => 'call', 'title' => 'Tree plantation plan', 'link' => 'https://zoom.us/j/123',
            'org_unit_id' => null, 'vibhag_id' => null, 'member_ids' => [$kiran->profile->member_id],
        ]))->assertCreated()->assertJsonPath('data.provider', 'zoom');

        Sanctum::actingAs($kiran);
        $this->postJson('/api/v1/meetings/'.$call->json('data.id').'/rsvp', ['rsvp' => 'going'])->assertOk()->assertJsonPath('data.my_rsvp', 'going');
        $this->assertSame(1, AppNotification::where('user_id', $ravi->id)->where('type', 'call_reply')->count());
    }

    public function test_join_records_attendance_but_not_too_early(): void
    {
        $admin = $this->role($this->member('Kiran'), 'district_admin', 'Hyderabad');
        $anusha = $this->member('Anusha');
        Sanctum::actingAs($admin);
        $id = $this->postJson('/api/v1/meetings', $this->meetingPayload())->json('data.id');

        Sanctum::actingAs($anusha);
        $this->postJson("/api/v1/meetings/$id/join")->assertJsonPath('error.code', 'TOO_EARLY');

        $this->travelTo(Meeting::find($id)->starts_at->copy()->subMinutes(5));
        $this->postJson("/api/v1/meetings/$id/join")->assertOk()->assertJsonPath('data.link', 'https://meet.google.com/kqv-ndbx-tre');
        $this->assertNotNull(MeetingInvitee::where('meeting_id', $id)->where('user_id', $anusha->id)->value('joined_at'));
    }

    public function test_minutes_create_action_items_for_the_assignee(): void
    {
        $admin = $this->role($this->member('Kiran'), 'district_admin', 'Hyderabad');
        $anusha = $this->member('Anusha');
        Sanctum::actingAs($admin);
        $id = $this->postJson('/api/v1/meetings', $this->meetingPayload())->json('data.id');

        $this->putJson("/api/v1/meetings/$id/minutes", [
            'minutes' => 'Lake clean-up reviewed.',
            'action_items' => [['title' => 'Book venue for tree plantation', 'member_id' => $anusha->profile->member_id, 'due_on' => now()->addDays(5)->toDateString()]],
        ])->assertOk()->assertJsonCount(1, 'data.action_items');

        Sanctum::actingAs($anusha);
        $item = $this->getJson('/api/v1/me/action-items')->assertJsonCount(1, 'data')->json('data.0.id');
        $this->postJson("/api/v1/action-items/$item/done")->assertJsonPath('data.done', true);
        $this->get("/api/v1/meetings/$id/calendar.ics")->assertOk()->assertHeader('Content-Type', 'text/calendar; charset=utf-8');
    }

    public function test_state_circular_reaches_members_below_it_and_tracks_reads(): void
    {
        $state = $this->role($this->member('Prashanth'), 'state_admin', 'Telangana');
        $hyd = $this->member('Anusha');
        $wgl = $this->member('Sandeep', 'Kakatiya University');
        $ap = $this->member('Lakshmi', 'Andhra University');

        Sanctum::actingAs($state);
        $id = $this->post('/api/v1/admin/circulars', [
            'title' => 'Sadasyata Abhiyan 2026–27 guidelines',
            'body' => 'Every unit plans one membership drive before 15 December.',
            'org_unit_id' => $this->unit('Telangana')->id,
            'attachment' => UploadedFile::fake()->create('guidelines.pdf', 200, 'application/pdf'),
        ], ['Accept' => 'application/json'])->assertCreated()->assertJsonPath('data.audience_size', 3)->json('data.id');

        Sanctum::actingAs($hyd);
        $this->getJson('/api/v1/circulars')->assertJsonCount(1, 'data')->assertJsonPath('meta.unread', 1);
        $this->getJson("/api/v1/circulars/$id")->assertOk()->assertJsonPath('data.from', 'Telangana');
        $this->getJson('/api/v1/circulars')->assertJsonPath('data.0.is_read', true)->assertJsonPath('meta.unread', 0);

        Sanctum::actingAs($ap);
        $this->getJson('/api/v1/circulars')->assertJsonCount(0, 'data');
        $this->getJson("/api/v1/circulars/$id")->assertNotFound();

        Sanctum::actingAs($state);
        $this->getJson('/api/v1/admin/circulars')->assertJsonPath('data.0.reads', 1)->assertJsonPath('data.0.read_rate', 33);
        $this->postJson("/api/v1/admin/circulars/$id/remind")->assertJsonPath('data.reminded', 2);
        $this->assertSame(1, AppNotification::where('user_id', $wgl->id)->where('type', 'circular_reminder')->count());
        $this->assertSame(0, AppNotification::where('user_id', $hyd->id)->where('type', 'circular_reminder')->count());
    }

    public function test_only_that_vibhags_coordinators_can_post_in_its_space(): void
    {
        $sfdAdmin = $this->role($this->member('Kiran'), 'vibhag_admin', 'Hyderabad', 'SFD');
        $thinkAdmin = $this->role($this->member('Harsha'), 'vibhag_admin', 'Hyderabad', 'THINK-INDIA');
        $anusha = $this->member('Anusha');
        $sfd = $this->vibhag('SFD');

        Sanctum::actingAs($thinkAdmin);
        $this->postJson("/api/v1/spaces/{$sfd->id}/posts", ['body' => 'Hello SFD'])->assertStatus(403);

        Sanctum::actingAs($sfdAdmin);
        $this->postJson("/api/v1/spaces/{$sfd->id}/posts", ['body' => 'Lake clean-up done. 86 students joined.'])->assertCreated();

        Sanctum::actingAs($anusha);
        $this->getJson("/api/v1/spaces/{$sfd->id}/posts")->assertJsonCount(1, 'data')->assertJsonPath('data.0.author', 'Kiran');
        $this->getJson("/api/v1/spaces/{$sfd->id}")->assertJsonPath('data.is_member', true)->assertJsonPath('data.can_post', false);
        $this->deleteJson("/api/v1/spaces/{$sfd->id}/join")->assertOk();
        $this->getJson('/api/v1/spaces')->assertJsonPath('data.0.is_member', false);
    }

    public function test_activity_reports_are_for_own_unit_and_roll_up_to_admins(): void
    {
        $anusha = $this->member('Anusha');
        $district = $this->role($this->member('Kiran'), 'district_admin', 'Hyderabad');
        $warangal = $this->role($this->member('Raju', 'Kakatiya University'), 'district_admin', 'Warangal');

        Sanctum::actingAs($anusha);
        $payload = [
            'title' => 'Lake clean-up drive', 'programme_type' => 'seva', 'held_on' => now()->subDay()->toDateString(),
            'place' => 'Saroornagar Lake', 'participants' => 86, 'institutions' => 4, 'vibhag_id' => $this->vibhag('SFD')->id,
            'photos' => [UploadedFile::fake()->image('a.jpg', 800, 600)],
        ];
        $this->post('/api/v1/activity-reports', $payload, ['Accept' => 'application/json'])->assertCreated()->assertJsonCount(1, 'data.photo_urls');
        $this->post('/api/v1/activity-reports', $payload + ['org_unit_id' => $this->unit('Kakatiya University')->id], ['Accept' => 'application/json'])
            ->assertStatus(403);

        Sanctum::actingAs($district);
        $this->getJson('/api/v1/admin/activity-reports')->assertJsonCount(1, 'data')->assertJsonPath('meta.total_participants', 86);

        Sanctum::actingAs($warangal);
        $this->getJson('/api/v1/admin/activity-reports')->assertJsonCount(0, 'data');
    }

    public function test_analytics_summarises_the_area_and_rolls_up_units(): void
    {
        $state = $this->role($this->member('Prashanth'), 'state_admin', 'Telangana');
        $this->member('Anusha', 'Osmania University', ['SFD'], ['gender' => 'female', 'date_of_birth' => now()->subYears(20)]);
        $this->member('Ravi', 'Secunderabad', ['THINK-INDIA'], ['gender' => 'male']);
        $this->member('Sandeep', 'Kakatiya University');
        $this->member('Lakshmi', 'Andhra University');

        $applicant = User::create(['mobile' => '+919811111111']);
        $p = new MemberProfile(['full_name' => 'Waiting Person', 'org_unit_id' => $this->unit('Kukatpally')->id]);
        $p->user_id = $applicant->id;
        $p->save();
        MembershipApplication::create(['user_id' => $applicant->id, 'org_unit_id' => $this->unit('Kukatpally')->id, 'status' => 'submitted', 'submitted_at' => now()->subDays(9)]);

        Sanctum::actingAs($this->member('Reporter'));
        $this->postJson('/api/v1/activity-reports', ['title' => 'Campus contact', 'programme_type' => 'campus_contact', 'held_on' => now()->toDateString(), 'participants' => 40])->assertCreated();

        Sanctum::actingAs($state);
        $res = $this->getJson('/api/v1/admin/analytics?months=6')->assertOk()
            ->assertJsonPath('data.scope.name', 'Telangana')
            ->assertJsonPath('data.summary.members_total', 5) // Prashanth, Anusha, Ravi, Sandeep, Reporter (not AP)
            ->assertJsonPath('data.summary.pending_now', 1)
            ->assertJsonPath('data.summary.pending_over_7_days', 1)
            ->assertJsonPath('data.summary.reports_submitted', 1)
            ->assertJsonPath('data.summary.participants_reached', 40)
            ->assertJsonCount(6, 'data.monthly');

        $units = collect($res->json('data.units'))->keyBy('name');
        $this->assertSame(4, $units['Hyderabad']['members']);
        $this->assertSame(1, $units['Hyderabad']['reports']);
        $this->assertContains('Applications waiting over 7 days', $units['Hyderabad']['attention']);
        $this->assertSame(1, $units['Warangal']['members']);

        $this->getJson('/api/v1/admin/analytics?unit_id='.$this->unit('Hyderabad')->id)
            ->assertJsonPath('data.scope.name', 'Hyderabad')
            ->assertJsonPath('data.scope.parent_id', $this->unit('Telangana')->id);

        $this->getJson('/api/v1/admin/analytics?unit_id='.$this->unit('Andhra Pradesh')->id)->assertStatus(403);
    }

    public function test_reminders_go_out_once(): void
    {
        $admin = $this->role($this->member('Kiran'), 'district_admin', 'Hyderabad');
        $anusha = $this->member('Anusha');
        Sanctum::actingAs($admin);
        $id = $this->postJson('/api/v1/meetings', $this->meetingPayload())->json('data.id');

        $this->travelTo(Meeting::find($id)->starts_at->copy()->subHours(24));
        $this->artisan('abvp:meeting-reminders')->assertSuccessful();
        $this->artisan('abvp:meeting-reminders')->assertSuccessful();

        $this->assertSame(1, AppNotification::where('user_id', $anusha->id)->where('type', 'meeting_reminder')->count());
    }
}
