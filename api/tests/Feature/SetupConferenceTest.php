<?php

namespace Tests\Feature;

use App\Models\Event;
use App\Models\GuideItem;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SetupConferenceTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_creates_the_conference_with_a_guide_and_no_sample_people(): void
    {
        $this->seed(DatabaseSeeder::class);
        $this->artisan('abvp:setup-conference')->assertFailed();

        $this->artisan('abvp:make-admin', ['mobile' => '9848000001', 'name' => 'Admin'])->assertSuccessful();
        $this->artisan('abvp:setup-conference', ['--helpline' => '9000090000', '--start' => '2026-12-26 09:00'])->assertSuccessful();
        $this->artisan('abvp:setup-conference')->assertSuccessful(); // second run changes nothing

        $event = Event::sole();
        $this->assertSame('2026-12-26 03:30:00', $event->starts_at->utc()->format('Y-m-d H:i:s'));
        $this->assertFalse($event->guide_enabled);
        $this->assertSame(8, GuideItem::where('kind', 'arrival')->count());
        $this->assertSame(['108', '112', '181'], GuideItem::where('kind', 'emergency')->with('contacts')->get()->map(fn ($i) => $i->contacts[0]->phone)->all());
        // Only the national emergency numbers have contacts; everyone else is added by organisers.
        $this->assertSame(0, GuideItem::where('kind', '!=', 'emergency')->has('contacts')->count());
    }
}
