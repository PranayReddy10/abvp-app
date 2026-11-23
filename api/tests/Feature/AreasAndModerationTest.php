<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\Post;
use App\Models\RoleAssignment;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AreasAndModerationTest extends TestCase
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
        $p = new MemberProfile(['full_name' => 'Admin '.$role, 'org_unit_id' => OrgUnit::where('name', $unit)->value('id')]);
        $p->user_id = $u->id;
        $p->member_id = 'A'.$u->id;
        $p->membership_status = 'approved';
        $p->save();
        RoleAssignment::create(['user_id' => $u->id, 'role' => $role, 'org_unit_id' => OrgUnit::where('name', $unit)->value('id')]);

        return $u;
    }

    public function test_all_posts_tab_shows_everyones_posts_including_the_admins_own(): void
    {
        $admin = $this->admin('super_admin', 'Bharat');
        Sanctum::actingAs($admin);
        $this->postJson('/api/v1/posts', ['body' => 'From the admin', 'audience' => 'members'])->assertCreated();
        $guest = User::create(['mobile' => '+919811155566', 'name' => 'Delegate Ravi']);
        Post::create(['user_id' => $guest->id, 'body' => 'Delegate post', 'audience' => 'members']);

        $this->getJson('/api/v1/admin/moderation')->assertOk()->assertJsonCount(0, 'data'); // nothing reported
        $all = collect($this->getJson('/api/v1/admin/moderation?status=all')->assertOk()->json('data'));
        $this->assertSame(['Delegate post', 'From the admin'], $all->pluck('body')->all());
        $this->assertSame('Delegate Ravi', $all->first()['author']['name']);

        $this->postJson('/api/v1/admin/moderation/posts/'.$all->first()['id'], ['action' => 'hide', 'reason' => 'Off topic'])->assertOk();
        $this->getJson('/api/v1/admin/moderation?status=hidden')->assertJsonCount(1, 'data');
    }

    public function test_admins_add_states_and_districts_in_their_area(): void
    {
        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $root = $this->getJson('/api/v1/admin/org-units')->assertOk()->json('data.0');
        $this->assertSame('national', $root['type']);
        $state = $this->postJson('/api/v1/admin/org-units', ['parent_id' => $root['id'], 'name' => 'Vidarbha'])->assertCreated()->json('data');
        $this->assertSame('state', $state['type']);
        $this->postJson('/api/v1/admin/org-units', ['parent_id' => $state['id'], 'name' => 'Nagpur'])->assertCreated()->assertJsonPath('data.type', 'district');
        $this->getJson('/api/v1/admin/org-units?parent_id='.$state['id'])->assertOk()->assertJsonPath('data.0.name', 'Nagpur');
        $this->getJson('/api/v1/org/units')->assertOk()->assertJsonFragment(['name' => 'Vidarbha']);

        // A state admin manages only their own state.
        Sanctum::actingAs($this->admin('state_admin', 'Telangana'));
        $this->getJson('/api/v1/admin/org-units')->assertOk()->assertJsonPath('data.0.name', 'Telangana');
        $this->postJson('/api/v1/admin/org-units', ['parent_id' => $state['id'], 'name' => 'Wardha'])->assertStatus(403);
        $this->patchJson('/api/v1/admin/org-units/'.$state['id'], ['is_active' => false])->assertStatus(403);
    }

    public function test_add_all_prants_once_and_new_states_reach_the_signup_list(): void
    {
        Sanctum::actingAs($this->admin('state_admin', 'Telangana'));
        $this->postJson('/api/v1/admin/org-units/import-prants')->assertStatus(403);

        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $added = $this->postJson('/api/v1/admin/org-units/import-prants')->assertOk()->json('data.added');
        $this->assertContains('Vidarbha', $added);
        $this->assertNotContains('Telangana', $added);
        $this->postJson('/api/v1/admin/org-units/import-prants')->assertOk()->assertJsonPath('data.added', []);
        $this->assertSame(count(config('abvp.prants')), OrgUnit::where('type', 'state')->count());

        $root = OrgUnit::where('type', 'national')->first();
        $this->postJson('/api/v1/admin/org-units', ['parent_id' => $root->id, 'name' => 'Andaman Island Unit'])->assertCreated();
        $this->getJson('/api/v1/guide/prants')->assertOk()->assertJsonFragment(['Andaman Island Unit']);
    }
}
