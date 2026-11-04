<?php

namespace Tests\Feature;

use App\Models\AppNotification;
use App\Models\Event;
use App\Models\EventRegistration;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\RoleAssignment;
use App\Models\User;
use App\Models\Vibhag;
use App\Services\EventService;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class EventsTest extends TestCase
{
    use RefreshDatabase;

    private int $seq = 0;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    private function unit(string $name): OrgUnit
    {
        return OrgUnit::where('name', $name)->firstOrFail();
    }

    private function member(string $name, string $unit = 'Osmania University', array $vibhags = ['SFD']): User
    {
        $this->seq++;
        $user = User::create(['mobile' => '+9198000'.str_pad((string) $this->seq, 5, '0', STR_PAD_LEFT)]);
        $p = new MemberProfile(['full_name' => $name, 'org_unit_id' => $this->unit($unit)->id]);
        $p->user_id = $user->id;
        $p->member_id = 'M'.$this->seq;
        $p->membership_status = 'approved';
        $p->save();
        $user->vibhags()->sync(Vibhag::whereIn('code', $vibhags)->pluck('id'));

        return $user;
    }

    private function admin(string $role = 'state_admin', string $unit = 'Telangana'): User
    {
        $u = $this->member('Admin '.$this->seq + 1);
        RoleAssignment::create(['user_id' => $u->id, 'role' => $role, 'org_unit_id' => $this->unit($unit)->id]);

        return $u;
    }

    private function createEvent(User $admin, array $over = []): int
    {
        Sanctum::actingAs($admin);
        $id = $this->postJson('/api/v1/admin/events', $over + [
            'title' => 'Telangana Pranth Adhiveshan',
            'category' => 'conference',
            'venue' => 'Kakatiya University, Warangal',
            'starts_at' => now()->addDays(10)->setTime(9, 0)->toIso8601String(),
            'ends_at' => now()->addDays(12)->setTime(17, 0)->toIso8601String(),
            'org_unit_id' => $this->unit('Telangana')->id,
            'instructions' => 'Report at Gate 3 by 8 AM. Carry your pass.',
            'contact_name' => 'Srinivas R.',
            'contact_phone' => '9848000000',
        ])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/admin/events/$id/publish")->assertOk()->assertJsonPath('data.status', 'published');

        return $id;
    }

    public function test_drafts_are_hidden_and_published_events_show_to_members(): void
    {
        $admin = $this->admin();
        Sanctum::actingAs($admin);
        $draft = $this->postJson('/api/v1/admin/events', [
            'title' => 'Draft', 'category' => 'programme', 'venue' => 'X',
            'starts_at' => now()->addDay()->toIso8601String(), 'ends_at' => now()->addDays(2)->toIso8601String(),
            'org_unit_id' => $this->unit('Hyderabad')->id,
        ])->json('data.id');
        $published = $this->createEvent($admin);

        Sanctum::actingAs($this->member('Anusha'));
        $this->getJson('/api/v1/events')->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $published);
        $this->getJson("/api/v1/events/$draft")->assertNotFound();
        $this->getJson("/api/v1/events/$published")->assertJsonPath('data.instructions', null)->assertJsonPath('data.eligible', true);
    }

    public function test_eligibility_rules_by_area_and_vibhag(): void
    {
        $id = $this->createEvent($this->admin(), ['rules' => [['org_unit_id' => $this->unit('Hyderabad')->id, 'vibhag_id' => Vibhag::where('code', 'SFD')->value('id')]]]);

        Sanctum::actingAs($this->member('Warangal SFD', 'Kakatiya University'));
        $this->getJson("/api/v1/events/$id")->assertJsonPath('data.eligible', false);
        $this->postJson("/api/v1/events/$id/register")->assertStatus(403)->assertJsonPath('error.code', 'NOT_ELIGIBLE');

        Sanctum::actingAs($this->member('Hyderabad Think', 'Osmania University', ['THINK-INDIA']));
        $this->postJson("/api/v1/events/$id/register")->assertStatus(403);

        Sanctum::actingAs($this->member('Hyderabad SFD'));
        $this->postJson("/api/v1/events/$id/register")->assertCreated()
            ->assertJsonPath('data.my_registration.status', 'registered')
            ->assertJsonPath('data.instructions', 'Report at Gate 3 by 8 AM. Carry your pass.')
            ->assertJsonPath('data.contact.name', 'Srinivas R.');
        $this->postJson("/api/v1/events/$id/register")->assertStatus(409)->assertJsonPath('error.code', 'ALREADY_REGISTERED');
    }

    public function test_capacity_waitlist_and_promotion_on_cancel(): void
    {
        $id = $this->createEvent($this->admin(), ['capacity' => 2]);
        $a = $this->member('A');
        $b = $this->member('B');
        $c = $this->member('C');
        $d = $this->member('D');

        foreach ([$a, $b] as $u) {
            Sanctum::actingAs($u);
            $this->postJson("/api/v1/events/$id/register")->assertJsonPath('data.my_registration.status', 'registered');
        }
        Sanctum::actingAs($c);
        $this->postJson("/api/v1/events/$id/register")->assertJsonPath('data.my_registration.status', 'waitlisted')->assertJsonPath('data.waitlist_position', 1);
        Sanctum::actingAs($d);
        $this->postJson("/api/v1/events/$id/register")->assertJsonPath('data.waitlist_position', 2)->assertJsonPath('data.seats_left', 0);

        Sanctum::actingAs($a);
        $this->postJson("/api/v1/events/$id/cancel-registration")->assertJsonPath('data.my_registration.status', 'cancelled');

        $this->assertSame('registered', EventRegistration::where('user_id', $c->id)->value('status'));
        $this->assertSame('waitlisted', EventRegistration::where('user_id', $d->id)->value('status'));
        $this->assertSame(1, AppNotification::where('user_id', $c->id)->where('type', 'event_waitlist_promoted')->count());
    }

    public function test_registration_window_and_approval(): void
    {
        $admin = $this->admin();
        $closed = $this->createEvent($admin, ['registration_closes_at' => now()->subHour()->toIso8601String()]);
        $approval = $this->createEvent($admin, ['requires_approval' => true]);
        $m = $this->member('Ravi');

        Sanctum::actingAs($m);
        $this->postJson("/api/v1/events/$closed/register")->assertJsonPath('error.code', 'REGISTRATION_CLOSED');
        $this->postJson("/api/v1/events/$approval/register")->assertJsonPath('data.my_registration.status', 'pending');
        $this->getJson('/api/v1/me/passes')->assertJsonPath('data.0.token', null);

        Sanctum::actingAs($admin);
        $reg = EventRegistration::where('user_id', $m->id)->value('id');
        $this->postJson("/api/v1/admin/events/$approval/registrations/$reg/decide", ['decision' => 'approve'])->assertJsonPath('data.status', 'registered');

        Sanctum::actingAs($m);
        $this->assertStringStartsWith('EP1.', $this->getJson('/api/v1/me/passes')->json('data.0.token'));
    }

    public function test_scanning_checks_people_in_once_and_rejects_bad_passes(): void
    {
        $admin = $this->admin();
        $id = $this->createEvent($admin);
        $other = $this->createEvent($admin, ['title' => 'Another event']);
        $anusha = $this->member('Anusha');
        $scanner = $this->member('Gate Volunteer');

        Sanctum::actingAs($anusha);
        $this->postJson("/api/v1/events/$id/register");
        $token = $this->getJson('/api/v1/me/passes')->json('data.0.token');
        $this->assertStringNotContainsString('Anusha', $token);

        Sanctum::actingAs($scanner);
        $this->postJson("/api/v1/events/$id/check-in", ['token' => $token])->assertStatus(403)->assertJsonPath('error.code', 'NOT_EVENT_STAFF');

        Sanctum::actingAs($admin);
        $this->postJson("/api/v1/admin/events/$id/staff", ['member_id' => $scanner->profile->member_id, 'role' => 'scanner'])->assertCreated();

        Sanctum::actingAs($scanner);
        $this->getJson('/api/v1/auth/me')->assertJsonPath('data.can_check_in', true);
        $this->getJson("/api/v1/events/$id/roster")->assertJsonCount(1, 'data');
        $this->postJson("/api/v1/events/$id/check-in", ['token' => $token, 'gate' => 'Gate 3'])->assertOk()
            ->assertJsonPath('data.name', 'Anusha')->assertJsonPath('data.already', false);
        $this->postJson("/api/v1/events/$id/check-in", ['token' => $token, 'gate' => 'Gate 1'])->assertOk()
            ->assertJsonPath('data.already', true)->assertJsonPath('data.gate', 'Gate 3');
        $this->postJson("/api/v1/events/$id/check-in", ['token' => $token.'x'])->assertJsonPath('error.code', 'PASS_INVALID');

        Sanctum::actingAs($admin);
        $this->postJson("/api/v1/events/$other/check-in", ['token' => $token])->assertJsonPath('error.code', 'WRONG_EVENT');
        $this->getJson("/api/v1/admin/events/$id/live")->assertJsonPath('data.arrived.members', 1)->assertJsonPath('data.by_gate.0.gate', 'Gate 3');
    }

    public function test_offline_batch_reports_each_scan_separately(): void
    {
        $admin = $this->admin();
        $id = $this->createEvent($admin);
        $tokens = [];
        foreach (['A', 'B'] as $n) {
            Sanctum::actingAs($this->member($n));
            $this->postJson("/api/v1/events/$id/register");
            $tokens[] = $this->getJson('/api/v1/me/passes')->json('data.0.token');
        }

        Sanctum::actingAs($admin);
        $res = $this->postJson("/api/v1/events/$id/check-in/batch", ['items' => [
            ['token' => $tokens[0], 'gate' => 'Gate 2', 'scanned_at' => now()->subMinutes(20)->toIso8601String()],
            ['token' => $tokens[1], 'gate' => 'Gate 2'],
            ['token' => $tokens[0], 'gate' => 'Gate 2'],
            ['token' => 'EP1.zz.forged'],
        ]])->assertOk()->assertJsonPath('meta.accepted', 3);

        $this->assertSame([true, true, true, false], collect($res->json('data'))->pluck('ok')->all());
        $this->assertTrue($res->json('data.2.already'));
        $this->assertSame('offline', EventRegistration::where('status', 'registered')->first()->check_in_method);
    }

    public function test_guests_are_invited_by_mobile_and_see_only_their_invitation(): void
    {
        $admin = $this->admin();
        $id = $this->createEvent($admin, ['capacity' => 1]);
        $this->createEvent($admin, ['title' => 'Members-only camp']);
        Sanctum::actingAs($this->member('Fills the seat'));
        $this->postJson("/api/v1/events/$id/register")->assertCreated();

        Sanctum::actingAs($admin);
        $this->postJson("/api/v1/admin/events/$id/guests", ['name' => 'Prof. Rao', 'mobile' => '9123456789', 'organisation' => 'Osmania University'])
            ->assertCreated();
        $this->postJson("/api/v1/admin/events/$id/guests", ['name' => 'Prof. Rao', 'mobile' => '9123456789'])->assertStatus(409);

        $guest = User::where('mobile', '+919123456789')->first();
        Sanctum::actingAs($guest);
        $this->getJson('/api/v1/auth/me')->assertJsonPath('data.is_guest', true);
        $this->getJson('/api/v1/events')->assertJsonCount(1, 'data')->assertJsonPath('data.0.my_registration.kind', 'guest');
        $this->assertStringStartsWith('EP1.', $this->getJson('/api/v1/me/passes')->json('data.0.token'));
        $this->getJson('/api/v1/members/M1')->assertStatus(403);
    }

    public function test_changing_time_notifies_people_and_cancel_tells_everyone(): void
    {
        $admin = $this->admin();
        $id = $this->createEvent($admin);
        $m = $this->member('Ravi');
        Sanctum::actingAs($m);
        $this->postJson("/api/v1/events/$id/register");

        Sanctum::actingAs($admin);
        $this->patchJson("/api/v1/admin/events/$id", ['venue' => 'Hanamkonda Convention Hall'])->assertJsonPath('data.notified', true);
        $this->postJson("/api/v1/admin/events/$id/cancel", ['reason' => 'Postponed due to exams'])->assertJsonPath('data.status', 'cancelled');

        $this->assertSame(['event_changed', 'event_cancelled'], AppNotification::where('user_id', $m->id)->orderBy('id')->pluck('type')->all());
    }

    public function test_district_admin_cannot_manage_another_districts_event(): void
    {
        $id = $this->createEvent($this->admin('district_admin', 'Hyderabad'), ['org_unit_id' => $this->unit('Hyderabad')->id]);
        Sanctum::actingAs($this->admin('district_admin', 'Warangal'));

        $this->getJson("/api/v1/admin/events/$id")->assertStatus(403);
        $this->getJson('/api/v1/admin/events')->assertJsonCount(0, 'data');
        $this->postJson("/api/v1/events/$id/check-in", ['token' => 'x'])->assertStatus(403);
    }

    public function test_pass_tokens_are_signed(): void
    {
        $svc = app(EventService::class);
        $reg = new EventRegistration;
        $reg->id = 42;
        $token = $svc->passToken($reg);

        $this->assertNull($svc->registrationFromToken(str_replace('.16.', '.17.', $token)));
        $this->assertNull($svc->registrationFromToken('EP1.16.'.str_repeat('a', 16)));
    }
}
