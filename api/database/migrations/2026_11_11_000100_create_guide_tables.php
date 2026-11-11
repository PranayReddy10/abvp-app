<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Conference guide: what a delegate needs at a big event, in one place.
        Schema::table('events', function (Blueprint $t) {
            $t->boolean('guide_enabled')->default(false);
            $t->decimal('venue_lat', 9, 6)->nullable();
            $t->decimal('venue_lng', 9, 6)->nullable();
            $t->string('helpline_phone', 20)->nullable();
        });

        Schema::create('guide_items', function (Blueprint $t) {
            $t->id();
            $t->foreignId('event_id')->constrained()->cascadeOnDelete();
            $t->string('kind', 20); // stay, arrival, food, office, session, exhibit, facility, tourist, emergency
            $t->string('title', 120);
            $t->string('subtitle', 160)->nullable();
            $t->string('region', 80)->nullable();       // stay: the ABVP prant (state) it is for
            $t->text('description')->nullable();
            $t->string('location', 160)->nullable();    // where: "Hall B, Stall 7, left of the stage"
            $t->string('landmark', 160)->nullable();    // how to spot it: "Green flag with a lotus"
            $t->string('color', 7)->nullable();         // identifying colour, #RRGGBB
            $t->string('timings', 120)->nullable();
            $t->json('tags')->nullable();               // short chips: Veg, Jain, Girls, 24x7…
            $t->json('steps')->nullable();              // how to reach, in order
            $t->string('map_url', 500)->nullable();
            $t->decimal('lat', 9, 6)->nullable();
            $t->decimal('lng', 9, 6)->nullable();
            $t->decimal('distance_km', 6, 1)->nullable(); // road distance to the venue, when known
            $t->string('travel_time', 60)->nullable();
            $t->json('photos')->nullable();
            $t->unsignedInteger('sort')->default(0);
            $t->timestamps();
            $t->index(['event_id', 'kind', 'sort']);
        });

        Schema::create('guide_contacts', function (Blueprint $t) {
            $t->id();
            $t->foreignId('guide_item_id')->constrained()->cascadeOnDelete();
            $t->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $t->string('name', 100);
            $t->string('role', 80)->nullable();
            $t->string('phone', 20)->nullable();
            $t->boolean('is_lead')->default(false);
            $t->unsignedInteger('sort')->default(0);
            $t->timestamps();
        });

        Schema::table('users', function (Blueprint $t) {
            $t->string('google_id', 64)->nullable()->unique();
            $t->string('google_email', 190)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', fn (Blueprint $t) => $t->dropColumn(['google_id', 'google_email']));
        Schema::dropIfExists('guide_contacts');
        Schema::dropIfExists('guide_items');
        Schema::table('events', fn (Blueprint $t) => $t->dropColumn(['guide_enabled', 'venue_lat', 'venue_lng', 'helpline_phone']));
    }
};
