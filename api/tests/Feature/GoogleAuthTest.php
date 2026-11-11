<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class GoogleAuthTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
        config(['services.google.client_ids' => 'web-client.apps.googleusercontent.com, android-client.apps.googleusercontent.com']);
    }

    private function googleSays(array $claims, int $status = 200): void
    {
        Http::fake(['oauth2.googleapis.com/*' => Http::response($claims + [
            'iss' => 'https://accounts.google.com', 'aud' => 'android-client.apps.googleusercontent.com', 'sub' => '1122334455',
            'email' => 'ravi@example.com', 'email_verified' => 'true', 'name' => 'Ravi', 'exp' => (string) (time() + 600),
        ], $status)]);
    }

    public function test_first_google_sign_in_links_after_one_otp_then_signs_in_directly(): void
    {
        $this->googleSays([]);
        $first = $this->postJson('/api/v1/auth/google', ['id_token' => 'token-from-phone'])->assertOk()
            ->assertJsonPath('data.linked', false)
            ->assertJsonPath('data.email', 'ravi@example.com');
        $this->assertArrayNotHasKey('token', $first->json('data'));
        $link = $first->json('data.link_token');

        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876543210'])->assertOk();
        $this->postJson('/api/v1/auth/verify-otp', ['mobile' => '9876543210', 'code' => '123456', 'google_link_token' => $link])
            ->assertOk()->assertJsonPath('data.google_linked', true);
        $user = User::where('mobile', '+919876543210')->first();
        $this->assertSame('1122334455', $user->google_id);
        $this->assertSame('ravi@example.com', $user->google_email);

        // Next time: straight in.
        $this->postJson('/api/v1/auth/google', ['id_token' => 'token-again'])->assertOk()
            ->assertJsonPath('data.linked', true)
            ->assertJsonPath('data.is_new_user', false)
            ->assertJsonStructure(['data' => ['token', 'user']]);

        // The same Google account cannot be linked to a second number.
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876500000'])->assertOk();
        $this->postJson('/api/v1/auth/verify-otp', ['mobile' => '9876500000', 'code' => '123456', 'google_link_token' => $link])
            ->assertStatus(409)->assertJsonPath('error.code', 'GOOGLE_ALREADY_LINKED');
    }

    public function test_tokens_for_other_apps_unverified_or_expired_are_refused(): void
    {
        $this->googleSays(['aud' => 'someone-elses-app.apps.googleusercontent.com']);
        $this->postJson('/api/v1/auth/google', ['id_token' => 'x'])->assertStatus(401)->assertJsonPath('error.code', 'GOOGLE_TOKEN_INVALID');

        $this->googleSays(['email_verified' => 'false']);
        $this->postJson('/api/v1/auth/google', ['id_token' => 'x'])->assertStatus(401);

        $this->googleSays(['exp' => (string) (time() - 5)]);
        $this->postJson('/api/v1/auth/google', ['id_token' => 'x'])->assertStatus(401);

        $this->googleSays(['error' => 'invalid_token'], 400);
        $this->postJson('/api/v1/auth/google', ['id_token' => 'x'])->assertStatus(401);

        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876543210'])->assertOk();
        $this->postJson('/api/v1/auth/verify-otp', ['mobile' => '9876543210', 'code' => '123456', 'google_link_token' => 'tampered'])
            ->assertStatus(422)->assertJsonPath('error.code', 'GOOGLE_LINK_INVALID');
    }

    public function test_without_client_ids_google_sign_in_says_it_is_not_set_up(): void
    {
        config(['services.google.client_ids' => '']);
        $this->postJson('/api/v1/auth/google', ['id_token' => 'x'])->assertStatus(503)->assertJsonPath('error.code', 'GOOGLE_NOT_CONFIGURED');
    }

    public function test_suspended_members_cannot_sign_in_with_google(): void
    {
        $u = User::create(['mobile' => '+919811111111']);
        $u->forceFill(['google_id' => '1122334455', 'status' => 'suspended'])->save();
        $this->googleSays([]);
        $this->postJson('/api/v1/auth/google', ['id_token' => 'x'])->assertStatus(403)->assertJsonPath('error.code', 'ACCOUNT_SUSPENDED');
    }
}
