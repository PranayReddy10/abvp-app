<?php

namespace App\Services;

use App\Models\MemberProfile;
use App\Models\OrgUnit;
use Illuminate\Support\Facades\DB;

/**
 * Member IDs look like ABVP-TS-HYD-024871: state code, district code and a
 * running number per district. IDs already in use are skipped.
 */
class MemberIdGenerator
{
    public function next(OrgUnit $unit): string
    {
        $state = $unit->ancestorOfType('state');
        $district = $unit->ancestorOfType('district');
        $counterUnit = $district ?? $state ?? $unit;
        $prefix = array_filter(['ABVP', $state?->code ?? 'IN', $district?->code]);

        // Several counters can share a prefix (areas without a code all use ABVP-IN), and IDs
        // can come from imports: keep counting until the ID is free.
        return DB::transaction(function () use ($counterUnit, $prefix) {
            $row = OrgUnit::whereKey($counterUnit->id)->lockForUpdate()->first();
            do {
                $row->member_seq++;
                $id = strtoupper(implode('-', [...$prefix, str_pad((string) $row->member_seq, 6, '0', STR_PAD_LEFT)]));
            } while (MemberProfile::where('member_id', $id)->exists());
            $row->saveQuietly();

            return $id;
        });
    }
}
