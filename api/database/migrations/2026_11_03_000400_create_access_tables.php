<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // App permissions. Always scoped to an org unit (and optionally a vibhag).
        Schema::create('role_assignments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('role', 32);
            $table->foreignId('org_unit_id')->constrained('org_units');
            $table->foreignId('vibhag_id')->nullable()->constrained('vibhags');
            $table->foreignId('assigned_by')->nullable()->constrained('users');
            $table->date('starts_on')->nullable();
            $table->date('ends_on')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'role']);
        });

        // Dayitva: organisational posts held over time, shown on the profile.
        // Separate from app permissions: a Zilla Sanyojak need not be an app admin.
        Schema::create('responsibilities', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('title');
            $table->foreignId('org_unit_id')->nullable()->constrained('org_units');
            $table->foreignId('vibhag_id')->nullable()->constrained('vibhags');
            $table->date('starts_on');
            $table->date('ends_on')->nullable();
            $table->foreignId('added_by')->nullable()->constrained('users');
            $table->timestamps();
            $table->index(['user_id', 'starts_on']);
        });

        Schema::create('audit_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('actor_id')->nullable()->constrained('users');
            $table->string('action', 64)->index();
            $table->string('subject_type', 64)->nullable();
            $table->unsignedBigInteger('subject_id')->nullable();
            $table->json('before')->nullable();
            $table->json('after')->nullable();
            $table->string('ip', 45)->nullable();
            $table->timestamp('created_at')->nullable()->index();
            $table->index(['subject_type', 'subject_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
        Schema::dropIfExists('responsibilities');
        Schema::dropIfExists('role_assignments');
    }
};
