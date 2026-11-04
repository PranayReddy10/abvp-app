<?php

namespace Tests\Feature;

use App\Models\AppNotification;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\Post;
use App\Models\RoleAssignment;
use App\Models\User;
use App\Models\Vibhag;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FeedTest extends TestCase
{
    use RefreshDatabase;

    private int $seq = 0;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
        Storage::fake('local');
    }

    private function member(string $name, string $unit = 'Osmania University', array $vibhags = ['SFD'], bool $approved = true): User
    {
        $this->seq++;
        $user = User::create(['mobile' => '+9198000'.str_pad((string) $this->seq, 5, '0', STR_PAD_LEFT)]);
        $p = new MemberProfile(['full_name' => $name, 'org_unit_id' => OrgUnit::where('name', $unit)->value('id')]);
        $p->user_id = $user->id;
        $p->member_id = 'M'.$this->seq;
        $p->membership_status = $approved ? 'approved' : 'submitted';
        $p->save();
        $user->vibhags()->sync(Vibhag::whereIn('code', $vibhags)->pluck('id'));

        return $user;
    }

    private function createPost(User $u, array $data, array $files = []): \Illuminate\Testing\TestResponse
    {
        Sanctum::actingAs($u);

        return $this->post('/api/v1/posts', $data + ['audience' => 'members'] + $files, ['Accept' => 'application/json']);
    }

    public function test_members_post_with_photos_and_hashtags_and_others_see_it(): void
    {
        $a = $this->member('Anusha');
        $b = $this->member('Ravi', 'Kakatiya University');

        $this->createPost($a, ['body' => 'Lake clean-up done! 86 students joined. #SwachhParisar #SFD'], ['photos' => [UploadedFile::fake()->image('a.jpg', 800, 600), UploadedFile::fake()->image('b.jpg', 800, 600)]])
            ->assertCreated()->assertJsonCount(2, 'data.photo_urls')->assertJsonPath('data.author.name', 'Anusha');

        Sanctum::actingAs($b);
        $this->getJson('/api/v1/feed')->assertJsonCount(1, 'data')->assertJsonPath('data.0.body', 'Lake clean-up done! 86 students joined. #SwachhParisar #SFD');
        $this->getJson('/api/v1/feed?tag=swachhparisar')->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/feed?tag=other')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/feed/trending')->assertJsonPath('data.0.posts', 1);
    }

    public function test_audience_limits_who_sees_a_post(): void
    {
        $hyd = $this->member('Anusha');
        $hydThink = $this->member('Harsha', 'Secunderabad', ['THINK-INDIA']);
        $wgl = $this->member('Ravi', 'Kakatiya University');

        $this->createPost($hyd, ['body' => 'Hyderabad baithak at 6', 'audience' => 'area'])->assertCreated()->assertJsonPath('data.audience_label', 'Only my district');
        $this->createPost($hyd, ['body' => 'SFD only', 'audience' => 'vibhag', 'vibhag_id' => Vibhag::where('code', 'SFD')->value('id')])->assertCreated();
        $this->createPost($hyd, ['body' => 'Think India', 'audience' => 'vibhag', 'vibhag_id' => Vibhag::where('code', 'THINK-INDIA')->value('id')])->assertStatus(403);

        Sanctum::actingAs($hydThink);
        $this->assertSame(['Hyderabad baithak at 6'], collect($this->getJson('/api/v1/feed')->json('data'))->pluck('body')->all());
        Sanctum::actingAs($wgl);
        $this->assertSame(['SFD only'], collect($this->getJson('/api/v1/feed')->json('data'))->pluck('body')->all());
    }

    public function test_only_approved_members_use_the_feed(): void
    {
        $applicant = $this->member('Applicant', approved: false);
        Sanctum::actingAs($applicant);
        $this->getJson('/api/v1/feed')->assertStatus(403)->assertJsonPath('error.code', 'NOT_A_MEMBER');
        $this->createPost($applicant, ['body' => 'hi'])->assertStatus(403);
    }

    public function test_like_comment_repost_and_follow(): void
    {
        $a = $this->member('Anusha');
        $b = $this->member('Ravi');
        $id = $this->createPost($a, ['body' => 'Tree plantation on Saturday'])->json('data.id');

        Sanctum::actingAs($b);
        $this->postJson("/api/v1/posts/$id/like")->assertJsonPath('data.liked', true)->assertJsonPath('data.likes_count', 1);
        $this->postJson("/api/v1/posts/$id/like")->assertJsonPath('data.liked', false)->assertJsonPath('data.likes_count', 0);
        $this->postJson("/api/v1/posts/$id/like");
        $this->postJson("/api/v1/posts/$id/comments", ['body' => 'Count me in'])->assertCreated();
        $this->post('/api/v1/posts', ['repost_of_id' => $id, 'audience' => 'members'], ['Accept' => 'application/json'])->assertCreated()->assertJsonPath('data.repost_of.id', $id);
        $this->post('/api/v1/posts', ['repost_of_id' => $id, 'audience' => 'members'], ['Accept' => 'application/json'])->assertStatus(409);
        $this->postJson('/api/v1/members/M1/follow')->assertJsonPath('data.following', true)->assertJsonPath('data.followers', 1);

        $this->getJson("/api/v1/posts/$id")->assertJsonPath('data.likes', 1)->assertJsonPath('data.comments', 1)->assertJsonPath('data.reposts', 1)
            ->assertJsonPath('data.liked', true)->assertJsonPath('data.reposted', true)->assertJsonPath('data.replies.0.body', 'Count me in');
        $this->getJson('/api/v1/members/M1')->assertJsonPath('data.social.followers', 1)->assertJsonPath('data.social.is_following', true);
        $this->getJson('/api/v1/feed?tab=following')->assertJsonCount(1, 'data');

        $types = AppNotification::where('user_id', $a->id)->pluck('type')->sort()->values()->all();
        $this->assertSame(['new_follower', 'post_comment', 'post_repost'], $types);

        Sanctum::actingAs($a);
        $this->deleteJson("/api/v1/posts/$id")->assertOk();
    }

    public function test_reports_auto_hide_and_admins_in_scope_moderate(): void
    {
        $author = $this->member('Troll');
        $id = $this->createPost($author, ['body' => 'Something abusive'])->json('data.id');

        foreach (range(1, 5) as $i) {
            Sanctum::actingAs($this->member("Reporter $i"));
            $this->postJson("/api/v1/posts/$id/report", ['reason' => 'abuse'])->assertOk();
            if ($i === 1) {
                // Reporting twice counts once.
                $this->postJson("/api/v1/posts/$id/report", ['reason' => 'abuse'])->assertJsonPath('data.already', true);
            }
        }
        $this->assertSame(5, Post::find($id)->reports_count);
        $this->assertNotNull(Post::find($id)->hidden_at);
        $this->getJson('/api/v1/feed')->assertJsonCount(0, 'data');

        Sanctum::actingAs($author);
        $this->getJson('/api/v1/feed')->assertJsonPath('data.0.hidden', true); // the author still sees their own

        $wgl = $this->member('Warangal admin', 'Kakatiya University');
        RoleAssignment::create(['user_id' => $wgl->id, 'role' => 'district_admin', 'org_unit_id' => OrgUnit::where('name', 'Warangal')->value('id')]);
        Sanctum::actingAs($wgl);
        $this->getJson('/api/v1/admin/moderation?status=hidden')->assertJsonCount(0, 'data');
        $this->postJson("/api/v1/admin/moderation/posts/$id", ['action' => 'restore'])->assertStatus(403);

        $hyd = $this->member('Hyderabad admin');
        RoleAssignment::create(['user_id' => $hyd->id, 'role' => 'district_admin', 'org_unit_id' => OrgUnit::where('name', 'Hyderabad')->value('id')]);
        Sanctum::actingAs($hyd);
        $this->getJson('/api/v1/admin/moderation')->assertJsonPath('data.0.reports_count', 5)->assertJsonPath('data.0.reasons.0.count', 5);
        $this->postJson("/api/v1/admin/moderation/posts/$id", ['action' => 'hide', 'reason' => 'Abusive language'])->assertJsonPath('data.hidden', true);
        $this->assertDatabaseHas('audit_logs', ['action' => 'post.hide']);
        $this->assertSame(1, AppNotification::where('user_id', $author->id)->where('type', 'post_hidden')->count());
    }

    public function test_posting_is_rate_limited(): void
    {
        $a = $this->member('Anusha');
        foreach (range(1, 10) as $i) {
            $this->createPost($a, ['body' => "Post $i"])->assertCreated();
        }
        $this->createPost($a, ['body' => 'one too many'])->assertStatus(429);
    }

    public function test_event_cover_upload(): void
    {
        $admin = $this->member('Admin');
        RoleAssignment::create(['user_id' => $admin->id, 'role' => 'state_admin', 'org_unit_id' => OrgUnit::where('name', 'Telangana')->value('id')]);
        Sanctum::actingAs($admin);
        $id = $this->postJson('/api/v1/admin/events', ['title' => 'Yuva Sammelan', 'category' => 'programme', 'venue' => 'Hyderabad',
            'starts_at' => now()->addDays(3)->toIso8601String(), 'ends_at' => now()->addDays(3)->addHours(4)->toIso8601String(),
            'org_unit_id' => OrgUnit::where('name', 'Hyderabad')->value('id')])->json('data.id');
        $this->post("/api/v1/admin/events/$id/cover", ['cover' => UploadedFile::fake()->image('c.jpg', 1200, 700)], ['Accept' => 'application/json'])->assertOk();
        $this->getJson("/api/v1/admin/events/$id")->assertJsonPath('data.cover_url', fn ($u) => str_contains($u, '/media/events/'));
    }
}
