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

class AccountsListTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
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

    public function test_new_sign_ups_show_in_accounts_and_audit_log_by_name(): void
    {
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876511111'])->assertOk();
        $this->postJson('/api/v1/auth/register', ['mobile' => '9876511111', 'code' => '123456', 'name' => 'Sita Rao', 'prant' => 'Telangana'])->assertOk();
        User::create(['mobile' => '+919876522222', 'name' => 'Arjun Goa', 'prant' => 'Goa']);

        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $rows = collect($this->getJson('/api/v1/admin/accounts')->assertOk()->json('data'));
        $this->assertTrue($rows->contains('name', 'Sita Rao'));
        $this->assertSame('draft', $rows->firstWhere('name', 'Sita Rao')['membership']);
        $this->getJson('/api/v1/admin/accounts?status=approved')->assertOk()->assertJsonMissing(['name' => 'Sita Rao']);
        $this->getJson('/api/v1/admin/accounts?q=Sita')->assertOk()->assertJsonCount(1, 'data');

        $log = collect($this->getJson('/api/v1/admin/audit-logs')->assertOk()->json('data'))->firstWhere('action', 'auth.signed_up');
        $this->assertStringStartsWith('Sita Rao', $log['subject']);

        // A Telangana state admin sees Telangana sign-ups, not Goa's.
        Sanctum::actingAs($this->admin('state_admin', 'Telangana'));
        $names = collect($this->getJson('/api/v1/admin/accounts')->assertOk()->json('data'))->pluck('name');
        $this->assertContains('Sita Rao', $names);
        $this->assertNotContains('Arjun Goa', $names);
    }
}
