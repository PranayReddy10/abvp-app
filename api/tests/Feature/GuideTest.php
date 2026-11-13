<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Event;
use App\Models\EventRegistration;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\RoleAssignment;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class GuideTest extends TestCase
{
    use RefreshDatabase;

    private int $seq = 0;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
        Storage::fake('local');
    }

    private function member(string $name, string $unit = 'Osmania University'): User
    {
        $this->seq++;
        $u = User::create(['mobile' => '+9196000'.str_pad((string) $this->seq, 5, '0', STR_PAD_LEFT)]);
        $p = new MemberProfile(['full_name' => $name, 'org_unit_id' => OrgUnit::where('name', $unit)->value('id')]);
        $p->user_id = $u->id;
        $p->member_id = 'G'.$this->seq;
        $p->membership_status = 'approved';
        $p->save();

        return $u;
    }

    private function admin(): User
    {
        $u = $this->member('Organiser');
        RoleAssignment::create(['user_id' => $u->id, 'role' => 'state_admin', 'org_unit_id' => OrgUnit::where('name', 'Telangana')->value('id')]);

        return $u;
    }

    private function conference(User $organiser): Event
    {
        $e = Event::create([
            'title' => 'Rashtriya Adhiveshan', 'category' => 'conference', 'venue' => 'Adhiveshan Nagar, Hyderabad',
            'starts_at' => now()->addDay(), 'ends_at' => now()->addDays(4), 'org_unit_id' => OrgUnit::where('name', 'Telangana')->value('id'),
            'organiser_id' => $organiser->id, 'capacity' => 5000,
        ]);
        $e->forceFill(['status' => 'published', 'published_at' => now()])->save();

        return $e;
    }

    private function register(User $u, Event $e): void
    {
        EventRegistration::create(['event_id' => $e->id, 'user_id' => $u->id, 'kind' => 'member', 'status' => 'registered']);
    }

    public function test_organiser_builds_the_guide_and_delegates_see_it_with_leads(): void
    {
        $admin = $this->admin();
        $event = $this->conference($admin);
        $lead = $this->member('Akhil Kumar');
        $delegate = $this->member('Rahul Sharma');
        $this->register($delegate, $event);

        Sanctum::actingAs($admin);
        $this->putJson("/api/v1/admin/events/{$event->id}/guide/settings", ['guide_enabled' => true, 'venue_lat' => 17.385, 'venue_lng' => 78.4867, 'helpline_phone' => '1800 123 4567'])
            ->assertOk()->assertJsonPath('data.settings.guide_enabled', true);

        $airport = $this->postJson("/api/v1/admin/events/{$event->id}/guide/items", [
            'kind' => 'arrival', 'title' => 'RGI Airport', 'subtitle' => 'Arrivals, Gate 4', 'lat' => 17.2403, 'lng' => 78.4294,
            'travel_time' => '50 min by shuttle', 'steps' => ['Exit at Gate 4', 'Find the saffron ABVP desk', 'Board the shuttle to the venue', ''],
            'contacts' => [['member_id' => 'NOPE-404', 'role' => 'Desk lead', 'is_lead' => true], ['name' => 'Sai', 'phone' => '9000000002', 'role' => 'Volunteer']],
        ]);
        // An unknown Member ID is refused with a clear message.
        $airport->assertStatus(422);

        $airport = $this->postJson("/api/v1/admin/events/{$event->id}/guide/items", [
            'kind' => 'arrival', 'title' => 'RGI Airport', 'subtitle' => 'Arrivals, Gate 4', 'lat' => 17.2403, 'lng' => 78.4294,
            'travel_time' => '50 min by shuttle', 'steps' => ['Exit at Gate 4', 'Find the saffron ABVP desk', 'Board the shuttle to the venue', ''],
            'contacts' => [['member_id' => $lead->profile->member_id, 'role' => 'Desk lead', 'is_lead' => true], ['name' => 'Sai', 'phone' => '9000000002', 'role' => 'Volunteer']],
        ])->assertCreated()
            ->assertJsonPath('data.contacts.0.name', 'Akhil Kumar')
            ->assertJsonPath('data.contacts.0.is_lead', true)
            ->assertJsonPath('data.steps', ['Exit at Gate 4', 'Find the saffron ABVP desk', 'Board the shuttle to the venue']);
        $this->assertFalse($airport->json('data.distance_is_road'));
        $this->assertEqualsWithDelta(16.4, $airport->json('data.distance_km'), 1.0);
        $this->assertStringContainsString('travelmode=transit', $airport->json('data.directions_url'));

        $this->postJson("/api/v1/admin/events/{$event->id}/guide/items", ['kind' => 'stay', 'title' => 'SVIT Engineering College'])
            ->assertStatus(422)->assertJsonValidationErrors('region', 'error.fields');
        $this->postJson("/api/v1/admin/events/{$event->id}/guide/items", [
            'kind' => 'stay', 'title' => 'SVIT Engineering College', 'region' => 'Konkan (Mumbai)', 'location' => 'Boys hostel, Block B',
            'contacts' => [['name' => 'Saicharan', 'phone' => '9000000003', 'is_lead' => true]],
        ])->assertCreated();
        $this->postJson("/api/v1/admin/events/{$event->id}/guide/items", [
            'kind' => 'stay', 'title' => 'Keshav Hostel', 'region' => 'Telangana', 'tags' => ['Girls'],
        ])->assertCreated();
        $this->postJson("/api/v1/admin/events/{$event->id}/guide/items", [
            'kind' => 'food', 'title' => 'Telangana Ruchulu', 'location' => 'Hall B, Stall 7', 'landmark' => 'Green flag with a lotus', 'color' => '#2E8B57', 'tags' => ['Veg'],
        ])->assertCreated()->assertJsonPath('data.color', '#2E8B57');
        $this->assertSame(4, AuditLog::where('action', 'guide.created')->count());

        // Delegate: hub, my prant's stay, sections with phones.
        Sanctum::actingAs($delegate);
        $this->getJson('/api/v1/me/guide-events')->assertOk()->assertJsonPath('data.0.event.id', $event->id)->assertJsonPath('data.0.open_first', true);
        $hub = $this->getJson("/api/v1/events/{$event->id}/guide")->assertOk()
            ->assertJsonPath('my_region', null)
            ->assertJsonPath('data.event.helpline', '1800 123 4567')
            ->assertJsonPath('data.my_region', 'Telangana')
            ->assertJsonPath('data.my_stays.0.title', 'Keshav Hostel');
        $sections = collect($hub->json('data.sections'))->keyBy('kind');
        $this->assertSame(2, $sections['stay']['count']);
        $this->assertSame(1, $sections['arrival']['count']);
        $this->assertSame('निवास', $sections['stay']['hindi']);

        $stays = $this->getJson("/api/v1/events/{$event->id}/guide/stay")->assertOk();
        $this->assertSame(['Konkan (Mumbai)', 'Telangana'], collect($stays->json('meta.regions'))->pluck('region')->all());
        $this->getJson("/api/v1/events/{$event->id}/guide/arrival")->assertOk()
            ->assertJsonPath('data.0.contacts.0.phone', $lead->mobile)
            ->assertJsonPath('data.0.contacts.1.phone', '9000000002');
        $this->getJson("/api/v1/events/{$event->id}/guide/nonsense")->assertNotFound();
    }

    public function test_anyone_can_open_the_guide_once_it_is_switched_on(): void
    {
        $admin = $this->admin();
        $event = $this->conference($admin);
        $outsider = $this->member('Not registered');

        // Off: hidden from everyone.
        $this->getJson("/api/v1/events/{$event->id}/guide")->assertNotFound();
        $this->getJson('/api/v1/guide/events')->assertOk()->assertJsonCount(0, 'data');

        $event->forceFill(['guide_enabled' => true])->save();

        // A guest with no account and no registration.
        $this->getJson('/api/v1/guide/events')->assertOk()->assertJsonPath('data.0.event.id', $event->id);
        $this->getJson("/api/v1/events/{$event->id}/guide")->assertOk()
            ->assertJsonPath('data.signed_in', false)
            ->assertJsonPath('data.my_region', null)
            ->assertJsonPath('data.open_tickets', 0);
        $this->getJson("/api/v1/events/{$event->id}/guide/food")->assertOk();

        // Signed in but not registered: sees it, gets "my prant", and can raise a support ticket.
        Sanctum::actingAs($outsider);
        $this->getJson('/api/v1/me/guide-events')->assertOk()->assertJsonCount(1, 'data');
        $this->getJson("/api/v1/events/{$event->id}/guide")->assertOk()->assertJsonPath('data.my_region', 'Telangana');
        $this->postJson("/api/v1/events/{$event->id}/help", ['category' => 'venue', 'message' => 'Where is the Telangana stall?'])->assertCreated();
        $this->getJson("/api/v1/events/{$event->id}/announcements")->assertOk();

        // Drafts never show, even with the switch on.
        $draft = Event::create(['title' => 'Draft', 'category' => 'conference', 'venue' => 'x', 'starts_at' => now()->addDay(), 'ends_at' => now()->addDays(2),
            'org_unit_id' => $event->org_unit_id, 'organiser_id' => $admin->id, 'guide_enabled' => true]);
        $this->getJson("/api/v1/events/{$draft->id}/guide")->assertNotFound();

        // Organisers outside the event's area cannot edit it.
        $other = $this->member('Delhi admin');
        RoleAssignment::create(['user_id' => $other->id, 'role' => 'state_admin', 'org_unit_id' => OrgUnit::where('type', 'state')->where('name', '!=', 'Telangana')->value('id')]);
        Sanctum::actingAs($other);
        $this->getJson("/api/v1/admin/events/{$event->id}/guide")->assertStatus(403);
    }

    public function test_photos_edit_reorder_and_delete(): void
    {
        $admin = $this->admin();
        $event = $this->conference($admin);
        Sanctum::actingAs($admin);
        $a = $this->postJson("/api/v1/admin/events/{$event->id}/guide/items", ['kind' => 'exhibit', 'title' => 'History of Telangana'])->json('data.id');
        $b = $this->postJson("/api/v1/admin/events/{$event->id}/guide/items", ['kind' => 'exhibit', 'title' => 'Martyrs of ABVP'])->json('data.id');

        $this->post("/api/v1/admin/guide-items/{$a}/photos", ['photo' => UploadedFile::fake()->image('a.jpg', 1200, 800)], ['Accept' => 'application/json'])
            ->assertOk()->assertJsonCount(1, 'data.photo_urls');
        $res = $this->post("/api/v1/admin/guide-items/{$a}/photos", ['photo' => UploadedFile::fake()->image('b.jpg')], ['Accept' => 'application/json'])->assertOk();
        $this->get($res->json('data.photo_urls.1'))->assertOk();
        $this->deleteJson("/api/v1/admin/guide-items/{$a}/photos/0")->assertOk()->assertJsonCount(1, 'data.photo_urls');

        $this->patchJson("/api/v1/admin/guide-items/{$a}", ['title' => 'History of Telangana', 'description' => 'From Kakatiyas to today.', 'color' => 'orange'])
            ->assertStatus(422)->assertJsonValidationErrors('color', 'error.fields');
        $this->patchJson("/api/v1/admin/guide-items/{$a}", ['title' => 'Telangana through the ages', 'description' => 'From the Kakatiyas to today.'])
            ->assertOk()->assertJsonPath('data.title', 'Telangana through the ages')->assertJsonPath('data.kind', 'exhibit');

        $this->postJson("/api/v1/admin/events/{$event->id}/guide/reorder", ['ids' => [$b, $a]])->assertOk();
        $titles = collect($this->getJson("/api/v1/admin/events/{$event->id}/guide")->json('data.items'))->pluck('title')->all();
        $this->assertSame(['Martyrs of ABVP', 'Telangana through the ages'], $titles);

        $this->deleteJson("/api/v1/admin/guide-items/{$b}")->assertOk();
        $this->assertCount(1, $this->getJson("/api/v1/admin/events/{$event->id}/guide")->json('data.items'));
    }

    public function test_support_chat_between_a_guest_and_the_help_desk(): void
    {
        $admin = $this->admin();
        $event = $this->conference($admin);
        $event->forceFill(['guide_enabled' => true])->save();
        $guest = $this->member('Guest from Delhi');
        $stranger = $this->member('Someone else');

        Sanctum::actingAs($guest);
        $id = $this->postJson("/api/v1/events/{$event->id}/help", ['category' => 'chat', 'message' => 'Which bus goes to Block G?'])
            ->assertCreated()->assertJsonPath('data.category_label', 'Chat with the help desk')->json('data.id');

        Sanctum::actingAs($admin);
        $this->postJson("/api/v1/help/{$id}/reply", ['body' => 'Bus 4 from Gate 2, every 20 minutes.'])->assertOk()
            ->assertJsonPath('data.replies.0.mine', true)
            ->assertJsonPath('data.status', 'in_progress');

        Sanctum::actingAs($guest);
        $this->getJson("/api/v1/help/{$id}")->assertOk()
            ->assertJsonPath('data.replies.0.from_team', true)
            ->assertJsonPath('data.replies.0.mine', false)
            ->assertJsonPath('data.replies.0.body', 'Bus 4 from Gate 2, every 20 minutes.');
        $this->postJson("/api/v1/help/{$id}/reply", ['body' => 'Thank you!'])->assertOk()->assertJsonPath('data.replies.1.mine', true);
        $this->assertDatabaseHas('app_notifications', ['user_id' => $guest->id, 'type' => 'help_reply']);

        Sanctum::actingAs($stranger);
        $this->getJson("/api/v1/help/{$id}")->assertStatus(403);
        $this->postJson("/api/v1/help/{$id}/reply", ['body' => 'hi'])->assertStatus(403);
    }
}
