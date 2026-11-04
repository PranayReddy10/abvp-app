<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Updates posted inside a Vibhag space, optionally for one area only.
        Schema::create('vibhag_posts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vibhag_id')->constrained()->cascadeOnDelete();
            $table->foreignId('org_unit_id')->constrained('org_units');
            $table->foreignId('author_id')->constrained('users');
            $table->text('body');
            $table->timestamps();
            $table->index(['vibhag_id', 'created_at']);
        });

        // Baithaks and one-to-one calls. Video lives with Meet/Zoom; we keep the link.
        Schema::create('meetings', function (Blueprint $table) {
            $table->id();
            $table->string('kind', 12)->default('meeting'); // meeting | call
            $table->string('title');
            $table->text('agenda')->nullable();
            $table->string('mode', 12); // online | in_person | hybrid
            $table->string('link', 500)->nullable();
            $table->string('provider', 20)->nullable(); // google_meet | zoom | teams | jitsi | youtube | link
            $table->string('venue')->nullable();
            $table->dateTime('starts_at');
            $table->dateTime('ends_at');
            $table->foreignId('organiser_id')->constrained('users');
            $table->foreignId('org_unit_id')->nullable()->constrained('org_units');
            $table->foreignId('vibhag_id')->nullable()->constrained('vibhags');
            $table->string('status', 12)->default('scheduled'); // scheduled | cancelled
            $table->text('minutes')->nullable();
            $table->timestamp('reminded_day_at')->nullable();
            $table->timestamp('reminded_soon_at')->nullable();
            $table->timestamps();
            $table->index(['starts_at', 'status']);
        });

        Schema::create('meeting_invitees', function (Blueprint $table) {
            $table->id();
            $table->foreignId('meeting_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('rsvp', 8)->default('pending'); // pending | going | maybe | no
            $table->string('rsvp_note', 300)->nullable();
            $table->timestamp('joined_at')->nullable();
            $table->timestamps();
            $table->unique(['meeting_id', 'user_id']);
            $table->index(['user_id', 'rsvp']);
        });

        Schema::create('action_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('meeting_id')->constrained()->cascadeOnDelete();
            $table->foreignId('assignee_id')->constrained('users');
            $table->string('title');
            $table->date('due_on')->nullable();
            $table->timestamp('done_at')->nullable();
            $table->timestamps();
            $table->index(['assignee_id', 'done_at']);
        });

        // Official circulars. Audience: approved members whose unit is inside org_unit,
        // and in the Vibhag when one is set.
        Schema::create('circulars', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->text('body');
            $table->string('attachment_path')->nullable();
            $table->foreignId('org_unit_id')->constrained('org_units');
            $table->foreignId('vibhag_id')->nullable()->constrained('vibhags');
            $table->foreignId('issued_by')->constrained('users');
            $table->unsignedInteger('audience_size')->default(0);
            $table->timestamp('published_at')->index();
            $table->timestamps();
        });

        Schema::create('circular_reads', function (Blueprint $table) {
            $table->foreignId('circular_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->timestamp('read_at');
            $table->primary(['circular_id', 'user_id']);
        });

        // What happened on the ground. Feeds every dashboard above the unit.
        Schema::create('activity_reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('org_unit_id')->constrained('org_units');
            $table->foreignId('vibhag_id')->nullable()->constrained('vibhags');
            $table->foreignId('submitted_by')->constrained('users');
            $table->string('title');
            $table->string('programme_type', 40);
            $table->date('held_on')->index();
            $table->string('place')->nullable();
            $table->unsignedInteger('participants')->default(0);
            $table->unsignedSmallInteger('institutions')->default(0);
            $table->text('description')->nullable();
            $table->json('photos')->nullable();
            $table->timestamps();
            $table->index(['org_unit_id', 'held_on']);
        });

        // In-app notifications (push via FCM can read the same rows later).
        Schema::create('app_notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('type', 32);
            $table->string('title');
            $table->string('body', 500)->nullable();
            $table->json('data')->nullable();
            $table->timestamp('read_at')->nullable();
            $table->timestamp('created_at')->nullable();
            $table->index(['user_id', 'read_at', 'created_at']);
        });
    }

    public function down(): void
    {
        foreach (['app_notifications', 'activity_reports', 'circular_reads', 'circulars', 'action_items', 'meeting_invitees', 'meetings', 'vibhag_posts'] as $t) {
            Schema::dropIfExists($t);
        }
    }
};
