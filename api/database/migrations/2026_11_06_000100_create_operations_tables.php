<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('event_teams', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->string('name'); // Registration desk, Hospitality, Stage and sound
            $table->text('description')->nullable();
            $table->foreignId('lead_user_id')->nullable()->constrained('users');
            $table->timestamps();
            $table->unique(['event_id', 'name']);
        });

        // A person can have zero, one or many duties at an event.
        Schema::create('event_duties', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->foreignId('team_id')->nullable()->constrained('event_teams')->nullOnDelete();
            $table->foreignId('assignee_id')->constrained('users');
            $table->foreignId('reporting_user_id')->nullable()->constrained('users');
            $table->string('title');
            $table->text('instructions')->nullable();
            $table->string('location')->nullable(); // Gate 3, Main stage
            $table->dateTime('starts_at');
            $table->dateTime('ends_at');
            // assigned | accepted | declined | in_progress | done | blocked | cancelled
            $table->string('status', 12)->default('assigned')->index();
            $table->string('status_note', 500)->nullable();
            $table->timestamp('responded_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->foreignId('assigned_by')->nullable()->constrained('users');
            $table->timestamps();
            $table->index(['assignee_id', 'starts_at']);
            $table->index(['event_id', 'team_id']);
        });

        // Requests for help during an event: stay, food, transport, medical, venue...
        Schema::create('help_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->foreignId('raised_by')->constrained('users');
            $table->string('category', 16);
            $table->text('message');
            $table->string('location')->nullable();
            $table->string('status', 12)->default('open')->index(); // open | in_progress | resolved
            $table->foreignId('team_id')->nullable()->constrained('event_teams')->nullOnDelete();
            $table->foreignId('handled_by')->nullable()->constrained('users');
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();
            $table->index(['event_id', 'status']);
        });

        Schema::create('help_replies', function (Blueprint $table) {
            $table->id();
            $table->foreignId('help_request_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained();
            $table->text('body');
            $table->timestamp('created_at')->nullable();
        });

        Schema::create('event_announcements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sent_by')->constrained('users');
            $table->string('audience', 12)->default('everyone'); // everyone | team_only
            $table->string('title');
            $table->text('body');
            $table->unsignedInteger('recipients')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        foreach (['event_announcements', 'help_replies', 'help_requests', 'event_duties', 'event_teams'] as $t) {
            Schema::dropIfExists($t);
        }
    }
};
