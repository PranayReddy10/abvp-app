<?php

namespace Tests\Feature;

use App\Console\Commands\LoadConferenceTeams;
use App\Models\AppNotification;
use App\Models\Event;
use App\Models\EventTeam;
use App\Models\EventTeamMember;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\RoleAssignment;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ConferenceTeamsTest extends TestCase
{
    use RefreshDatabase;

    private Event $event;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
        $super = $this->admin('super_admin', 'Bharat');
        $this->event = Event::create([
            'title' => 'Rashtriya Adhiveshan 2026', 'category' => 'conference', 'venue' => 'Hyderabad',
            'starts_at' => now()->addDays(20), 'ends_at' => now()->addDays(23),
            'org_unit_id' => OrgUnit::where('name', 'Telangana')->value('id'), 'organiser_id' => $super->id,
        ]);
        $this->event->forceFill(['status' => 'published'])->save();
        $this->artisan('abvp:load-conference-teams', ['--event' => $this->event->id])->assertSuccessful();
    }

    private function admin(string $role, string $unit): User
    {
        $u = User::create(['mobile' => '+919700'.random_int(100000, 999999), 'name' => 'Admin']);
        $p = new MemberProfile(['full_name' => 'Admin', 'org_unit_id' => OrgUnit::where('name', $unit)->value('id')]);
        $p->user_id = $u->id;
        $p->member_id = 'A'.$u->id;
        $p->membership_status = 'approved';
        $p->save();
        RoleAssignment::create(['user_id' => $u->id, 'role' => $role, 'org_unit_id' => OrgUnit::where('name', $unit)->value('id')]);

        return $u;
    }

    private function ghat(string $name): EventTeam
    {
        return EventTeam::where('event_id', $this->event->id)->whereNull('parent_id')->where('name', $name)->firstOrFail();
    }

    private function dept(string $ghat, string $name): EventTeam
    {
        return EventTeam::where('parent_id', $this->ghat($ghat)->id)->where('name', $name)->firstOrFail();
    }

    /** Gives a sheet person a phone and an account, as if they signed up with that number. */
    private function signUp(EventTeamMember $m, string $mobile): User
    {
        $m->update(['mobile' => $mobile]);
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => $mobile])->assertOk();
        $this->postJson('/api/v1/auth/register', ['mobile' => $mobile, 'code' => '123456', 'name' => $m->name])->assertOk();
        $this->app['auth']->forgetGuards();

        return User::where('mobile', '+91'.$mobile)->firstOrFail();
    }

    public function test_sheet_loads_once_with_the_conference_details(): void
    {
        $this->artisan('abvp:load-conference-teams', ['--event' => $this->event->id])->assertSuccessful(); // again: no duplicates
        $this->assertSame(count(LoadConferenceTeams::SHEET), EventTeam::where('event_id', $this->event->id)->whereNull('parent_id')->count());
        $this->assertSame(8, $this->ghat('Karyalaya')->children()->count());
        $this->assertSame('Shri A Shyam Kiran', $this->ghat('Karyalaya')->members()->where('role', 'ghat_pramukh')->value('name'));
        $this->assertSame(2, $this->dept('Adhiveshan Parisar', 'Medical')->members()->count());
        $this->assertSame('72nd National Conference – Bhagyanagar', $this->event->fresh()->title);
        $this->assertSame('2026-12-24', $this->event->fresh()->starts_at->timezone('Asia/Kolkata')->toDateString());
    }

    public function test_tree_is_public_but_phones_need_sign_in(): void
    {
        EventTeamMember::where('name', 'Gowtham')->update(['mobile' => '+919876500001']);
        $this->getJson('/api/v1/conference')->assertOk()->assertJsonPath('data.id', $this->event->id)->assertJsonPath('data.has_teams', true);
        $open = $this->getJson("/api/v1/events/{$this->event->id}/teams")->assertOk();
        $gowtham = collect($open->json('data.ghats.0.departments.0.people'))->firstWhere('name', 'Gowtham');
        $this->assertNull($gowtham['mobile']);
        $this->assertTrue($gowtham['has_mobile']);

        Sanctum::actingAs(User::create(['mobile' => '+919876500099', 'name' => 'Delegate']));
        $signed = $this->getJson("/api/v1/events/{$this->event->id}/teams")->assertOk();
        $this->assertSame('+919876500001', collect($signed->json('data.ghats.0.departments.0.people'))->firstWhere('name', 'Gowtham')['mobile']);
    }

    public function test_people_are_linked_when_they_sign_up_and_get_their_seva(): void
    {
        $gowtham = EventTeamMember::where('name', 'Gowtham')->firstOrFail();
        $u = $this->signUp($gowtham, '9876500001');
        $this->assertSame($u->id, $gowtham->fresh()->user_id);

        Sanctum::actingAs($u);
        $seva = $this->getJson('/api/v1/me/seva')->assertOk();
        $seva->assertJsonPath('data.places.0.team.name', 'Adhiveshan office')
            ->assertJsonPath('data.places.0.ghat.name', 'Karyalaya')
            ->assertJsonPath('data.places.0.role_label', 'Pramukh')
            ->assertJsonPath('data.places.0.can_manage', true);
        $this->assertEqualsCanonicalizing(['Adhiveshan office', 'Karyalaya'], collect($seva->json('data.chats'))->pluck('name')->all());

        // Someone with no place gets an empty seva and no chat.
        Sanctum::actingAs(User::create(['mobile' => '+919876500098', 'name' => 'Delegate']));
        $this->getJson('/api/v1/me/seva')->assertOk()->assertJsonCount(0, 'data.places')->assertJsonCount(0, 'data.chats');
        $this->getJson('/api/v1/teams/'.$gowtham->team_id.'/messages')->assertStatus(403)->assertJsonPath('error.code', 'NOT_IN_TEAM');
    }

    public function test_chat_rules_and_announcements(): void
    {
        $karyalaya = $this->ghat('Karyalaya');
        $office = $this->dept('Karyalaya', 'Adhiveshan office');
        $head = $this->signUp(EventTeamMember::where('name', 'Shri A Shyam Kiran')->firstOrFail(), '9876500010');
        $pramukh = $this->signUp(EventTeamMember::where('name', 'Gowtham')->firstOrFail(), '9876500011');
        $printing = $this->signUp(EventTeamMember::where('name', 'Sai Teja')->where('team_id', $this->dept('Karyalaya', 'Printing')->id)->firstOrFail(), '9876500012');

        // Ghat head adds a volunteer to the Adhiveshan office.
        Sanctum::actingAs($head);
        $this->postJson("/api/v1/teams/{$office->id}/members", ['name' => 'Ravi', 'mobile' => '9876500013', 'role' => 'volunteer'])->assertCreated()->assertJsonPath('data.linked', false);
        $this->postJson("/api/v1/teams/{$office->id}/members", ['name' => 'X', 'role' => 'ghat_pramukh'])->assertStatus(422);
        $volunteer = $this->signUp(EventTeamMember::where('name', 'Ravi')->firstOrFail(), '9876500013');

        // Department chat: Pramukh, volunteer and ghat heads; not another department's Pramukh.
        Sanctum::actingAs($volunteer);
        $this->postJson("/api/v1/teams/{$office->id}/messages", ['body' => 'Reached the office'])->assertCreated();
        $this->postJson("/api/v1/teams/{$office->id}/messages", ['body' => 'All come', 'announcement' => true])->assertStatus(403);
        $this->getJson("/api/v1/teams/{$karyalaya->id}/messages")->assertStatus(403);
        Sanctum::actingAs($printing);
        $this->getJson("/api/v1/teams/{$office->id}/messages")->assertStatus(403);
        $this->getJson("/api/v1/teams/{$karyalaya->id}/messages")->assertOk(); // department Pramukhs are in the ghat chat

        // Ghat head announces to the whole ghat.
        Sanctum::actingAs($head);
        $this->postJson("/api/v1/teams/{$karyalaya->id}/messages", ['body' => 'Meeting at 6 pm at the office', 'announcement' => true])->assertCreated();
        foreach ([$pramukh, $printing, $volunteer] as $p) {
            $this->assertTrue(AppNotification::where('user_id', $p->id)->where('type', 'team_announcement')->exists());
        }

        // Heads of another ghat cannot manage this one.
        $bhojan = $this->signUp(EventTeamMember::where('name', 'Shri K Navendra')->firstOrFail(), '9876500014');
        Sanctum::actingAs($bhojan);
        $this->postJson("/api/v1/teams/{$office->id}/members", ['name' => 'Y', 'role' => 'volunteer'])->assertStatus(403)->assertJsonPath('error.code', 'HEADS_ONLY');
    }

    public function test_team_meeting_invites_everyone_and_tasks_reach_linked_people(): void
    {
        $office = $this->dept('Karyalaya', 'Adhiveshan office');
        $head = $this->signUp(EventTeamMember::where('name', 'Shri A Shyam Kiran')->firstOrFail(), '9876500020');
        $gowthamRow = EventTeamMember::where('name', 'Gowtham')->firstOrFail();
        $pramukh = $this->signUp($gowthamRow, '9876500021');

        Sanctum::actingAs($head);
        $id = $this->postJson("/api/v1/teams/{$this->ghat('Karyalaya')->id}/meetings", [
            'title' => 'Karyalaya ghat baithak', 'mode' => 'online', 'link' => 'https://meet.google.com/abc-defg-hij',
            'starts_at' => now()->addDay()->toIso8601String(), 'ends_at' => now()->addDay()->addHour()->toIso8601String(),
        ])->assertCreated()->json('data.id');

        Sanctum::actingAs($pramukh);
        $this->getJson("/api/v1/meetings/$id")->assertOk()->assertJsonPath('data.link', 'https://meet.google.com/abc-defg-hij');
        $this->getJson('/api/v1/me/seva')->assertJsonPath('data.meetings.0.title', 'Karyalaya ghat baithak');

        // Unassigned people never get the link.
        Sanctum::actingAs(User::create(['mobile' => '+919876500097', 'name' => 'Delegate']));
        $this->getJson("/api/v1/meetings/$id")->assertStatus(403);

        // Task to the Pramukh, then into their task list.
        Sanctum::actingAs($head);
        $this->postJson("/api/v1/teams/{$office->id}/tasks", ['member_id' => $gowthamRow->id, 'title' => 'Print ID cards',
            'starts_at' => now()->addDay()->toIso8601String(), 'ends_at' => now()->addDays(2)->toIso8601String()])->assertCreated();
        $unlinked = EventTeamMember::where('name', 'Vishwa Teja')->firstOrFail();
        $this->postJson("/api/v1/teams/{$this->ghat('Karyalaya')->id}/tasks", ['member_id' => $unlinked->id, 'title' => 'X',
            'starts_at' => now()->addDay()->toIso8601String(), 'ends_at' => now()->addDays(2)->toIso8601String()])->assertStatus(422)->assertJsonPath('error.code', 'NOT_SIGNED_UP');
        Sanctum::actingAs($pramukh);
        $this->getJson('/api/v1/me/seva')->assertJsonPath('data.tasks.0.title', 'Print ID cards');
    }

    public function test_admin_builds_imports_and_exports(): void
    {
        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $this->getJson("/api/v1/admin/events/{$this->event->id}/conference-teams")->assertOk()
            ->assertJsonPath('data.totals.ghats', count(LoadConferenceTeams::SHEET));
        $ghat = $this->postJson("/api/v1/admin/events/{$this->event->id}/conference-teams", ['name' => 'Suraksha ghat'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/admin/events/{$this->event->id}/conference-teams", ['name' => 'Gate 1', 'parent_id' => $ghat])->assertCreated();

        $csv = "ghat,department,role,name,mobile\nKaryalaya,Adhiveshan office,Pramukh,Gowtham,9876500031\nKaryalaya,Adhiveshan office,Volunteer,Kiran,9876500032\nNew ghat,,Ghat Pramukh,Shri New,\nbad line";
        $r = $this->postJson("/api/v1/admin/events/{$this->event->id}/conference-teams/import", ['csv' => $csv])->assertOk();
        $r->assertJsonPath('data.people', 2)->assertJsonPath('data.updated', 1)->assertJsonPath('data.ghats', 1);
        $this->assertSame('+919876500031', EventTeamMember::where('name', 'Gowtham')->value('mobile'));
        // Running the same import again changes nothing.
        $this->postJson("/api/v1/admin/events/{$this->event->id}/conference-teams/import", ['csv' => $csv])->assertJsonPath('data.people', 0)->assertJsonPath('data.updated', 0);

        $export = $this->get("/api/v1/admin/events/{$this->event->id}/conference-teams/export");
        $export->assertOk();
        $this->assertStringContainsString('Karyalaya,"Adhiveshan office",Pramukh,Gowtham,+919876500031', $export->getContent());

        Sanctum::actingAs($this->admin('district_admin', 'Hyderabad'));
        $this->getJson("/api/v1/admin/events/{$this->event->id}/conference-teams")->assertStatus(403);
    }

    public function test_admin_can_load_the_sheet_from_the_panel(): void
    {
        EventTeam::where('event_id', $this->event->id)->delete();
        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $this->postJson("/api/v1/admin/events/{$this->event->id}/conference-teams/load-sheet")
            ->assertOk()->assertJsonPath('data.totals.ghats', count(LoadConferenceTeams::SHEET));
        $this->getJson('/api/v1/conference')->assertOk()->assertJsonPath('data.id', $this->event->id);
    }

    public function test_heads_add_people_by_member_id(): void
    {
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876533301'])->assertOk();
        $this->postJson('/api/v1/auth/register', ['mobile' => '9876533301', 'code' => '123456', 'name' => 'Kiran Rao'])->assertOk();
        $this->app['auth']->forgetGuards();
        $kiran = User::where('mobile', '+919876533301')->firstOrFail();
        $mid = $kiran->profile->member_id;
        $this->assertNotEmpty($mid);

        // Someone in no team cannot look people up.
        Sanctum::actingAs(User::create(['mobile' => '+919876500097', 'name' => 'Nobody']));
        $this->getJson('/api/v1/team-members/lookup?q='.$mid)->assertStatus(403);

        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $this->getJson('/api/v1/team-members/lookup?q='.strtolower($mid))->assertOk()
            ->assertJsonPath('data.name', 'Kiran Rao')->assertJsonPath('data.mobile', '+919876533301');
        $this->getJson('/api/v1/team-members/lookup?q=9876533301')->assertOk()->assertJsonPath('data.member_id', $mid);
        $this->getJson('/api/v1/team-members/lookup?q=ABVP-XX-999999')->assertNotFound();

        $team = $this->dept('Bhojan', 'Kitchen');
        $this->postJson("/api/v1/teams/{$team->id}/members", ['member_id' => $mid, 'role' => 'volunteer'])->assertCreated()
            ->assertJsonPath('data.name', 'Kiran Rao');
        $row = EventTeamMember::where('team_id', $team->id)->where('name', 'Kiran Rao')->firstOrFail();
        $this->assertSame($kiran->id, $row->user_id);
        $this->assertSame('+919876533301', $row->mobile);
    }
}
