<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The conference volunteer structure: ghats (event_teams with no parent), their departments
 * (event_teams with a ghat as parent), the people in each with their role, and a chat per team.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('event_teams', function (Blueprint $table) {
            $table->foreignId('parent_id')->nullable()->after('event_id')->constrained('event_teams')->cascadeOnDelete();
            $table->string('kind', 12)->default('team')->after('parent_id'); // ghat | department | team
            $table->string('name_local')->nullable()->after('name');
            $table->unsignedSmallInteger('sort')->default(0);
            $table->string('color', 9)->nullable();
        });
        Schema::table('event_teams', function (Blueprint $table) {
            $table->dropUnique(['event_id', 'name']);
            $table->unique(['event_id', 'parent_id', 'name']);
        });

        Schema::create('event_team_members', function (Blueprint $table) {
            $table->id();
            $table->foreignId('team_id')->constrained('event_teams')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('name');
            $table->string('mobile', 16)->nullable()->index();
            // ghat_pramukh | ghat_saha_pramukh | ghat_palak | pramukh | saha_pramukh | volunteer
            $table->string('role', 20);
            $table->string('note')->nullable();
            $table->unsignedSmallInteger('sort')->default(0);
            $table->timestamps();
            $table->index(['team_id', 'role']);
        });

        Schema::create('event_team_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('team_id')->constrained('event_teams')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained();
            $table->text('body');
            $table->boolean('is_announcement')->default(false);
            $table->timestamps();
            $table->index(['team_id', 'id']);
        });

        Schema::table('meetings', function (Blueprint $table) {
            $table->foreignId('event_team_id')->nullable()->after('vibhag_id')->constrained('event_teams')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('meetings', fn (Blueprint $t) => $t->dropConstrainedForeignId('event_team_id'));
        Schema::dropIfExists('event_team_messages');
        Schema::dropIfExists('event_team_members');
        Schema::table('event_teams', function (Blueprint $table) {
            $table->dropUnique(['event_id', 'parent_id', 'name']);
            $table->unique(['event_id', 'name']);
            $table->dropConstrainedForeignId('parent_id');
            $table->dropColumn(['kind', 'name_local', 'sort', 'color']);
        });
    }
};
