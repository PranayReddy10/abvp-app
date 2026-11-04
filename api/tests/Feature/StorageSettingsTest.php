<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\RoleAssignment;
use App\Models\Setting;
use App\Models\User;
use App\Services\MediaStorage;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Mockery;
use Tests\TestCase;

class StorageSettingsTest extends TestCase
{
    use RefreshDatabase;

    private int $seq = 0;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
        Storage::fake('local');
    }

    private function admin(string $role, string $unit): User
    {
        $this->seq++;
        $u = User::create(['mobile' => '+9197000'.str_pad((string) $this->seq, 5, '0', STR_PAD_LEFT)]);
        $p = new MemberProfile(['full_name' => 'Admin '.$this->seq, 'org_unit_id' => OrgUnit::where('name', $unit)->value('id')]);
        $p->user_id = $u->id;
        $p->member_id = 'A'.$this->seq;
        $p->membership_status = 'approved';
        $p->save();
        RoleAssignment::create(['user_id' => $u->id, 'role' => $role, 'org_unit_id' => OrgUnit::where('name', $unit)->value('id')]);

        return $u;
    }

    /** DigitalOcean is not reachable from tests: pretend the connection check gives this answer. */
    private function spacesAnswers(?string $error): void
    {
        $mock = Mockery::mock(MediaStorage::class)->makePartial();
        $mock->shouldReceive('test')->andReturn($error);
        $this->app->instance(MediaStorage::class, $mock);
    }

    private array $spaces = ['driver' => 'spaces', 'region' => 'blr1', 'bucket' => 'abvp-photos', 'key' => 'DO00ABCDEFGHIJKL1234', 'secret' => 'super-secret-value-123'];

    public function test_only_super_admins_manage_storage(): void
    {
        Sanctum::actingAs($this->admin('state_admin', 'Telangana'));
        $this->getJson('/api/v1/admin/settings/storage')->assertStatus(403);
        $this->putJson('/api/v1/admin/settings/storage', $this->spaces)->assertStatus(403);

        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $this->getJson('/api/v1/admin/settings/storage')->assertOk()
            ->assertJsonPath('data.driver', 'local')
            ->assertJsonPath('data.spaces.has_secret', false)
            ->assertJsonPath('data.s3_driver_installed', true);
    }

    public function test_a_space_that_fails_the_check_is_not_saved(): void
    {
        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $this->spacesAnswers('DigitalOcean refused the access key or secret.');

        $this->putJson('/api/v1/admin/settings/storage', $this->spaces)
            ->assertStatus(422)->assertJsonPath('error.code', 'STORAGE_TEST_FAILED');
        $this->assertSame(0, Setting::count());
        $this->assertSame('local', config('abvp.media_disk'));

        $this->putJson('/api/v1/admin/settings/storage', ['bucket' => 'Bad_Name'] + $this->spaces)->assertStatus(422);
    }

    public function test_switching_to_spaces_keeps_the_secret_encrypted_and_hidden(): void
    {
        $admin = $this->admin('super_admin', 'Bharat');
        Sanctum::actingAs($admin);
        $this->spacesAnswers(null);

        $res = $this->putJson('/api/v1/admin/settings/storage', $this->spaces)->assertOk()
            ->assertJsonPath('data.driver', 'spaces')
            ->assertJsonPath('data.spaces.bucket', 'abvp-photos')
            ->assertJsonPath('data.spaces.key_hint', 'DO00…1234')
            ->assertJsonPath('data.spaces.has_secret', true);
        $this->assertStringNotContainsString('super-secret-value-123', $res->getContent());
        $this->assertStringNotContainsString('DO00ABCDEFGHIJKL1234', $res->getContent());

        $raw = DB::table('settings')->where('key', 'storage.spaces_secret')->value('value');
        $this->assertNotSame('super-secret-value-123', $raw);
        $this->assertSame('super-secret-value-123', Setting::value('storage.spaces_secret'));
        $this->assertSame('spaces', config('abvp.media_disk'));
        $this->assertSame('https://blr1.digitaloceanspaces.com', config('filesystems.disks.spaces.endpoint'));
        $this->assertTrue(AuditLog::where('action', 'settings.storage')->exists());

        // Blank key and secret keep the saved ones when changing region or name.
        $this->putJson('/api/v1/admin/settings/storage', ['region' => 'sgp1', 'key' => '', 'secret' => ''] + $this->spaces)->assertOk();
        $this->assertSame('super-secret-value-123', Setting::value('storage.spaces_secret'));
        $this->assertSame('https://sgp1.digitaloceanspaces.com', config('filesystems.disks.spaces.endpoint'));

        // And back to the server disk.
        $this->putJson('/api/v1/admin/settings/storage', ['driver' => 'local'])->assertOk()->assertJsonPath('data.driver', 'local');
        $this->assertSame('local', config('abvp.media_disk'));
    }

    public function test_existing_photos_copy_in_batches_and_old_ones_still_load(): void
    {
        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $this->spacesAnswers(null);
        $this->putJson('/api/v1/admin/settings/storage', $this->spaces)->assertOk();
        Storage::fake('spaces');

        $local = Storage::disk('local');
        foreach (range(1, 30) as $i) {
            $local->put("posts/2026/11/p{$i}.jpg", "photo {$i}");
        }
        $local->put('photos/9/me.jpg', 'face');
        $local->put('private-notes.txt', 'not app media'); // outside the media folders: left alone

        $first = $this->postJson('/api/v1/admin/settings/storage/copy')->assertOk()->json('data');
        $this->assertSame(31, $first['total']);
        $this->assertSame(25, $first['copied']);
        $this->assertFalse($first['finished']);

        $second = $this->postJson('/api/v1/admin/settings/storage/copy', ['offset' => $first['done']])->assertOk()->json('data');
        $this->assertSame(6, $second['copied']);
        $this->assertTrue($second['finished']);
        Storage::disk('spaces')->assertExists('photos/9/me.jpg');
        Storage::disk('spaces')->assertMissing('private-notes.txt');

        // Running it again skips what is already there.
        $again = $this->postJson('/api/v1/admin/settings/storage/copy')->json('data');
        $this->assertSame(0, $again['copied']);
        $this->assertSame(25, $again['skipped']);

        // A photo saved only on the server before the switch is still served.
        $profile = MemberProfile::first();
        $local->put('photos/old/me.jpg', 'old face');
        $profile->forceFill(['photo_path' => 'photos/old/me.jpg'])->save();
        $url = \Illuminate\Support\Facades\URL::temporarySignedRoute('media.photo', now()->addMinute(), ['profile' => $profile->id]);
        $this->get($url)->assertOk();
    }

    public function test_copy_needs_spaces_switched_on(): void
    {
        Sanctum::actingAs($this->admin('super_admin', 'Bharat'));
        $this->postJson('/api/v1/admin/settings/storage/copy')->assertStatus(409)->assertJsonPath('error.code', 'NOT_ON_SPACES');
    }
}
