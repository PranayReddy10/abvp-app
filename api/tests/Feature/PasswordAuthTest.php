<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PasswordAuthTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    public function test_make_admin_with_password_then_sign_in_with_mobile_and_password(): void
    {
        $this->artisan('abvp:make-admin', ['mobile' => '9000000001', 'name' => 'State Admin', '--password' => true])
            ->expectsQuestion('New password (at least 8 characters)', 'Sangathan@2026')
            ->expectsQuestion('Type it again', 'Sangathan@2026')
            ->assertSuccessful();

        $user = User::where('mobile', '+919000000001')->first();
        $this->assertNotSame('Sangathan@2026', $user->getRawOriginal('password'));

        $r = $this->postJson('/api/v1/auth/password', ['login' => '90000 00001', 'password' => 'Sangathan@2026', 'device_name' => 'admin-web'])
            ->assertOk()->assertJsonPath('data.user.has_password', true);
        $this->assertContains('admin.access', $r->json('data.user.permissions'));
        $this->assertArrayNotHasKey('password', $r->json('data.user'));

        $this->postJson('/api/v1/auth/password', ['login' => '9000000001', 'password' => 'wrong-one'])
            ->assertStatus(422)->assertJsonPath('error.code', 'WRONG_PASSWORD');
    }

    public function test_account_without_password_cannot_use_password_sign_in(): void
    {
        User::create(['mobile' => '+919000000002', 'name' => 'No Password']);
        $this->postJson('/api/v1/auth/password', ['login' => '9000000002', 'password' => 'anything123'])
            ->assertStatus(422)->assertJsonPath('error.code', 'WRONG_PASSWORD');
    }

    public function test_set_and_change_password_signs_out_other_devices(): void
    {
        $user = User::create(['mobile' => '+919000000003', 'name' => 'Ravi']);
        $phone = $user->createToken('phone')->plainTextToken;
        $web = $user->createToken('web')->plainTextToken;

        $this->withToken($web)->putJson('/api/v1/me/password', ['password' => 'short', 'password_confirmation' => 'short'])->assertStatus(422);
        $this->withToken($web)->putJson('/api/v1/me/password', ['password' => 'FirstPass1', 'password_confirmation' => 'FirstPass1'])->assertOk();
        $this->assertSame(1, $user->tokens()->count());

        $this->app['auth']->forgetGuards();
        $this->withToken($web)->putJson('/api/v1/me/password', ['current_password' => 'nope', 'password' => 'SecondPass2', 'password_confirmation' => 'SecondPass2'])
            ->assertStatus(422);
        $this->withToken($web)->putJson('/api/v1/me/password', ['current_password' => 'FirstPass1', 'password' => 'SecondPass2', 'password_confirmation' => 'SecondPass2'])->assertOk();
        $this->postJson('/api/v1/auth/password', ['login' => '9000000003', 'password' => 'SecondPass2'])->assertOk();
        $this->assertNotNull($phone);
    }

    public function test_set_password_command_resets_and_signs_out(): void
    {
        $user = User::create(['mobile' => '+919000000004', 'name' => 'Forgetful']);
        $user->createToken('old');
        $this->artisan('abvp:set-password', ['mobile' => '9000000004'])
            ->expectsQuestion('New password (at least 8 characters)', 'NewPass123')
            ->expectsQuestion('Type it again', 'NewPass123')
            ->assertSuccessful();
        $this->assertSame(0, $user->tokens()->count());
        $this->postJson('/api/v1/auth/password', ['login' => '9000000004', 'password' => 'NewPass123'])->assertOk();
    }
}
