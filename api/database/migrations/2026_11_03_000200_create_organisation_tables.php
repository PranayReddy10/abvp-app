<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Geographic hierarchy: national > state > district > unit (ikai / college).
        // "path" holds the ancestor chain like "/1/4/9/" so scope checks are a prefix match.
        Schema::create('org_units', function (Blueprint $table) {
            $table->id();
            $table->foreignId('parent_id')->nullable()->constrained('org_units');
            $table->string('type', 16);
            $table->string('name');
            $table->string('name_local')->nullable();
            $table->string('code', 12)->nullable();
            $table->string('path')->default('/')->index();
            $table->unsignedTinyInteger('depth')->default(0);
            $table->unsignedInteger('member_seq')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->unique(['parent_id', 'name']);
            $table->index(['type', 'is_active']);
        });

        // Vibhags are departments, independent of geography. About 70, edited as data.
        Schema::create('vibhags', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('code', 24)->unique();
            $table->text('description')->nullable();
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('vibhags');
        Schema::dropIfExists('org_units');
    }
};
