<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // How each person is travelling to the event, and their pickup.
        Schema::create('event_travel', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('mode', 12); // train | bus | flight | own | other
            $table->string('reference', 60)->nullable(); // train or bus number
            $table->dateTime('arriving_at')->nullable();
            $table->string('arrival_point', 120)->nullable(); // Warangal railway station
            $table->dateTime('departing_at')->nullable();
            $table->boolean('needs_pickup')->default(false);
            $table->boolean('needs_stay')->default(false);
            $table->foreignId('vehicle_id')->nullable();
            $table->string('pickup_status', 12)->default('none'); // none | assigned | picked_up
            $table->timestamp('picked_up_at')->nullable();
            $table->string('notes', 300)->nullable();
            $table->timestamps();
            $table->unique(['event_id', 'user_id']);
            $table->index(['event_id', 'arriving_at']);
        });

        Schema::create('event_vehicles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->string('name', 60); // Bus 1
            $table->unsignedSmallInteger('capacity');
            $table->string('pickup_point', 120)->nullable();
            $table->dateTime('departs_at')->nullable();
            $table->string('driver_name', 80)->nullable();
            $table->string('driver_phone', 20)->nullable();
            $table->timestamps();
        });

        Schema::table('event_travel', function (Blueprint $table) {
            $table->foreign('vehicle_id')->references('id')->on('event_vehicles')->nullOnDelete();
        });

        // Accommodation: places (hostels, halls) with rooms of a given size.
        Schema::create('event_stays', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->string('name', 120);
            $table->string('address')->nullable();
            $table->string('map_url', 500)->nullable();
            $table->string('for_gender', 8)->default('any'); // any | female | male
            $table->timestamps();
        });

        Schema::create('event_rooms', function (Blueprint $table) {
            $table->id();
            $table->foreignId('stay_id')->constrained('event_stays')->cascadeOnDelete();
            $table->string('name', 40);
            $table->unsignedSmallInteger('capacity');
            $table->unique(['stay_id', 'name']);
        });

        Schema::create('room_allocations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->foreignId('room_id')->constrained('event_rooms')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->timestamp('checked_in_at')->nullable();
            $table->timestamp('checked_out_at')->nullable();
            $table->timestamps();
            $table->unique(['event_id', 'user_id']); // one bed per person per event
        });

        // Food: meal sessions, and who has been served (once each).
        Schema::create('meal_sessions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->string('name', 60); // Day 1 Lunch
            $table->dateTime('starts_at');
            $table->dateTime('ends_at');
            $table->string('location', 120)->nullable();
            $table->timestamps();
        });

        Schema::create('meal_servings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('meal_session_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('served_by')->nullable()->constrained('users');
            $table->string('counter', 40)->nullable();
            $table->timestamp('served_at');
            $table->unique(['meal_session_id', 'user_id']); // the database refuses a second plate
        });

        // Live location: opt-in, for a set time, to a named audience, stoppable any time.
        Schema::create('location_sessions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->string('shared_with', 16); // coordinators | team_lead
            $table->string('purpose', 160);
            $table->timestamp('expires_at');
            $table->timestamp('stopped_at')->nullable();
            $table->timestamps();
            $table->index(['event_id', 'expires_at']);
        });

        Schema::create('location_points', function (Blueprint $table) {
            $table->id();
            $table->foreignId('location_session_id')->constrained()->cascadeOnDelete();
            $table->decimal('lat', 9, 6);
            $table->decimal('lng', 9, 6);
            $table->unsignedSmallInteger('accuracy_m')->nullable();
            $table->timestamp('recorded_at')->index();
        });
    }

    public function down(): void
    {
        foreach (['location_points', 'location_sessions', 'meal_servings', 'meal_sessions', 'room_allocations', 'event_rooms', 'event_stays', 'event_travel', 'event_vehicles'] as $t) {
            Schema::dropIfExists($t);
        }
    }
};
