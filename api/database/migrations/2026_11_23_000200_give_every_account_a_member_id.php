<?php

use App\Models\User;
use App\Services\AccountIds;
use Illuminate\Database\Migrations\Migration;

/** Accounts made before every account got a member ID get one now. */
return new class extends Migration
{
    public function up(): void
    {
        if (! \App\Models\OrgUnit::query()->exists()) {
            return; // fresh install: nothing seeded yet, nobody to number
        }
        $ids = app(AccountIds::class);
        User::query()->whereDoesntHave('profile', fn ($p) => $p->whereNotNull('member_id'))
            ->orderBy('id')->each(fn (User $u) => $ids->ensure($u));
    }

    public function down(): void
    {
        // IDs once given are kept.
    }
};
