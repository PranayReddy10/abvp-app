<?php

namespace App\Services;

use App\Models\OrgUnit;
use Illuminate\Support\Facades\DB;

/**
 * Member IDs look like ABVP-TS-HYD-024871: state code, district code and a
 * running number per district. Must be called inside a transaction.
 */
class MemberIdGenerator
{
    public function next(OrgUnit $unit): string
    {
        $state = $unit->ancestorOfType('state');
        $district = $unit->ancestorOfType('district');
        $counterUnit = $district ?? $state ?? $unit;

        $seq = DB::transaction(function () use ($counterUnit) {
            $row = OrgUnit::whereKey($counterUnit->id)->lockForUpdate()->first();
            $row->member_seq++;
            $row->saveQuietly();

            return $row->member_seq;
        });

        $parts = array_filter([
            'ABVP',
            $state?->code ?? 'IN',
            $district?->code,
            str_pad((string) $seq, 6, '0', STR_PAD_LEFT),
        ]);

        return strtoupper(implode('-', $parts));
    }
}
