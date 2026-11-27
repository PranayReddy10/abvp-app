<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Posts waiting for an admin's approval (when Community → "Posts need approval" is on). */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('posts', 'pending_at')) {
            Schema::table('posts', fn (Blueprint $t) => $t->timestamp('pending_at')->nullable()->after('hidden_reason'));
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('posts', 'pending_at')) {
            Schema::table('posts', fn (Blueprint $t) => $t->dropColumn('pending_at'));
        }
    }
};
