<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The conference volunteer structure: ghats (event_teams with no parent), their departments
 * (event_teams with a ghat as parent), the people in each with their role, and a chat per team.
 *
 * Written to be safe on MySQL and re-runnable: an earlier version stopped half-way on MySQL
 * (the old unique index also served the event_id foreign key, error 1553) after adding the
 * columns, so every step checks what is already there.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('event_teams', function (Blueprint $table) {
            if (! Schema::hasColumn('event_teams', 'parent_id')) {
                $table->foreignId('parent_id')->nullable()->after('event_id')->constrained('event_teams')->cascadeOnDelete();
            }
            if (! Schema::hasColumn('event_teams', 'kind')) {
                $table->string('kind', 12)->default('team')->after('parent_id'); // ghat | department | team
            }
            if (! Schema::hasColumn('event_teams', 'name_local')) {
                $table->string('name_local')->nullable()->after('name');
            }
            if (! Schema::hasColumn('event_teams', 'sort')) {
                $table->unsignedSmallInteger('sort')->default(0);
            }
            if (! Schema::hasColumn('event_teams', 'color')) {
                $table->string('color', 9)->nullable();
            }
        });

        // Give the event_id foreign key its own index before the old unique index goes.
        if (! Schema::hasIndex('event_teams', 'event_teams_event_id_index')) {
            Schema::table('event_teams', fn (Blueprint $t) => $t->index('event_id'));
        }
        if (Schema::hasIndex('event_teams', 'event_teams_event_id_name_unique')) {
            Schema::table('event_teams', fn (Blueprint $t) => $t->dropUnique(['event_id', 'name']));
        }
        // Department names repeat across ghats (Sanchalan samiti, Central Team).
        if (! Schema::hasIndex('event_teams', 'event_teams_event_id_parent_id_name_unique')) {
            Schema::table('event_teams', fn (Blueprint $t) => $t->unique(['event_id', 'parent_id', 'name']));
        }

        if (! Schema::hasTable('event_team_members')) {
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
        }

        if (! Schema::hasTable('event_team_messages')) {
            Schema::create('event_team_messages', function (Blueprint $table) {
                $table->id();
                $table->foreignId('team_id')->constrained('event_teams')->cascadeOnDelete();
                $table->foreignId('user_id')->constrained();
                $table->text('body');
                $table->boolean('is_announcement')->default(false);
                $table->timestamps();
                $table->index(['team_id', 'id']);
            });
        }

        if (! Schema::hasColumn('meetings', 'event_team_id')) {
            Schema::table('meetings', function (Blueprint $table) {
                $table->foreignId('event_team_id')->nullable()->after('vibhag_id')->constrained('event_teams')->nullOnDelete();
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('meetings', 'event_team_id')) {
            Schema::table('meetings', fn (Blueprint $t) => $t->dropConstrainedForeignId('event_team_id'));
        }
        Schema::dropIfExists('event_team_messages');
        Schema::dropIfExists('event_team_members');
        if (Schema::hasIndex('event_teams', 'event_teams_event_id_parent_id_name_unique')) {
            Schema::table('event_teams', fn (Blueprint $t) => $t->dropUnique(['event_id', 'parent_id', 'name']));
        }
        if (! Schema::hasIndex('event_teams', 'event_teams_event_id_name_unique')) {
            Schema::table('event_teams', fn (Blueprint $t) => $t->unique(['event_id', 'name']));
        }
        if (Schema::hasColumn('event_teams', 'parent_id')) {
            Schema::table('event_teams', fn (Blueprint $t) => $t->dropConstrainedForeignId('parent_id'));
        }
        Schema::table('event_teams', function (Blueprint $table) {
            foreach (['kind', 'name_local', 'sort', 'color'] as $c) {
                if (Schema::hasColumn('event_teams', $c)) {
                    $table->dropColumn($c);
                }
            }
        });
    }
};
