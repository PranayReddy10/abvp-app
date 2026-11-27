<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Videos for guide items (the Gallery): uploaded clips or YouTube / other links. */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('guide_items', 'videos')) {
            Schema::table('guide_items', fn (Blueprint $t) => $t->json('videos')->nullable()->after('photos'));
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('guide_items', 'videos')) {
            Schema::table('guide_items', fn (Blueprint $t) => $t->dropColumn('videos'));
        }
    }
};
