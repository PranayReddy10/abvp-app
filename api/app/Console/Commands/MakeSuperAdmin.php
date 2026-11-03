<?php

namespace App\Console\Commands;

use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\RoleAssignment;
use App\Models\User;
use App\Services\MemberIdGenerator;
use App\Support\Mobile;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/** Bootstraps the first administrator. Run once over SSH after deploying. */
class MakeSuperAdmin extends Command
{
    protected $signature = 'abvp:make-admin
        {mobile : 10-digit mobile number}
        {name : Full name}
        {--role=super_admin : Role to give}
        {--unit= : Org unit id for the scope (defaults to the national unit)}';

    protected $description = 'Create or promote an administrator who signs in with OTP';

    public function handle(MemberIdGenerator $ids): int
    {
        $mobile = Mobile::normalize($this->argument('mobile'));
        if (! $mobile) {
            $this->error('Invalid mobile number.');

            return self::FAILURE;
        }

        $role = $this->option('role');
        if (! array_key_exists($role, config('abvp.roles'))) {
            $this->error('Unknown role. Use one of: '.implode(', ', array_keys(config('abvp.roles'))));

            return self::FAILURE;
        }

        $unit = $this->option('unit')
            ? OrgUnit::find($this->option('unit'))
            : OrgUnit::where('type', 'national')->first();

        if (! $unit) {
            $this->error('Org unit not found. Run `php artisan db:seed` first.');

            return self::FAILURE;
        }

        DB::transaction(function () use ($mobile, $unit, $role, $ids) {
            $user = User::firstOrCreate(['mobile' => $mobile], ['name' => $this->argument('name')]);

            $profile = $user->profile ?? new MemberProfile;
            $profile->user_id = $user->id;
            $profile->full_name = $profile->full_name ?: $this->argument('name');
            $profile->org_unit_id ??= $unit->id;
            $profile->membership_status = MemberProfile::STATUS_APPROVED;
            $profile->approved_at ??= now();
            $profile->member_id ??= $ids->next($unit);
            $profile->save();

            RoleAssignment::firstOrCreate(
                ['user_id' => $user->id, 'role' => $role, 'org_unit_id' => $unit->id],
                ['starts_on' => now()->toDateString()],
            );

            $this->info("{$this->argument('name')} ({$mobile}) is now {$role} for {$unit->name}. Member ID {$profile->member_id}.");
        });

        return self::SUCCESS;
    }
}
