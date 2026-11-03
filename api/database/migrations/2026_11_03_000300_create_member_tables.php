<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('member_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->string('member_id', 32)->nullable()->unique();
            $table->string('full_name');
            $table->string('gender', 16)->nullable();
            $table->date('date_of_birth')->nullable();
            $table->string('photo_path')->nullable();
            $table->foreignId('org_unit_id')->nullable()->constrained('org_units');
            $table->string('institution')->nullable();
            $table->string('course')->nullable();
            $table->string('study_year', 16)->nullable();
            $table->text('bio')->nullable();
            $table->json('languages')->nullable();
            $table->json('skills')->nullable();
            $table->json('links')->nullable();
            $table->json('privacy')->nullable();
            // draft | submitted | more_info_required | approved | rejected | suspended
            $table->string('membership_status', 24)->default('draft')->index();
            $table->timestamp('approved_at')->nullable();
            $table->timestamps();
        });

        Schema::create('member_vibhag', function (Blueprint $table) {
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('vibhag_id')->constrained()->cascadeOnDelete();
            $table->timestamp('joined_at')->nullable();
            $table->primary(['user_id', 'vibhag_id']);
        });

        Schema::create('membership_applications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            // The unit the applicant chose. Admins whose scope contains it can review.
            $table->foreignId('org_unit_id')->constrained('org_units');
            // submitted | more_info_required | approved | rejected
            $table->string('status', 24)->default('submitted');
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('decided_at')->nullable();
            $table->foreignId('decided_by')->nullable()->constrained('users');
            $table->text('decision_note')->nullable();
            $table->timestamps();
            $table->index(['status', 'submitted_at']);
        });

        Schema::create('application_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('membership_application_id')->constrained()->cascadeOnDelete();
            $table->foreignId('actor_id')->nullable()->constrained('users');
            $table->string('action', 32); // submitted | resubmitted | approved | returned | rejected
            $table->text('note')->nullable();
            $table->timestamp('created_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('application_events');
        Schema::dropIfExists('membership_applications');
        Schema::dropIfExists('member_vibhag');
        Schema::dropIfExists('member_profiles');
    }
};
