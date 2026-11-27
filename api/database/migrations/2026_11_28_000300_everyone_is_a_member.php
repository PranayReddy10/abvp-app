<?php

use App\Models\MemberProfile;
use App\Models\User;
use App\Services\AccountIds;
use Illuminate\Database\Migrations\Migration;

/**
 * Everyone who signed up is a member: profiles still in draft / applied become members, and
 * accounts without a profile get one with a member ID. Verification (the blue tick) stays
 * with admins. Skipped when Settings → "Membership needs approval" is on.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (rescue(fn () => \App\Services\SignInSettings::membershipNeedsApproval(), false, false)) {
            return;
        }
        MemberProfile::whereIn('membership_status', ['draft', 'submitted', 'more_info_required'])
            ->update(['membership_status' => 'approved', 'approved_at' => now()]);
        User::where('status', 'active')->whereDoesntHave('profile')->each(
            fn (User $u) => rescue(fn () => app(AccountIds::class)->ensure($u), null, false)
        );
    }

    public function down(): void
    {
        // Membership decisions are not undone.
    }
};
