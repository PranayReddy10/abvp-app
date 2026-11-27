<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\Post;
use App\Models\RoleAssignment;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AccountAdminTest extends TestCase
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

    private function person(): User
    {
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876555111'])->assertOk();
        $this->postJson('/api/v1/auth/register', ['mobile' => '9876555111', 'code' => '123456', 'name' => 'Sita Rao', 'prant' => 'Telangana', 'password' => 'Secret@2026', 'password_confirmation' => 'Secret@2026'])->assertOk();

        return User::where('mobile', '+919876555111')->first();
    }

    public function test_view_block_unblock_and_delete_an_account(): void
    {
        $u = $this->person();
        $token = $u->createToken('phone')->plainTextToken;
        Post::create(['user_id' => $u->id, 'body' => 'hello', 'audience' => 'members']);

        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $this->getJson("/api/v1/admin/accounts/{$u->id}")->assertOk()
            ->assertJsonPath('name', null)->assertJsonPath('data.name', 'Sita Rao')
            ->assertJsonPath('data.status', 'active')->assertJsonPath('data.posts', 1)->assertJsonPath('data.can_manage', true);

        // Block: sessions end and sign-in is refused.
        $this->postJson("/api/v1/admin/accounts/{$u->id}/block", ['blocked' => true, 'reason' => 'Spam'])->assertOk()->assertJsonPath('data.status', 'suspended');
        $this->assertSame(0, $u->tokens()->count());
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/password', ['login' => '9876555111', 'password' => 'Secret@2026'])->assertStatus(403)->assertJsonPath('error.code', 'ACCOUNT_SUSPENDED');

        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $this->postJson("/api/v1/admin/accounts/{$u->id}/block", ['blocked' => false])->assertOk()->assertJsonPath('data.status', 'active');

        // Delete: personal data and posts go, the number is free again.
        $this->deleteJson("/api/v1/admin/accounts/{$u->id}")->assertOk();
        $u->refresh();
        $this->assertSame('deleted', $u->status);
        $this->assertSame('Deleted account', $u->name);
        $this->assertNull($u->profile);
        $this->assertSame(0, Post::where('user_id', $u->id)->count());
        $this->getJson('/api/v1/admin/accounts')->assertJsonMissing(['name' => 'Deleted account']);
        $this->assertTrue(collect($this->getJson('/api/v1/admin/audit-logs')->json('data'))->contains('action', 'account.deleted'));

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876555111'])->assertOk();
        $this->postJson('/api/v1/auth/register', ['mobile' => '9876555111', 'code' => '123456', 'name' => 'Sita Again'])->assertOk()->assertJsonPath('data.is_new_user', true);
        $this->assertNotNull($token);
    }

    public function test_admins_and_yourself_are_protected_and_area_is_respected(): void
    {
        $super = $this->admin('super_admin', 'Bharat');
        $state = $this->admin('state_admin', 'Telangana');
        Sanctum::actingAs($state);
        $this->postJson("/api/v1/admin/accounts/{$state->id}/block", ['blocked' => true])->assertStatus(403)->assertJsonPath('error.code', 'PROTECTED_ACCOUNT');
        $this->deleteJson("/api/v1/admin/accounts/{$super->id}")->assertStatus(403);

        $goa = User::create(['mobile' => '+919876555222', 'name' => 'Goa Person', 'prant' => 'Goa']);
        $this->getJson("/api/v1/admin/accounts/{$goa->id}")->assertStatus(403)->assertJsonPath('error.code', 'FORBIDDEN_SCOPE');

        $local = $this->person(); // prant Telangana, no district yet
        Sanctum::actingAs($state);
        $this->postJson("/api/v1/admin/accounts/{$local->id}/block", ['blocked' => true])->assertOk();

        // Only a super admin acts on someone with an admin role.
        Sanctum::actingAs($super);
        $this->postJson("/api/v1/admin/accounts/{$state->id}/block", ['blocked' => true])->assertOk();
    }

    public function test_admin_adds_a_member_with_an_area_and_password(): void
    {
        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $hyd = OrgUnit::where('name', 'Hyderabad')->value('id');
        $r = $this->postJson('/api/v1/admin/accounts', ['name' => 'Ravi Kumar', 'mobile' => '9876544410', 'org_unit_id' => $hyd, 'password' => 'Secret@2026', 'approve' => true])
            ->assertCreated();
        $this->assertNotEmpty($r->json('data.member_id'));
        $u = User::where('mobile', '+919876544410')->firstOrFail();
        $this->assertSame('approved', $u->profile->membership_status);
        $this->assertSame($hyd, $u->profile->org_unit_id);
        $this->postJson('/api/v1/admin/accounts', ['name' => 'Again', 'mobile' => '9876544410'])->assertStatus(409)->assertJsonPath('error.code', 'ACCOUNT_EXISTS');

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/password', ['login' => '9876544410', 'password' => 'Secret@2026'])->assertOk();
    }

    public function test_district_admin_adds_only_inside_their_area(): void
    {
        Sanctum::actingAs($this->admin('district_admin', 'Hyderabad'));
        $this->postJson('/api/v1/admin/accounts', ['name' => 'Out Side', 'mobile' => '9876544411'])->assertStatus(403);
        $this->postJson('/api/v1/admin/accounts', ['name' => 'In Side', 'mobile' => '9876544411', 'org_unit_id' => OrgUnit::where('name', 'Hyderabad')->value('id')])->assertCreated();
    }

    public function test_admin_edits_details_photo_verifies_and_fills_the_delegate_form(): void
    {
        Storage::fake('local');
        $u = $this->person();
        $this->assertSame('approved', $u->profile->membership_status); // everyone who signs up is a member
        $this->assertFalse($u->profile->isVerified());

        $organiser = User::firstOrCreate(['mobile' => '+919999900001']);
        $e = \App\Models\Event::create(['title' => '72nd National Conference', 'category' => 'conference', 'venue' => 'Bhagyanagar',
            'starts_at' => now()->addDays(10), 'ends_at' => now()->addDays(13), 'org_unit_id' => OrgUnit::where('name', 'Telangana')->value('id'),
            'organiser_id' => $organiser->id, 'guide_enabled' => true, 'delegate_registration_open' => false]);
        $e->forceFill(['status' => 'published', 'published_at' => now()])->save();

        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $hyd = OrgUnit::where('name', 'Hyderabad')->value('id');
        $this->patchJson("/api/v1/admin/accounts/{$u->id}", ['full_name' => 'Sita Ramesh Rao', 'gender' => 'female', 'org_unit_id' => $hyd, 'institution' => 'Osmania University'])
            ->assertOk()->assertJsonPath('data.name', 'Sita Ramesh Rao')->assertJsonPath('data.prant', 'Telangana');
        $this->assertSame($hyd, $u->profile->fresh()->org_unit_id);

        $this->post("/api/v1/admin/accounts/{$u->id}/photo", ['photo' => UploadedFile::fake()->image('me.jpg', 400, 400)], ['Accept' => 'application/json'])->assertOk();
        $this->assertNotNull($u->profile->fresh()->photo_path);
        $this->deleteJson("/api/v1/admin/accounts/{$u->id}/photo")->assertOk();
        $this->assertNull($u->profile->fresh()->photo_path);

        $this->postJson("/api/v1/admin/accounts/{$u->id}/verify", ['verified' => true])->assertOk()->assertJsonPath('data.verified', true);
        $this->getJson('/api/v1/admin/accounts?status=verified')->assertJsonFragment(['name' => 'Sita Ramesh Rao']);

        // Registration is closed, but an admin can still fill the person's delegate form.
        $this->putJson("/api/v1/admin/accounts/{$u->id}/delegate", [
            'first_name' => 'Sita', 'surname' => 'Rao', 'mobile' => '9876555111', 'gender' => 'female', 'prant' => 'Telangana',
            'responsibility' => 'Karyakarta', 'mode' => 'train', 'reference' => '12723',
            'arriving_at' => now()->addDays(9)->toIso8601String(), 'arrival_point' => 'Secunderabad',
            'departing_at' => now()->addDays(13)->toIso8601String(),
        ])->assertOk()->assertJsonPath('data.delegate.registration.details.responsibility', 'Karyakarta');
    }
}
