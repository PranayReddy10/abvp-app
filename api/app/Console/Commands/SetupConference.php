<?php

namespace App\Console\Commands;

use App\Models\Event;
use App\Models\GuideContact;
use App\Models\GuideItem;
use App\Models\OrgUnit;
use App\Models\User;
use App\Support\Mobile;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Creates the national conference with its guide already laid out, using public facts only
 * (stations, airport, emergency numbers, tourist places). No made-up people: organisers add the
 * leads, stays and stalls in the admin panel. Safe to run on the live server.
 */
class SetupConference extends Command
{
    protected $signature = 'abvp:setup-conference
        {--title=Rashtriya Adhiveshan 2026 – Bhagyanagar : Event name}
        {--start=2026-12-26 09:00 : First day and time (India time)}
        {--days=3 : Number of days}
        {--venue=Hyderabad : Venue as delegates should see it}
        {--lat=17.385 : Venue latitude}
        {--lng=78.4867 : Venue longitude}
        {--helpline= : 24x7 helpline number}
        {--organiser= : Mobile number of the organising admin (defaults to the first super admin)}';

    protected $description = 'Create the national conference with a ready-to-fill conference guide (no sample people)';

    public function handle(): int
    {
        $state = OrgUnit::where('name', 'Telangana')->where('type', 'state')->first() ?? OrgUnit::whereNull('parent_id')->first();
        if (! $state) {
            $this->error('Run "php artisan db:seed --force" first so states and districts exist.');

            return self::FAILURE;
        }
        $organiser = $this->option('organiser')
            ? User::where('mobile', Mobile::normalize($this->option('organiser')))->first()
            : User::whereHas('roleAssignments', fn ($q) => $q->where('role', 'super_admin'))->first();
        if (! $organiser) {
            $this->error('No organiser found. Create an admin first: php artisan abvp:make-admin 98XXXXXXXX "Your Name"');

            return self::FAILURE;
        }
        if (Event::where('title', $this->option('title'))->exists()) {
            $this->warn('An event with this name already exists. Nothing was changed.');

            return self::SUCCESS;
        }

        $start = Carbon::parse($this->option('start'), 'Asia/Kolkata');
        $end = $start->copy()->addDays(max(1, (int) $this->option('days')) - 1)->setTime(18, 0);

        $event = DB::transaction(function () use ($state, $organiser, $start, $end) {
            $event = Event::create([
                'title' => $this->option('title'), 'category' => 'conference', 'venue' => $this->option('venue'),
                'description' => 'The national conference of ABVP. The conference guide shows where to stay, how to reach, food, help desks and emergency contacts.',
                'instructions' => 'Carry your pass and a photo ID.',
                'starts_at' => $start->copy()->utc(), 'ends_at' => $end->copy()->utc(),
                'org_unit_id' => $state->id, 'organiser_id' => $organiser->id, 'capacity' => null,
                'venue_lat' => (float) $this->option('lat'), 'venue_lng' => (float) $this->option('lng'),
                'helpline_phone' => $this->option('helpline'), 'contact_phone' => $this->option('helpline'),
                // Off until the organisers have filled the guide; switch on in admin → event → Guide.
                'guide_enabled' => false, 'delegate_registration_open' => false,
            ]);
            $event->forceFill(['status' => 'published', 'published_at' => now()])->save();

            $sort = [];
            $add = function (string $kind, array $data, array $contacts = []) use ($event, &$sort) {
                $sort[$kind] = ($sort[$kind] ?? 0) + 1;
                $item = GuideItem::create($data + ['event_id' => $event->id, 'kind' => $kind, 'sort' => $sort[$kind]]);
                foreach ($contacts as $i => [$name, $phone, $role]) {
                    GuideContact::create(['guide_item_id' => $item->id, 'name' => $name, 'phone' => $phone, 'role' => $role, 'is_lead' => true, 'sort' => $i]);
                }
            };

            // Arrival points in Hyderabad. Desk spot, timings, steps and desk leads are added by the Yatayat team.
            foreach ([
                ['RGI Airport, Shamshabad', 17.2403, 78.4294, ['Airport']],
                ['Secunderabad Railway Station', 17.4337, 78.5016, ['Train']],
                ['Hyderabad (Nampally) Railway Station', 17.3925, 78.4676, ['Train']],
                ['Kacheguda Railway Station', 17.3896, 78.5005, ['Train']],
                ['Cherlapally Railway Terminal', 17.4600, 78.6000, ['Train']],
                ['Lingampally Railway Station', 17.4837, 78.3158, ['Train']],
                ['MGBS Bus Station', 17.3780, 78.4820, ['Bus']],
                ['JBS Bus Station, Secunderabad', 17.4486, 78.4983, ['Bus']],
            ] as [$title, $lat, $lng, $tags]) {
                $add('arrival', ['title' => $title, 'lat' => $lat, 'lng' => $lng, 'tags' => $tags]);
            }

            // National emergency numbers.
            foreach ([['Ambulance', 'National emergency ambulance', '108'], ['Police / any emergency', 'All-in-one emergency number', '112'], ['Women helpline', 'Women in distress', '181']] as [$title, $sub, $no]) {
                $add('emergency', ['title' => $title, 'subtitle' => $sub, 'color' => '#C92A2A'], [[$title, $no, 'Call']]);
            }

            // Places to visit around Hyderabad.
            foreach ([
                ['Bhagyalakshmi Temple, Charminar', 'Temple beside the Charminar, in the old city', 17.3616, 78.4747],
                ['Birla Mandir', 'Temple of Sri Venkateswara on Naubat Pahad', 17.4062, 78.4691],
                ['Yadadri Sri Lakshmi Narasimha Swamy Temple', 'Hill temple at Yadagirigutta, about 60 km away', 17.5891, 78.9437],
                ['Golconda Fort', 'Hill fort with a sound and light show', 17.3833, 78.4011],
                ['Salar Jung Museum', 'One of India\'s largest museums (closed on Fridays)', 17.3713, 78.4804],
            ] as [$title, $sub, $lat, $lng]) {
                $add('tourist', ['title' => $title, 'subtitle' => $sub, 'lat' => $lat, 'lng' => $lng, 'description' => 'Go in a group and tell your Nivas lead before you leave.']);
            }

            // Offices most conferences need; the Karyalay team adds location, hours and the person in charge.
            foreach ([['Adhiveshan Karyalay', 'Central office: passes, changes, anything you cannot find'], ['Panjikaran (Registration)', 'Collect your kit and badge'], ['Suchana Sahayata (Information)', 'Where is what, session times, lost and found'], ['Pratham Sahayata (First aid)', 'Doctor and nurses on duty'], ['Mahila Sahayata', 'Women volunteers for any concern']] as [$title, $sub]) {
                $add('office', ['title' => $title, 'subtitle' => $sub]);
            }

            return $event;
        });

        $this->info("Created \"{$event->title}\" (event #{$event->id}) with arrival points, emergency numbers, offices and tourist places.");
        $this->line('Next, in the admin panel → Events → this event → Guide tab:');
        $this->line('  1. Add stays per prant, food stalls, sessions, exhibition, campus and hall emergency leads, with their phone numbers.');
        $this->line('  2. Fill each arrival desk (spot, hours, steps, desk lead).');
        $this->line('  3. Switch on "Conference guide" and "Delegate registration" when ready.');

        return self::SUCCESS;
    }
}
