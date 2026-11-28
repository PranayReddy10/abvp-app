<?php

namespace Tests\Feature;

use App\Models\Event;
use App\Models\EventRegistration;
use App\Models\EventTeam;
use App\Models\EventTeamMember;
use App\Models\GuideItem;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\Post;
use App\Models\RoleAssignment;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SearchAndSiteTest extends TestCase
{
    use RefreshDatabase;

    private int $seq = 0;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    private function member(string $name): User
    {
        $this->seq++;
        $u = User::create(['mobile' => '+9196100'.str_pad((string) $this->seq, 5, '0', STR_PAD_LEFT)]);
        $p = new MemberProfile(['full_name' => $name, 'org_unit_id' => OrgUnit::where('name', 'Telangana')->value('id')]);
        $p->user_id = $u->id;
        $p->member_id = 'S'.$this->seq;
        $p->membership_status = 'approved';
        $p->save();

        return $u;
    }

    private function world(): array
    {
        $organiser = $this->member('Organiser');
        $e = Event::create([
            'title' => 'Rashtriya Adhiveshan', 'category' => 'conference', 'venue' => 'Adhiveshan Nagar, Hyderabad',
            'starts_at' => now()->addDay(), 'ends_at' => now()->addDays(4), 'org_unit_id' => OrgUnit::where('name', 'Telangana')->value('id'),
            'organiser_id' => $organiser->id, 'capacity' => 5000,
        ]);
        $e->forceFill(['status' => 'published', 'published_at' => now()])->save();
        GuideItem::create(['event_id' => $e->id, 'kind' => 'food', 'title' => 'Annapurna Hall', 'location' => 'Block C', 'sort' => 1]);
        $ghat = EventTeam::create(['event_id' => $e->id, 'kind' => 'ghat', 'name' => 'Bhojan']);
        $dept = EventTeam::create(['event_id' => $e->id, 'parent_id' => $ghat->id, 'kind' => 'department', 'name' => 'Annapurna kitchen']);
        EventTeamMember::create(['team_id' => $dept->id, 'name' => 'Nandu Rao', 'mobile' => '+919800011111', 'role' => 'pramukh']);
        $author = $this->member('Annapurna Sharma');
        Post::create(['user_id' => $author->id, 'body' => 'Annapurna kitchen needs volunteers tomorrow', 'audience' => 'members']);

        return [$e, $author];
    }

    public function test_signed_out_people_only_find_events(): void
    {
        $this->world();
        $r = $this->getJson('/api/v1/search?q=adhiveshan')->assertOk();
        $r->assertJsonPath('data.signed_in', false)->assertJsonCount(1, 'data.events');
        $this->getJson('/api/v1/search?q=annapurna')->assertOk()
            ->assertJsonCount(0, 'data.guide')->assertJsonCount(0, 'data.people')
            ->assertJsonCount(0, 'data.members')->assertJsonCount(0, 'data.posts');
        $this->getJson('/api/v1/search?q=a')->assertStatus(422);
    }

    public function test_signed_in_find_people_members_posts_and_delegates_their_guide(): void
    {
        [$e] = $this->world();
        $me = $this->member('Ravi Kumar');
        Sanctum::actingAs($me);
        $r = $this->getJson('/api/v1/search?q=annapurna')->assertOk();
        $r->assertJsonCount(0, 'data.guide') // not a delegate yet
            ->assertJsonPath('data.people.0.name', 'Nandu Rao')->assertJsonPath('data.people.0.ghat', 'Bhojan')
            ->assertJsonPath('data.members.0.name', 'Annapurna Sharma')
            ->assertJsonCount(1, 'data.posts');

        EventRegistration::create(['event_id' => $e->id, 'user_id' => $me->id, 'kind' => 'delegate', 'status' => 'registered']);
        $this->getJson('/api/v1/search?q=annapurna')->assertOk()
            ->assertJsonPath('data.guide.0.title', 'Annapurna Hall')->assertJsonPath('data.guide.0.kind_label', 'Food');
        // Wildcards are searched as plain text.
        $this->getJson('/api/v1/search?q=%25%25')->assertOk()->assertJsonCount(0, 'data.members');
    }

    public function test_super_admin_sets_analytics_and_verification_and_the_site_reads_them(): void
    {
        $this->getJson('/api/v1/site')->assertOk()->assertJsonPath('data.ga_id', null);
        $admin = $this->member('Admin');
        RoleAssignment::create(['user_id' => $admin->id, 'role' => 'state_admin', 'org_unit_id' => OrgUnit::where('name', 'Telangana')->value('id')]);
        Sanctum::actingAs($admin);
        $this->putJson('/api/v1/admin/settings/website', ['ga_id' => 'G-ABC123'])->assertStatus(403);

        $super = $this->member('Super');
        RoleAssignment::create(['user_id' => $super->id, 'role' => 'super_admin', 'org_unit_id' => OrgUnit::where('name', 'Bharat')->value('id')]);
        Sanctum::actingAs($super);
        $this->putJson('/api/v1/admin/settings/website', ['ga_id' => 'UA-123'])->assertStatus(422);
        $this->putJson('/api/v1/admin/settings/website', [
            'ga_id' => 'G-ABC123XYZ',
            'google_verification' => '<meta name="google-site-verification" content="abcDEF123_-x" />',
        ])->assertOk()->assertJsonPath('data.google_verification', 'abcDEF123_-x');
        $this->getJson('/api/v1/site')->assertJsonPath('data.ga_id', 'G-ABC123XYZ')
            ->assertJsonPath('data.google_verification', 'abcDEF123_-x');
    }
}
