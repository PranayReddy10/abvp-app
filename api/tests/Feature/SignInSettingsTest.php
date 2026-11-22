<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\RoleAssignment;
use App\Models\Setting;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SignInSettingsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    private function admin(string $role, string $unit, ?string $password = null): User
    {
        $u = User::create(['mobile' => '+919700'.random_int(100000, 999999)]);
        if ($password) {
            $u->forceFill(['password' => $password])->save();
        }
        $p = new MemberProfile(['full_name' => 'Admin', 'org_unit_id' => OrgUnit::where('name', $unit)->value('id')]);
        $p->user_id = $u->id;
        $p->member_id = 'A'.$u->id;
        $p->membership_status = 'approved';
        $p->save();
        RoleAssignment::create(['user_id' => $u->id, 'role' => $role, 'org_unit_id' => OrgUnit::where('name', $unit)->value('id')]);

        return $u;
    }

    public function test_only_super_admins_see_sign_in_settings(): void
    {
        Sanctum::actingAs($this->admin('state_admin', 'Telangana'));
        $this->getJson('/api/v1/admin/settings/sign-in')->assertStatus(403);
        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $this->getJson('/api/v1/admin/settings/sign-in')->assertOk()
            ->assertJsonPath('data.otp_enabled', true)->assertJsonPath('data.sms_driver', 'log');
    }

    public function test_switching_codes_off_needs_own_password_then_blocks_codes(): void
    {
        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $this->putJson('/api/v1/admin/settings/sign-in', ['otp_enabled' => false, 'sms_driver' => 'log'])
            ->assertStatus(422)->assertJsonPath('error.code', 'PASSWORD_FIRST');

        Sanctum::actingAs($this->admin('super_admin', 'Bharat', 'StrongPass1'));
        $this->putJson('/api/v1/admin/settings/sign-in', ['otp_enabled' => false, 'sms_driver' => 'log'])
            ->assertOk()->assertJsonPath('data.otp_enabled', false);

        $this->getJson('/api/v1/auth/options')->assertOk()->assertJsonPath('data.otp', false)->assertJsonPath('data.password', true);
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876543210'])->assertStatus(403)->assertJsonPath('error.code', 'OTP_DISABLED');

        $this->putJson('/api/v1/admin/settings/sign-in', ['otp_enabled' => true, 'sms_driver' => 'log'])->assertOk();
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876543210'])->assertOk();
    }

    public function test_msg91_saved_in_settings_is_used_and_key_is_encrypted(): void
    {
        Http::fake(['control.msg91.com/*' => Http::response(['type' => 'success'])]);
        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $this->putJson('/api/v1/admin/settings/sign-in', ['otp_enabled' => true, 'sms_driver' => 'msg91'])
            ->assertStatus(422)->assertJsonPath('error.code', 'MSG91_INCOMPLETE');
        $this->putJson('/api/v1/admin/settings/sign-in', ['otp_enabled' => true, 'sms_driver' => 'msg91', 'msg91_key' => '123456ABCDEFabcdef7890', 'msg91_template' => 'tmpl-otp-1'])
            ->assertOk()->assertJsonPath('data.sms_driver', 'msg91')->assertJsonPath('data.msg91.key_hint', '1234…7890');
        $this->assertNotSame('123456ABCDEFabcdef7890', Setting::find('sms.msg91_key_secret')->value);

        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876543210'])->assertOk();
        Http::assertSent(fn ($r) => $r->hasHeader('authkey', '123456ABCDEFabcdef7890') && $r['template_id'] === 'tmpl-otp-1' && $r['recipients'][0]['mobiles'] === '919876543210');

        $this->postJson('/api/v1/admin/settings/sign-in/test-sms', ['mobile' => '9876543210'])->assertOk();
    }

    public function test_sms_failure_gives_a_clear_message(): void
    {
        Http::fake(['control.msg91.com/*' => Http::response(['type' => 'error', 'message' => 'Invalid template'], 400)]);
        Setting::putMany(['sms.driver' => 'msg91', 'sms.msg91_key_secret' => 'k', 'sms.msg91_template' => 't']);
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876543210'])->assertStatus(503)->assertJsonPath('error.code', 'SMS_FAILED');
    }

    public function test_with_codes_off_sign_up_uses_a_password_and_never_takes_over_an_account(): void
    {
        Setting::putMany(['auth.otp_enabled' => '0']);
        $form = ['mobile' => '9876500001', 'name' => 'Sita Rao', 'prant' => 'Telangana', 'device_name' => 'web'];

        $this->postJson('/api/v1/auth/register', $form)->assertStatus(422)->assertJsonStructure(['error' => ['fields' => ['password']]]);
        $r = $this->postJson('/api/v1/auth/register', $form + ['password' => 'Delegate@26', 'password_confirmation' => 'Delegate@26'])
            ->assertOk()->assertJsonPath('data.is_new_user', true)->assertJsonPath('data.user.has_password', true);
        $this->assertNotEmpty($r->json('data.token'));
        $this->assertNull(User::where('mobile', '+919876500001')->value('mobile_verified_at'));

        // Same number again: refused, the first account is untouched.
        $this->postJson('/api/v1/auth/register', ['name' => 'Someone Else', 'password' => 'Other@2026', 'password_confirmation' => 'Other@2026'] + $form)
            ->assertStatus(409)->assertJsonPath('error.code', 'ACCOUNT_EXISTS');
        $this->assertSame('Sita Rao', User::where('mobile', '+919876500001')->value('name'));

        $this->postJson('/api/v1/auth/password', ['login' => '98765 00001', 'password' => 'Delegate@26'])->assertOk();
    }

    public function test_with_codes_on_sign_up_still_needs_the_code(): void
    {
        $this->postJson('/api/v1/auth/register', ['mobile' => '9876500002', 'name' => 'Ravi', 'password' => 'Delegate@26', 'password_confirmation' => 'Delegate@26'])
            ->assertStatus(422)->assertJsonStructure(['error' => ['fields' => ['code']]]);
    }
}
