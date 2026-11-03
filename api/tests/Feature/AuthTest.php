<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_new_user_signs_in_with_otp(): void
    {
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '98480 12345'])
            ->assertOk()
            ->assertJsonPath('data.mobile', '+91 98xxx xx345');

        $res = $this->postJson('/api/v1/auth/verify-otp', ['mobile' => '+919848012345', 'code' => '123456'])
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.is_new_user', true);

        $token = $res->json('data.token');
        $this->assertDatabaseHas('users', ['mobile' => '+919848012345']);

        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.mobile', '+919848012345')
            ->assertJsonPath('data.profile', null);
    }

    public function test_wrong_code_is_rejected_and_attempts_are_limited(): void
    {
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9848012345'])->assertOk();

        $this->postJson('/api/v1/auth/verify-otp', ['mobile' => '9848012345', 'code' => '000000'])
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'OTP_INVALID');

        foreach (range(1, 4) as $_) {
            $this->postJson('/api/v1/auth/verify-otp', ['mobile' => '9848012345', 'code' => '000000']);
        }

        $this->postJson('/api/v1/auth/verify-otp', ['mobile' => '9848012345', 'code' => '123456'])
            ->assertStatus(429);
    }

    public function test_invalid_mobile_is_refused(): void
    {
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '12345'])
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_MOBILE');
    }

    public function test_code_cannot_be_reused(): void
    {
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9848012345']);
        $this->postJson('/api/v1/auth/verify-otp', ['mobile' => '9848012345', 'code' => '123456'])->assertOk();

        $this->postJson('/api/v1/auth/verify-otp', ['mobile' => '9848012345', 'code' => '123456'])
            ->assertJsonPath('error.code', 'OTP_EXPIRED');
    }

    public function test_protected_routes_need_a_token(): void
    {
        $this->getJson('/api/v1/auth/me')->assertStatus(401)->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    public function test_suspended_account_cannot_sign_in(): void
    {
        User::create(['mobile' => '+919848012345', 'status' => 'suspended']);
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9848012345']);

        $this->postJson('/api/v1/auth/verify-otp', ['mobile' => '9848012345', 'code' => '123456'])
            ->assertStatus(403)
            ->assertJsonPath('error.code', 'ACCOUNT_SUSPENDED');
    }
}
