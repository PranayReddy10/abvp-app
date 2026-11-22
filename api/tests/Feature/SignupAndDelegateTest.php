<?php

namespace Tests\Feature;

use App\Models\Event;
use App\Models\EventRegistration;
use App\Models\EventTravel;
use App\Models\OrgUnit;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SignupAndDelegateTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    private function conference(array $over = []): Event
    {
        $organiser = User::firstOrCreate(['mobile' => '+919999900001']);
        $e = Event::create($over + [
            'title' => 'Rashtriya Adhiveshan', 'category' => 'conference', 'venue' => 'Bhagyanagar',
            'starts_at' => now()->addDays(10), 'ends_at' => now()->addDays(13), 'capacity' => 2,
            'org_unit_id' => OrgUnit::where('name', 'Telangana')->value('id'), 'organiser_id' => $organiser->id,
            'guide_enabled' => true, 'delegate_registration_open' => true,
        ]);
        $e->forceFill(['status' => 'published', 'published_at' => now()])->save();

        return $e;
    }

    private function form(array $over = []): array
    {
        return $over + [
            'full_name' => 'Rahul Sharma', 'gender' => 'male', 'prant' => 'Delhi', 'institution' => 'Delhi University',
            'food' => 'veg', 'emergency_name' => 'Suresh Sharma', 'emergency_phone' => '9811100000',
            'mode' => 'train', 'reference' => '12723 Telangana Express', 'arriving_at' => now()->addDays(9)->setTime(6, 30)->toIso8601String(),
            'arrival_point' => 'Secunderabad Railway Station', 'departing_at' => now()->addDays(13)->setTime(20, 0)->toIso8601String(),
            'needs_pickup' => true, 'needs_stay' => true,
        ];
    }

    public function test_anyone_signs_up_with_basic_details_and_an_otp(): void
    {
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876500011'])->assertOk();
        $this->postJson('/api/v1/auth/register', [
            'mobile' => '9876500011', 'code' => '123456', 'name' => 'Rahul Sharma', 'email' => 'rahul@example.com',
            'gender' => 'male', 'prant' => 'Delhi', 'institution' => 'Delhi University', 'occupation' => 'Student',
        ])->assertOk()
            ->assertJsonPath('data.is_new_user', true)
            ->assertJsonPath('data.user.name', 'Rahul Sharma')
            ->assertJsonPath('data.user.prant', 'Delhi')
            ->assertJsonPath('data.user.is_member', false)
            ->assertJsonStructure(['data' => ['token']]);

        // Wrong code: nothing is created.
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876500012'])->assertOk();
        $this->postJson('/api/v1/auth/register', ['mobile' => '9876500012', 'code' => '000000', 'name' => 'X Y'])->assertStatus(422);
        $this->assertDatabaseMissing('users', ['mobile' => '+919876500012']);

        // An existing account keeps its name; empty fields are filled.
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876500011'])->assertOk();
        $this->postJson('/api/v1/auth/register', ['mobile' => '9876500011', 'code' => '123456', 'name' => 'Someone Else', 'email' => 'new@example.com'])
            ->assertOk()->assertJsonPath('data.is_new_user', false)->assertJsonPath('data.user.name', 'Rahul Sharma')
            ->assertJsonPath('data.user.email', 'rahul@example.com');
    }

    public function test_delegate_registration_gives_a_pass_and_records_travel(): void
    {
        $event = $this->conference();
        $user = User::create(['mobile' => '+919876500021', 'name' => 'Rahul']);
        Sanctum::actingAs($user);

        $this->getJson("/api/v1/events/{$event->id}/delegate")->assertOk()
            ->assertJsonPath('data.open', true)
            ->assertJsonPath('data.registration', null)
            ->assertJsonPath('data.prefill.full_name', 'Rahul');

        $this->putJson("/api/v1/events/{$event->id}/delegate", $this->form(['emergency_phone' => 'abc']))
            ->assertStatus(422)->assertJsonValidationErrors('emergency_phone', 'error.fields');

        $res = $this->putJson("/api/v1/events/{$event->id}/delegate", $this->form())->assertCreated()
            ->assertJsonPath('data.status', 'registered')
            ->assertJsonPath('data.kind', 'delegate')
            ->assertJsonPath('data.details.prant', 'Delhi')
            ->assertJsonPath('data.travel.arrival_point', 'Secunderabad Railway Station')
            ->assertJsonPath('data.travel.needs_stay', true);
        $this->assertNotNull($res->json('data.pass_token'));
        $this->assertSame('Delhi', $user->fresh()->prant);

        // Editing updates the same registration and travel.
        $this->putJson("/api/v1/events/{$event->id}/delegate", $this->form(['mode' => 'flight', 'arrival_point' => 'RGI Airport']))->assertOk()
            ->assertJsonPath('data.travel.mode', 'flight');
        $this->assertSame(1, EventRegistration::where('event_id', $event->id)->count());
        $this->assertSame(1, EventTravel::where('event_id', $event->id)->count());

        // The pass shows with the other passes.
        $this->getJson('/api/v1/me/passes')->assertOk()->assertJsonPath('data.0.kind', 'delegate')->assertJsonPath('data.0.name', 'Rahul Sharma');

        $this->deleteJson("/api/v1/events/{$event->id}/delegate")->assertOk();
        $this->getJson("/api/v1/events/{$event->id}/delegate")->assertJsonPath('data.registration', null);
    }

    public function test_closed_registration_and_full_events(): void
    {
        $closed = $this->conference(['delegate_registration_open' => false]);
        Sanctum::actingAs(User::create(['mobile' => '+919876500031']));
        $this->putJson("/api/v1/events/{$closed->id}/delegate", $this->form())->assertStatus(403)->assertJsonPath('error.code', 'REGISTRATION_CLOSED');

        $event = $this->conference(['capacity' => 1, 'waitlist_enabled' => true]);
        Sanctum::actingAs(User::create(['mobile' => '+919876500032']));
        $this->putJson("/api/v1/events/{$event->id}/delegate", $this->form())->assertCreated()->assertJsonPath('data.status', 'registered');
        Sanctum::actingAs(User::create(['mobile' => '+919876500033']));
        $this->putJson("/api/v1/events/{$event->id}/delegate", $this->form())->assertCreated()
            ->assertJsonPath('data.status', 'waitlisted')->assertJsonPath('data.pass_token', null);

        $this->putJson('/api/v1/events/999999/delegate', $this->form())->assertNotFound();
    }

    public function test_guide_summary_says_registration_is_open(): void
    {
        $event = $this->conference();
        $this->getJson('/api/v1/guide/events')->assertOk()->assertJsonPath('data.0.event.delegate_registration_open', true);
        $this->getJson("/api/v1/events/{$event->id}/guide")->assertOk()->assertJsonPath('data.event.delegate_registration_open', true);
    }
}
