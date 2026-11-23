<?php

namespace App\Services;

use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Every account gets a member ID the moment it is created, member or not. The ID follows
 * the person's district if known, else the prant they chose, else the national series
 * (ABVP-IN-000123). It never changes afterwards, also not on approval.
 */
class AccountIds
{
    public function __construct(private MemberIdGenerator $ids) {}

    public function ensure(User $user): ?MemberProfile
    {
        if (! OrgUnit::query()->exists()) {
            return $user->profile; // nothing seeded yet (fresh install): numbering starts once areas exist
        }

        return DB::transaction(function () use ($user) {
            $profile = MemberProfile::where('user_id', $user->id)->lockForUpdate()->first() ?? new MemberProfile;
            if ($profile->exists && $profile->member_id) {
                return $profile;
            }
            $profile->user_id = $user->id;
            $profile->full_name = $profile->full_name ?: (string) ($user->name ?? '');
            $profile->member_id = $this->ids->next($this->unitFor($user, $profile));
            $profile->save();
            $user->setRelation('profile', $profile);

            return $profile;
        });
    }

    private function unitFor(User $user, MemberProfile $profile): OrgUnit
    {
        return $profile->orgUnit
            ?? ($user->prant ? OrgUnit::where('type', 'state')->where('name', $user->prant)->first() : null)
            ?? OrgUnit::where('type', 'national')->first()
            ?? OrgUnit::whereNull('parent_id')->first()
            ?? OrgUnit::query()->firstOrFail();
    }
}
