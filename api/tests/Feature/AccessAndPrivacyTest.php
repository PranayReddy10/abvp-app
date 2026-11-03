<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\RoleAssignment;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AccessAndPrivacyTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    private function member(string $mobile, string $memberId, string $unit = 'Osmania University', array $privacy = []): User
    {
        $user = User::create(['mobile' => $mobile]);
        $p = new MemberProfile(['full_name' => "Member $memberId", 'org_unit_id' => OrgUnit::where('name', $unit)->value('id'), 'institution' => 'Osmania', 'privacy' => $privacy]);
        $p->user_id = $user->id;
        $p->member_id = $memberId;
        $p->membership_status = MemberProfile::STATUS_APPROVED;
        $p->save();

        return $user;
    }

    private function role(User $user, string $role, string $unit): void
    {
        RoleAssignment::create(['user_id' => $user->id, 'role' => $role, 'org_unit_id' => OrgUnit::where('name', $unit)->value('id')]);
    }

    public function test_phone_is_hidden_from_other_members_by_default(): void
    {
        $this->member('+919800000001', 'M1');
        Sanctum::actingAs($this->member('+919800000002', 'M2'));

        $this->getJson('/api/v1/members/M1')
            ->assertOk()
            ->assertJsonPath('data.mobile', null)
            ->assertJsonPath('data.institution', 'Osmania');
    }

    public function test_member_can_open_phone_to_their_unit(): void
    {
        $this->member('+919800000001', 'M1', privacy: ['mobile' => 'my_unit']);

        Sanctum::actingAs($this->member('+919800000002', 'M2'));
        $this->getJson('/api/v1/members/M1')->assertJsonPath('data.mobile', '+919800000001');

        Sanctum::actingAs($this->member('+919800000003', 'M3', 'Kakatiya University'));
        $this->getJson('/api/v1/members/M1')->assertJsonPath('data.mobile', null);
    }

    public function test_non_members_cannot_browse_profiles(): void
    {
        $this->member('+919800000001', 'M1');
        Sanctum::actingAs(User::create(['mobile' => '+919800000009']));

        $this->getJson('/api/v1/members/M1')->assertStatus(403)->assertJsonPath('error.code', 'NOT_A_MEMBER');
    }

    public function test_admin_can_only_assign_roles_below_their_own(): void
    {
        $district = $this->member('+919800000001', 'D1');
        $this->role($district, 'district_admin', 'Hyderabad');
        $this->member('+919800000002', 'M2');
        $hyd = OrgUnit::where('name', 'Hyderabad')->value('id');
        $wgl = OrgUnit::where('name', 'Warangal')->value('id');

        Sanctum::actingAs($district);

        $this->postJson('/api/v1/admin/role-assignments', ['member_id' => 'M2', 'role' => 'verification_officer', 'org_unit_id' => $hyd])
            ->assertCreated();

        $this->postJson('/api/v1/admin/role-assignments', ['member_id' => 'M2', 'role' => 'district_admin', 'org_unit_id' => $hyd])
            ->assertStatus(403)->assertJsonPath('error.code', 'ROLE_TOO_HIGH');

        $this->postJson('/api/v1/admin/role-assignments', ['member_id' => 'M2', 'role' => 'verification_officer', 'org_unit_id' => $wgl])
            ->assertStatus(403)->assertJsonPath('error.code', 'FORBIDDEN_SCOPE');
    }

    public function test_only_national_admins_manage_vibhags(): void
    {
        $state = $this->member('+919800000001', 'S1');
        $this->role($state, 'state_admin', 'Telangana');
        Sanctum::actingAs($state);
        $this->postJson('/api/v1/admin/vibhags', ['name' => 'Jignasa', 'code' => 'JIGNASA'])->assertStatus(403);

        $national = $this->member('+919800000002', 'N1');
        $this->role($national, 'national_admin', 'Bharat');
        Sanctum::actingAs($national);
        $this->postJson('/api/v1/admin/vibhags', ['name' => 'Jignasa', 'code' => 'JIGNASA'])->assertCreated();
    }

    public function test_state_admin_adds_a_unit_inside_their_state_only(): void
    {
        $state = $this->member('+919800000001', 'S1');
        $this->role($state, 'state_admin', 'Telangana');
        Sanctum::actingAs($state);

        $this->postJson('/api/v1/admin/org-units', ['parent_id' => OrgUnit::where('name', 'Hyderabad')->value('id'), 'name' => 'Nizam College'])
            ->assertCreated()->assertJsonPath('data.type', 'unit');

        $this->postJson('/api/v1/admin/org-units', ['parent_id' => OrgUnit::where('name', 'Visakhapatnam')->value('id'), 'name' => 'GITAM'])
            ->assertStatus(403);

        $this->assertStringStartsWith(OrgUnit::where('name', 'Hyderabad')->value('path'), OrgUnit::where('name', 'Nizam College')->value('path'));
    }

    public function test_members_without_roles_cannot_use_admin_endpoints(): void
    {
        Sanctum::actingAs($this->member('+919800000001', 'M1'));

        $this->getJson('/api/v1/admin/dashboard')->assertStatus(403);
        $this->getJson('/api/v1/admin/applications')->assertStatus(403);
    }
}
