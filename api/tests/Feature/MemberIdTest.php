<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MemberIdTest extends TestCase
{
    use RefreshDatabase;

    public function test_ids_already_taken_are_skipped_even_across_counters(): void
    {
        $this->seed(DatabaseSeeder::class);
        // An admin imported with ABVP-IN-000001 while the counter still says 0.
        $admin = User::create(['mobile' => '+919000000000', 'name' => 'Admin']);
        $p = new MemberProfile(['full_name' => 'Admin']);
        $p->user_id = $admin->id;
        $p->member_id = 'ABVP-IN-000001';
        $p->save();
        // A prant without a code shares the ABVP-IN prefix with the national series.
        $national = OrgUnit::where('type', 'national')->first();
        OrgUnit::create(['parent_id' => $national->id, 'type' => 'state', 'name' => 'Vidarbha']);

        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876543211'])->assertOk();
        $a = $this->postJson('/api/v1/auth/register', ['mobile' => '9876543211', 'code' => '123456', 'name' => 'testing'])
            ->assertOk()->json('data.user.profile.member_id');
        $this->postJson('/api/v1/auth/send-otp', ['mobile' => '9876543212'])->assertOk();
        $b = $this->postJson('/api/v1/auth/register', ['mobile' => '9876543212', 'code' => '123456', 'name' => 'Vid', 'prant' => 'Vidarbha'])
            ->assertOk()->json('data.user.profile.member_id');

        $this->assertSame('ABVP-IN-000002', $a);
        $this->assertSame('ABVP-IN-000003', $b);
    }
}
