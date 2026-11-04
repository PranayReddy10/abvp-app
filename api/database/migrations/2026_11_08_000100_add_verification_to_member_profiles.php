<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // "Verified" is more than "approved": an office checked this person's identity
        // (ID, in person) and vouches for the profile. Shown as a blue tick.
        Schema::table('member_profiles', function (Blueprint $table) {
            $table->timestamp('verified_at')->nullable()->after('approved_at');
            $table->foreignId('verified_by')->nullable()->after('verified_at')->constrained('users');
            $table->string('verification_note', 300)->nullable()->after('verified_by');
        });
    }

    public function down(): void
    {
        Schema::table('member_profiles', function (Blueprint $table) {
            $table->dropConstrainedForeignId('verified_by');
            $table->dropColumn(['verified_at', 'verification_note']);
        });
    }
};
