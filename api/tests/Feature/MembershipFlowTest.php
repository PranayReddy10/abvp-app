<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
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

class MembershipFlowTest extends TestCase
{
    use RefreshDatabase;

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

    private function admin(string $role, string $unitName, string $mobile = '+919000000001'): User
    {
        $admin = User::create(['mobile' => $mobile, 'name' => 'Admin']);
        RoleAssignment::create(['user_id' => $admin->id, 'role' => $role, 'org_unit_id' => $this->unit($unitName)->id]);

        return $admin;
    }

    private function applicant(string $unitName = 'Osmania University', string $mobile = '+919848012345'): User
    {
        $user = User::create(['mobile' => $mobile]);
        Sanctum::actingAs($user);

        $this->patchJson('/api/v1/me/profile', [
            'full_name' => 'Anusha Naidu',
            'date_of_birth' => '2005-03-14',
            'org_unit_id' => $this->unit($unitName)->id,
            'institution' => 'University College for Women, Koti',
            'vibhag_ids' => Vibhag::whereIn('code', ['SFD', 'THINK-INDIA'])->pluck('id')->all(),
        ])->assertOk()->assertJsonCount(2, 'data.vibhags');

        $this->post('/api/v1/me/photo', ['photo' => UploadedFile::fake()->image('me.jpg', 400, 400)], ['Accept' => 'application/json'])
            ->assertOk();

        $this->postJson('/api/v1/membership/application', ['confirm' => true])
            ->assertCreated()
            ->assertJsonPath('data.application.status', 'submitted');

        return $user;
    }

    public function test_application_needs_a_complete_profile(): void
    {
        Sanctum::actingAs(User::create(['mobile' => '+919848012345']));
        $this->patchJson('/api/v1/me/profile', ['full_name' => 'Ravi'])->assertOk();

        $this->postJson('/api/v1/membership/application', ['confirm' => true])
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'PROFILE_INCOMPLETE');
    }

    public function test_state_cannot_be_chosen_as_home_unit(): void
    {
        Sanctum::actingAs(User::create(['mobile' => '+919848012345']));

        $this->patchJson('/api/v1/me/profile', ['full_name' => 'Ravi', 'org_unit_id' => $this->unit('Telangana')->id])
            ->assertJsonPath('error.code', 'UNIT_TOO_BROAD');
    }

    public function test_district_admin_approves_and_member_gets_id_and_pass(): void
    {
        $applicant = $this->applicant();
        $application = MembershipApplication::first();

        Sanctum::actingAs($this->admin('district_admin', 'Hyderabad'));

        $this->getJson('/api/v1/admin/applications')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.applicant.mobile', '+91 98xxx xx345');

        $this->getJson('/api/v1/admin/dashboard')
            ->assertOk()
            ->assertJsonPath('data.pending_applications', 1)
            ->assertJsonPath('data.scope.name', 'Hyderabad')
            ->assertJsonPath('data.pending_by_unit.0.org_unit.name', 'Osmania University');

        $this->postJson("/api/v1/admin/applications/{$application->id}/approve")
            ->assertOk()
            ->assertJsonPath('data.status', 'approved')
            ->assertJsonPath('data.profile.member_id', 'ABVP-TS-HYD-000001');

        $this->assertDatabaseHas('audit_logs', ['action' => 'membership.approved']);

        Sanctum::actingAs($applicant->fresh());
        $qr = $this->getJson('/api/v1/me/qr')->assertOk()->json('data.token');
        $this->assertStringStartsWith('AC1.', $qr);
        $this->assertStringNotContainsString('Anusha', base64_decode(explode('.', $qr)[1]));
    }

    public function test_admin_outside_the_area_cannot_see_or_decide(): void
    {
        $this->applicant();
        $application = MembershipApplication::first();

        Sanctum::actingAs($this->admin('district_admin', 'Warangal'));

        $this->getJson('/api/v1/admin/applications')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson("/api/v1/admin/applications/{$application->id}")->assertStatus(403)->assertJsonPath('error.code', 'FORBIDDEN_SCOPE');
        $this->postJson("/api/v1/admin/applications/{$application->id}/approve")->assertStatus(403);

        $this->assertSame(MemberProfile::STATUS_SUBMITTED, MemberProfile::first()->membership_status);
    }

    public function test_state_admin_reaches_every_district_in_the_state(): void
    {
        $this->applicant();

        Sanctum::actingAs($this->admin('state_admin', 'Telangana'));
        $this->getJson('/api/v1/admin/applications')->assertJsonCount(1, 'data');

        Sanctum::actingAs($this->admin('state_admin', 'Andhra Pradesh', '+919000000002'));
        $this->getJson('/api/v1/admin/applications')->assertJsonCount(0, 'data');
    }

    public function test_return_for_correction_then_resubmit(): void
    {
        $applicant = $this->applicant();
        $application = MembershipApplication::first();
        $admin = $this->admin('district_admin', 'Hyderabad');

        Sanctum::actingAs($admin);
        $this->postJson("/api/v1/admin/applications/{$application->id}/return", [])
            ->assertStatus(422)->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->postJson("/api/v1/admin/applications/{$application->id}/return", ['note' => 'Your photo is unclear. Upload a clear one.'])
            ->assertOk()->assertJsonPath('data.status', 'more_info_required');

        Sanctum::actingAs($applicant->fresh());
        $this->getJson('/api/v1/auth/me')
            ->assertJsonPath('data.application.status', 'more_info_required')
            ->assertJsonPath('data.application.decision_note', 'Your photo is unclear. Upload a clear one.');

        $this->postJson('/api/v1/membership/application', ['confirm' => true])
            ->assertCreated()->assertJsonPath('data.application.status', 'submitted');

        $this->assertSame(1, MembershipApplication::count());
        $this->assertSame(['submitted', 'returned', 'resubmitted'], $application->events()->pluck('action')->all());
    }

    public function test_decided_application_cannot_be_decided_again(): void
    {
        $this->applicant();
        $application = MembershipApplication::first();

        Sanctum::actingAs($this->admin('district_admin', 'Hyderabad'));
        $this->postJson("/api/v1/admin/applications/{$application->id}/reject", ['note' => 'Not a student of this unit.'])->assertOk();
        $this->postJson("/api/v1/admin/applications/{$application->id}/approve")
            ->assertStatus(409)->assertJsonPath('error.code', 'ALREADY_DECIDED');
    }

    public function test_member_ids_run_per_district(): void
    {
        $this->applicant('Osmania University', '+919848000001');
        $this->applicant('Secunderabad', '+919848000002');
        $this->applicant('Kakatiya University', '+919848000003');

        Sanctum::actingAs($this->admin('state_admin', 'Telangana'));
        foreach (MembershipApplication::orderBy('id')->get() as $app) {
            $this->postJson("/api/v1/admin/applications/{$app->id}/approve")->assertOk();
        }

        $this->assertSame(
            ['ABVP-TS-HYD-000001', 'ABVP-TS-HYD-000002', 'ABVP-TS-WGL-000001'],
            MemberProfile::orderBy('id')->pluck('member_id')->all(),
        );
    }
}
