<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Basic details from the sign-up form (anyone, not only members).
        Schema::table('users', function (Blueprint $t) {
            $t->string('prant', 80)->nullable();
            $t->string('institution', 150)->nullable();
            $t->string('occupation', 80)->nullable();
            $t->string('gender', 10)->nullable();
        });

        // Anyone can register as a delegate for a big conference, with their travel and stay needs.
        Schema::table('events', function (Blueprint $t) {
            $t->boolean('delegate_registration_open')->default(false);
        });
        Schema::table('event_registrations', function (Blueprint $t) {
            $t->json('details')->nullable(); // prant, gender, food, emergency contact…
        });
    }

    public function down(): void
    {
        Schema::table('event_registrations', fn (Blueprint $t) => $t->dropColumn('details'));
        Schema::table('events', fn (Blueprint $t) => $t->dropColumn('delegate_registration_open'));
        Schema::table('users', fn (Blueprint $t) => $t->dropColumn(['prant', 'institution', 'occupation', 'gender']));
    }
};
