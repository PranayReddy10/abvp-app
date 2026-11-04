<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('events', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('category', 32)->default('programme');
            $table->text('instructions')->nullable(); // what to bring, reporting time
            $table->string('venue');
            $table->string('venue_map_url', 500)->nullable();
            $table->dateTime('starts_at');
            $table->dateTime('ends_at');
            $table->foreignId('org_unit_id')->constrained('org_units'); // organising area
            $table->foreignId('organiser_id')->constrained('users');
            // draft | published | cancelled | completed
            $table->string('status', 12)->default('draft')->index();
            $table->dateTime('registration_opens_at')->nullable();
            $table->dateTime('registration_closes_at')->nullable();
            $table->unsignedInteger('capacity')->nullable();
            $table->boolean('requires_approval')->default(false);
            $table->boolean('waitlist_enabled')->default(true);
            $table->string('contact_name')->nullable();
            $table->string('contact_phone', 20)->nullable();
            $table->timestamp('published_at')->nullable();
            $table->timestamps();
            $table->index(['status', 'starts_at']);
        });

        // Who may register. No rows = every approved member. Several rows = any one matches.
        Schema::create('event_eligibility_rules', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->foreignId('org_unit_id')->nullable()->constrained('org_units');
            $table->foreignId('vibhag_id')->nullable()->constrained('vibhags');
        });

        Schema::create('event_registrations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('kind', 8)->default('member'); // member | guest
            // registered | waitlisted | pending | cancelled | rejected
            $table->string('status', 12)->index();
            $table->string('guest_name')->nullable();
            $table->string('guest_organisation')->nullable();
            $table->foreignId('invited_by')->nullable()->constrained('users');
            $table->text('decision_note')->nullable();
            $table->timestamp('checked_in_at')->nullable();
            $table->foreignId('checked_in_by')->nullable()->constrained('users');
            $table->string('gate', 40)->nullable();
            $table->string('check_in_method', 8)->nullable(); // scan | manual | offline
            $table->timestamps();
            $table->unique(['event_id', 'user_id']);
            $table->index(['event_id', 'status', 'kind']);
        });

        // Volunteers who may scan passes or coordinate on the day.
        Schema::create('event_staff', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('role', 16)->default('scanner'); // scanner | coordinator
            $table->timestamps();
            $table->unique(['event_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('event_staff');
        Schema::dropIfExists('event_registrations');
        Schema::dropIfExists('event_eligibility_rules');
        Schema::dropIfExists('events');
    }
};
