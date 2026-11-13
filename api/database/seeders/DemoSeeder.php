<?php

namespace Database\Seeders;

use App\Models\ActivityReport;
use App\Models\ApplicationEvent;
use App\Models\Circular;
use App\Models\Event;
use App\Models\EventRegistration;
use App\Models\EventAnnouncement;
use App\Models\EventDuty;
use App\Models\EventStaff;
use App\Models\EventTeam;
use App\Models\EventStay;
use App\Models\EventRoom;
use App\Models\EventTravel;
use App\Models\EventVehicle;
use App\Models\LocationPoint;
use App\Models\LocationSession;
use App\Models\MealServing;
use App\Models\MealSession;
use App\Services\LogisticsService;
use App\Models\HelpReply;
use App\Models\HelpRequest;
use App\Models\CircularRead;
use App\Models\MemberProfile;
use App\Models\MembershipApplication;
use App\Models\Meeting;
use App\Models\MeetingInvitee;
use App\Models\OrgUnit;
use App\Models\Responsibility;
use App\Models\RoleAssignment;
use App\Models\GuideContact;
use App\Models\GuideItem;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use App\Models\Vibhag;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use RuntimeException;

/**
 * Example data for demos and local testing: ~150 members across Telangana with six
 * months of applications, meetings, circulars and activity reports.
 * Run: php artisan db:seed --class=DemoSeeder   (refuses to run in production)
 */
class DemoSeeder extends Seeder
{
    private const WOMEN = ['Anusha', 'Sneha', 'Lakshmi', 'Divya', 'Harika', 'Pooja', 'Keerthi', 'Swathi', 'Bhavana', 'Meghana', 'Sowmya', 'Nikitha'];

    private const MEN = ['Ravi', 'Kiran', 'Vamshi', 'Rahul', 'Sai', 'Naveen', 'Arjun', 'Manoj', 'Teja', 'Srikanth', 'Praveen', 'Ajay'];

    private const LAST = ['Reddy', 'Naidu', 'Rao', 'Sharma', 'Goud', 'Patil', 'Kumar', 'Varma', 'Yadav', 'Chary', 'Mudiraj', 'Gupta'];

    private int $n = 0;

    public function run(): void
    {
        if (app()->environment('production')) {
            throw new RuntimeException('DemoSeeder must not run in production.');
        }
        mt_srand(2026);

        $state = OrgUnit::where('name', 'Telangana')->firstOrFail();
        $units = OrgUnit::within($state)->where('type', 'unit')->get();
        $vibhags = Vibhag::all();
        $weights = ['Osmania University' => 9, 'Secunderabad' => 6, 'Kukatpally' => 5, 'LB Nagar' => 4, 'Charminar' => 2, 'Kakatiya University' => 6, 'Hanamkonda' => 3, 'Karimnagar Town' => 3, 'Nizamabad Town' => 1, 'Khammam Town' => 2];

        $admin = User::where('mobile', '+919848000001')->first();
        $reviewers = [$admin, $this->person($units->firstWhere('name', 'Osmania University'), now()->subMonths(8), $vibhags, 'Srinivas Rao')];
        RoleAssignment::firstOrCreate(['user_id' => $reviewers[1]->id, 'role' => 'verification_officer', 'org_unit_id' => OrgUnit::where('name', 'Hyderabad')->value('id')]);

        // Members joining over six months, more in recent months.
        $members = collect();
        foreach ($units as $unit) {
            $count = ($weights[$unit->name] ?? 2) * 3;
            for ($i = 0; $i < $count; $i++) {
                $submitted = now()->subDays((int) (180 * (mt_rand(0, 1000) / 1000) ** 1.6) + 2);
                $outcome = mt_rand(1, 100);
                $user = $this->person($unit, $submitted, $vibhags);
                $app = MembershipApplication::create(['user_id' => $user->id, 'org_unit_id' => $unit->id, 'status' => 'submitted', 'submitted_at' => $submitted]);
                $this->event($app, $user, 'submitted', $submitted);

                if ($outcome <= 8 && $submitted->gt(now()->subDays(20))) {
                    $user->profile->forceFill(['membership_status' => 'submitted'])->save();
                    continue; // still waiting
                }
                $reviewer = $reviewers[mt_rand(0, 1)] ?? $admin;
                $decided = $submitted->copy()->addHours(mt_rand(6, 24 * 9));
                if ($decided->isFuture()) {
                    $decided = now()->subHour();
                }
                if ($outcome <= 14) {
                    $this->event($app, $reviewer, 'returned', $decided, 'Photo is unclear. Please upload a clear one.');
                    $decided = $decided->copy()->addDays(2)->min(now());
                    $this->event($app, $user, 'resubmitted', $decided);
                    $decided = $decided->copy()->addDay()->min(now());
                }
                $status = $outcome > 96 ? 'rejected' : 'approved';
                $app->forceFill(['status' => $status, 'decided_at' => $decided, 'decided_by' => $reviewer?->id])->save();
                $this->event($app, $reviewer, $status, $decided);
                if ($status === 'approved') {
                    $user->profile->forceFill(['membership_status' => 'approved', 'approved_at' => $decided, 'member_id' => 'DEMO-'.str_pad((string) $user->id, 6, '0', STR_PAD_LEFT)])->save();
                    $members->push($user);
                } else {
                    $user->profile->forceFill(['membership_status' => 'rejected'])->save();
                }
            }
        }

        // Dayitva for a few.
        foreach ($members->random(8) as $i => $m) {
            Responsibility::create(['user_id' => $m->id, 'title' => ['Ikai Mantri', 'Ikai Adhyaksh', 'Nagar Sanyojak', 'Vibhag Sanyojak'][$i % 4], 'org_unit_id' => $m->profile->org_unit_id, 'starts_on' => now()->subMonths(mt_rand(2, 10))->toDateString()]);
        }

        // Monthly district baithaks with attendance.
        foreach (['Hyderabad', 'Warangal'] as $d) {
            $district = OrgUnit::where('name', $d)->first();
            $inDistrict = $members->filter(fn ($m) => str_starts_with($m->profile->orgUnit->path, $district->path));
            for ($k = 5; $k >= 0; $k--) {
                $start = now()->subMonths($k)->startOfMonth()->addDays(mt_rand(3, 20))->setTime(13, 30);
                if ($start->isFuture()) {
                    continue;
                }
                $vibhag = $vibhags->random();
                $mt = Meeting::create(['kind' => 'meeting', 'title' => "{$vibhag->name} Zilla Baithak – ".$start->format('F'), 'mode' => 'online', 'link' => 'https://meet.google.com/demo-'.$k.'-'.$district->id, 'provider' => 'google_meet', 'starts_at' => $start, 'ends_at' => $start->copy()->addHour(), 'organiser_id' => $admin?->id ?? $members->first()->id, 'org_unit_id' => $district->id, 'vibhag_id' => null, 'minutes' => $k > 0 ? 'Reviewed last month. Planned next programmes.' : null]);
                foreach ($inDistrict->filter(fn ($m) => $m->profile->approved_at->lt($start)) as $m) {
                    $joined = mt_rand(1, 100) <= 58;
                    MeetingInvitee::create(['meeting_id' => $mt->id, 'user_id' => $m->id, 'rsvp' => $joined ? 'going' : ['pending', 'maybe', 'no'][mt_rand(0, 2)], 'joined_at' => $joined ? $start : null]);
                }
            }
        }

        // Circulars and who read them.
        foreach ([['Sadasyata Abhiyan 2026–27 guidelines', 'Telangana', 40], ['Campus Sampark schedule', 'Hyderabad', 15], ['Tree plantation drive, 1–15 December', 'Telangana', 6]] as [$title, $unitName, $daysAgo]) {
            $unit = OrgUnit::where('name', $unitName)->first();
            $c = new Circular(['title' => $title, 'body' => 'Details for all units. Plan and report through the app.', 'org_unit_id' => $unit->id, 'issued_by' => $admin?->id ?? $members->first()->id, 'published_at' => now()->subDays($daysAgo)]);
            $c->setRelation('orgUnit', $unit);
            $c->audience_size = $c->audienceQuery()->count();
            $c->save();
            foreach ($c->audienceQuery()->pluck('user_id') as $uid) {
                if (mt_rand(1, 100) <= min(90, 35 + $daysAgo * 2)) {
                    CircularRead::create(['circular_id' => $c->id, 'user_id' => $uid, 'read_at' => now()->subDays(mt_rand(0, $daysAgo))]);
                }
            }
        }

        $this->events($state, $members, $admin);
        $this->feed($members);
        $this->conference($members, $admin);

        // Activity reports. Some units go quiet so the analysis has something to flag.
        $types = array_keys(ActivityReport::TYPES);
        $titles = ['seva' => 'Lake clean-up drive', 'campus_contact' => 'Campus contact programme', 'seminar' => 'Talk on National Education Policy', 'training' => 'Prathmik Abhyas Varg', 'agitation' => 'Hostel fee protest', 'membership_drive' => 'Sadasyata Abhiyan', 'cultural' => 'Swami Vivekananda Jayanti', 'sports' => 'Inter-college kabaddi', 'meeting' => 'Ikai Baithak', 'other' => 'Blood donation camp'];
        foreach ($units as $unit) {
            if (in_array($unit->name, ['Charminar', 'Nizamabad Town'], true)) {
                $reports = 1;
                $recentOk = false;
            } else {
                $reports = (int) round(($weights[$unit->name] ?? 2) * 2.2);
                $recentOk = true;
            }
            $submitter = $members->first(fn ($m) => $m->profile->org_unit_id === $unit->id) ?? $members->first();
            for ($i = 0; $i < $reports; $i++) {
                $type = $types[mt_rand(0, count($types) - 1)];
                $held = $recentOk ? now()->subDays(mt_rand(0, 175)) : now()->subDays(mt_rand(60, 160));
                ActivityReport::create(['org_unit_id' => $unit->id, 'vibhag_id' => mt_rand(0, 2) ? $vibhags->random()->id : null, 'submitted_by' => $submitter->id, 'title' => $titles[$type], 'programme_type' => $type, 'held_on' => $held->toDateString(), 'place' => $unit->name, 'participants' => mt_rand(15, 220), 'institutions' => mt_rand(1, 6), 'created_at' => $held, 'updated_at' => $held]);
            }
        }
    }

    /** A national conference in Hyderabad with the delegate guide filled in. */
    private function conference($members, ?User $admin): void
    {
        $state = OrgUnit::where('name', 'Telangana')->first();
        $start = Carbon::create(2026, 12, 26, 3, 30); // 9 AM IST
        $event = Event::create([
            'title' => 'Rashtriya Adhiveshan 2026 – Bhagyanagar', 'category' => 'conference',
            'description' => 'The national conference of ABVP. Delegates from every prant meet in Bhagyanagar for three days of sessions, the exhibition and the shobha yatra.',
            'venue' => 'Adhiveshan Nagar, Hyderabad (demo venue)', 'starts_at' => $start, 'ends_at' => $start->copy()->addDays(3)->setTime(12, 30),
            'org_unit_id' => $state->id, 'organiser_id' => $admin?->id ?? $members->first()->id, 'capacity' => 10000,
            'instructions' => 'Carry your pass and a photo ID. Your stay and help desks are in the Conference guide.',
            'contact_name' => 'Adhiveshan Karyalay', 'contact_phone' => '9000090000',
            'guide_enabled' => true, 'venue_lat' => 17.3850, 'venue_lng' => 78.4867, 'helpline_phone' => '9000090000',
        ]);
        $event->forceFill(['status' => 'published', 'published_at' => now()->subDays(30)])->save();
        $event->forceFill(['cover_path' => $this->art('events/covers', 77)])->save();
        foreach ($members->take(70) as $m) {
            EventRegistration::create(['event_id' => $event->id, 'user_id' => $m->id, 'kind' => 'member', 'status' => 'registered']);
        }

        $first = ['Akhil', 'Saicharan', 'Ravi', 'Sneha', 'Arjun', 'Pooja', 'Vikram', 'Divya', 'Rohit', 'Anusha', 'Karthik', 'Meghana', 'Suresh', 'Lavanya', 'Naveen', 'Harika', 'Manoj', 'Bhavana', 'Rakesh', 'Swathi'];
        $last = ['Reddy', 'Rao', 'Goud', 'Sharma', 'Naidu', 'Varma', 'Patil', 'Yadav'];
        $n = 0;
        $person = function (?string $name = null) use (&$n, $first, $last) {
            $n++;

            return [$name ?? $first[$n % count($first)].' '.$last[$n % count($last)], '90000'.str_pad((string) (10000 + $n * 37), 5, '0', STR_PAD_LEFT)];
        };
        $add = function (string $kind, array $data, array $contacts = [], int $photos = 0) use ($event) {
            static $sort = [];
            $sort[$kind] = ($sort[$kind] ?? 0) + 1;
            $item = GuideItem::create($data + ['event_id' => $event->id, 'kind' => $kind, 'sort' => $sort[$kind]]);
            if ($photos) {
                $item->forceFill(['photos' => collect(range(1, $photos))->map(fn ($k) => $this->art('guide/'.$event->id, $item->id * 10 + $k))->all()])->save();
            }
            foreach ($contacts as $i => [$name, $phone, $role, $lead]) {
                GuideContact::create(['guide_item_id' => $item->id, 'name' => $name, 'phone' => $phone, 'role' => $role, 'is_lead' => $lead, 'sort' => $i]);
            }
        };

        // Yatayat: one desk and lead at every arrival point.
        $arrivals = [
            ['RGI Airport, Shamshabad', 'Arrivals hall, Gate 4', 17.2403, 78.4294, 32, '50 min by shuttle', 'Pushpak bus or the Adhiveshan shuttle every 30 minutes', 'Akhil'],
            ['Secunderabad Railway Station', 'Platform 1 exit, near the clock tower', 17.4337, 78.5016, 8, '25 min', 'Shuttle from the Platform 1 parking, every 20 minutes', null],
            ['Kacheguda Railway Station', 'Main entrance, booking office side', 17.3896, 78.5005, 4, '15 min', 'Shuttle every 30 minutes from the main gate', null],
            ['Cherlapally Railway Terminal', 'New terminal, exit gate 2', 17.4600, 78.6000, 17, '40 min', 'Shuttle every 45 minutes, or MMTS to Secunderabad', null],
            ['JBS Bus Station, Secunderabad', 'Platform 6, enquiry counter', 17.4486, 78.4983, 9, '25 min', 'Shuttle every 30 minutes from Gate 2', null],
            ['MGBS Bus Station', 'Main concourse, near the police outpost', 17.3780, 78.4820, 2, '10 min', 'Shuttle every 20 minutes, or walk with a volunteer', null],
        ];
        foreach ($arrivals as [$title, $desk, $lat, $lng, $km, $time, $how, $leadName]) {
            [$ln, $lp] = $person($leadName ? $leadName.' Kumar' : null);
            [$vn, $vp] = $person();
            [$wn, $wp] = $person();
            $add('arrival', [
                'title' => $title, 'subtitle' => 'Help desk: '.$desk, 'location' => $desk, 'landmark' => 'Saffron ABVP banner and volunteers in saffron scarves',
                'lat' => $lat, 'lng' => $lng, 'distance_km' => $km, 'travel_time' => $time, 'timings' => 'Open 24 hours, 24–29 December', 'tags' => ['24x7', 'Shuttle'],
                'steps' => ["Come out at: {$desk}", 'Look for the saffron ABVP Swagat banner', 'Show your pass QR to the desk volunteer', $how, 'Get off at Adhiveshan Nagar, Gate 1 – the registration desk is on your left'],
            ], [[$ln, $lp, 'Desk lead', true], [$vn, $vp, 'Volunteer', false], [$wn, $wp, 'Volunteer (night)', false]]);
        }

        // Nivas: stays per prant, each with a lead and a small team.
        $places = ['SVIT Engineering College', 'Keshav Memorial Hostel', 'Bhagyanagar Grand Hotel', 'Saffron Residency (hotel)', 'Vidya Bharati School Campus', 'Nagar Bhavan Dormitory'];
        foreach (config('abvp.prants') as $i => $prant) {
            $place = $prant === 'Konkan (Mumbai)' ? 'SVIT Engineering College' : $places[$i % count($places)];
            $team = [[...$person($prant === 'Konkan (Mumbai)' ? 'Saicharan Reddy' : null), 'Nivas lead', true], [...$person(), 'Team', false]];
            if ($i % 3 === 0) {
                $team[] = [...$person(), 'Team', false];
            }
            $girls = $i % 4 === 1;
            $add('stay', [
                'title' => $place, 'region' => $prant, 'subtitle' => $girls ? 'Girls block' : 'Boys block',
                'location' => ($girls ? 'Block G' : 'Block '.chr(65 + $i % 6)).', rooms '.(100 + $i * 4).'–'.(103 + $i * 4),
                'tags' => [$girls ? 'Girls' : 'Boys', 'Hot water'], 'timings' => 'Check-in from 24 Dec, 6 AM',
                'lat' => 17.38 + ($i % 7) * 0.012, 'lng' => 78.45 + ($i % 5) * 0.015, 'travel_time' => (5 + $i % 4 * 5).' min by shuttle',
            ], $team);
        }

        // Bhojan: halls and state stalls, each with a colour and landmark to spot it.
        $food = [
            ['Annapurna Bhojanalaya – Hall A', 'Main dining hall: breakfast, lunch and dinner', 'Hall A, behind the main stage', 'Big saffron arch with a kalash', '#E3620C', ['Veg', 'Main meals'], '7–9 AM · 12–3 PM · 7–10 PM'],
            ['Telangana Ruchulu', 'Pulihora, sakinalu, bobbatlu', 'Food court, Hall B, Stall 3', 'Green flag with a Bathukamma', '#2E8B57', ['Veg', 'Telangana'], '11 AM – 10 PM'],
            ['Andhra Vantillu', 'Pesarattu, gongura and more', 'Food court, Hall B, Stall 4', 'Yellow board with a mango leaf toran', '#D4A017', ['Veg', 'Andhra'], '11 AM – 10 PM'],
            ['Rajasthani Rasoi', 'Dal baati churma, ghevar', 'Food court, Hall B, Stall 8', 'Pink umbrella', '#D6336C', ['Veg', 'Rajasthan'], '11 AM – 10 PM'],
            ['Bengal Mishti Ghar', 'Rasgulla, sandesh, mishti doi', 'Food court, Hall B, Stall 11', 'White and red board', '#C92A2A', ['Sweets', 'Bengal'], '12 – 9 PM'],
            ['Jain Rasoi', 'No onion, no garlic meals', 'Hall A, counter 9', 'Blue Jain Rasoi board', '#1971C2', ['Jain'], '7–9 AM · 12–3 PM · 7–9 PM'],
            ['Chai & Snacks Kendra', 'Tea, coffee, biscuits, water', 'Near Gate 2 and next to the exhibition', 'Tea-cup cut-out', '#8B5E34', ['Snacks', '24x7'], 'Open 24 hours'],
        ];
        foreach ($food as $k => [$title, $sub, $where, $mark, $color, $tags, $time]) {
            $add('food', ['title' => $title, 'subtitle' => $sub, 'location' => $where, 'landmark' => $mark, 'color' => $color, 'tags' => $tags, 'timings' => $time,
                'description' => 'Show your pass at the counter. Please keep the hall clean – plates go in the green bins.'], [[...$person(), 'Stall lead', true]], $k < 3 ? 1 : 0);
        }

        // Karyalay.
        $offices = [
            ['Adhiveshan Karyalay', 'Central office: passes, changes, anything you cannot find', 'Gate 1, first tent on the right'],
            ['Panjikaran (Registration)', 'Collect your kit and badge', 'Gate 1, left side'],
            ['Suchana Sahayata (Information)', 'Where is what, session times, lost and found', 'Next to the main stage, and at Gate 2'],
            ['Pratham Sahayata (First aid)', 'Doctor and nurses on duty, medicines', 'Behind Hall A, red cross flag'],
            ['Mahila Sahayata (Help for girls)', 'Women volunteers for any concern', 'Block G entrance and near the main stage'],
            ['Media Kendra', 'Press, photos and social media team', 'Hall C, first floor'],
        ];
        foreach ($offices as [$title, $sub, $where]) {
            $add('office', ['title' => $title, 'subtitle' => $sub, 'location' => $where, 'timings' => '24–29 Dec, 7 AM – 11 PM'], [[...$person(), 'In charge', true], [...$person(), 'Team', false]]);
        }

        // Baithak: the programme.
        $sessions = [
            ['Udghatan Satra', 'Inauguration', 'Main stage', 0, '10:00 AM – 12:30 PM'],
            ['Pratinidhi Sabha', 'Delegates meeting by prant', 'Halls C and D', 0, '3:00 – 6:00 PM'],
            ['Khula Adhiveshan', 'Open session and resolutions', 'Main stage', 1, '10:00 AM – 1:00 PM'],
            ['Shobha Yatra', 'Procession through the city', 'Starts at Gate 3', 1, '3:30 – 6:30 PM'],
            ['Samapan Satra', 'Closing session', 'Main stage', 2, '10:00 AM – 12:30 PM'],
        ];
        foreach ($sessions as [$title, $sub, $where, $day, $time]) {
            $add('session', ['title' => $title, 'subtitle' => $sub, 'location' => $where, 'timings' => 'Day '.($day + 1).', '.$start->copy()->addDays($day)->format('j M').' · '.$time]);
        }

        // Pradarshini: digital showcase.
        $exhibits = [
            ['History of Telangana', 'From the Kakatiyas to statehood', 'Stories, maps and photographs of Telangana through the centuries. The full panels and captions are added by the Pradarshini team.'],
            ['History of Bhagyanagar', 'The city that hosts us', 'Old photographs and stories of Bhagyanagar (Hyderabad). The Pradarshini team adds the panels here.'],
            ['Display of pictures', 'ABVP through the years', 'Pictures from campaigns, conferences and seva work across the country.'],
            ['Martyrs of ABVP', 'Remembering those who gave their lives', 'Names, photographs and the stories of karyakartas we remember. Added by the Pradarshini team after verification.'],
        ];
        foreach ($exhibits as [$title, $sub, $desc]) {
            $add('exhibit', ['title' => $title, 'subtitle' => $sub, 'description' => $desc, 'location' => 'Pradarshini, Hall E', 'timings' => '9 AM – 9 PM'], [[...$person(), 'Pradarshini lead', true]], 3);
        }

        // Parisar: campus facilities.
        $facilities = [
            ['Bus parking', 'For buses coming from other states', 'Ground 2, enter by Gate 4', ['Buses']],
            ['Two-wheeler and car parking', 'Volunteers guide you to a slot', 'Next to Gate 3', ['Bikes', 'Cars']],
            ['Washrooms – men', 'Cleaned every 2 hours', 'Behind Halls A and C', ['Men']],
            ['Washrooms – women', 'Women volunteers on duty', 'Next to Block G and behind Hall B', ['Women']],
            ['Drinking water', 'RO water points', 'Every hall entrance and near the food court', ['24x7']],
            ['Cloak room and mobile charging', 'Leave bags safely; charge your phone', 'Gate 1, next to the Karyalay', ['Charging']],
        ];
        foreach ($facilities as [$title, $sub, $where, $tags]) {
            $add('facility', ['title' => $title, 'subtitle' => $sub, 'location' => $where, 'tags' => $tags], [[...$person(), 'Parisar volunteer', true]]);
        }

        // Paryatan: places to visit around Hyderabad.
        $tourist = [
            ['Bhagyalakshmi Temple, Charminar', 'Temple beside the Charminar, in the old city', 17.3616, 78.4747, 'Best visited early morning'],
            ['Birla Mandir', 'White marble temple of Sri Venkateswara on Naubat Pahad', 17.4062, 78.4691, 'Open 7 AM – 12 PM, 2 – 9 PM'],
            ['Yadadri Sri Lakshmi Narasimha Swamy Temple', 'Hill temple at Yadagirigutta, about 60 km away', 17.5891, 78.9437, 'Plan half a day'],
            ['Golconda Fort', 'Hill fort with a sound and light show', 17.3833, 78.4011, '9 AM – 5:30 PM'],
            ['Salar Jung Museum', 'One of India\'s largest museums', 17.3713, 78.4804, 'Closed on Fridays'],
        ];
        foreach ($tourist as $k => [$title, $sub, $lat, $lng, $time]) {
            $add('tourist', ['title' => $title, 'subtitle' => $sub, 'lat' => $lat, 'lng' => $lng, 'timings' => $time,
                'description' => 'Go in a group and tell your Nivas lead before you leave. Be back before the evening session.'], [], 2);
        }

        // Apatkal: the national numbers, then each hall with its emergency lead members.
        foreach ([['Ambulance', 'National emergency ambulance', '108'], ['Police / any emergency', 'All-in-one emergency number', '112'], ['Women helpline', 'Women in distress', '181']] as [$title, $sub, $number]) {
            $add('emergency', ['title' => $title, 'subtitle' => $sub, 'color' => '#C92A2A'], [[$title, $number, 'Call', true]]);
        }
        $halls = [
            ['Medical team', 'Medical room · behind Hall A', 'Doctor and two nurses on duty day and night; the ambulance waits at Gate 4', 3],
            ['Main stage', 'Hall A', 'First-aid kit and stretcher at the left wing of the stage', 2],
            ['Food court', 'Hall B', 'Ask any stall lead; first-aid kit at the Chai & Snacks Kendra', 2],
            ['Pratinidhi Sabha', 'Halls C and D', 'Volunteers in red jackets at every door', 2],
            ['Pradarshini', 'Hall E', 'Help desk at the exhibition entrance', 2],
            ['Nivas blocks', 'Blocks A to G', 'Night duty 10 PM – 6 AM at each block entrance', 3],
            ['Mahila Sahayata (women)', 'Block G and near the main stage', 'Women volunteers only', 2],
        ];
        foreach ($halls as [$title, $hall, $note, $size]) {
            $team = [[...$person(), 'Emergency lead', true]];
            for ($k = 1; $k < $size; $k++) {
                $team[] = [...$person(), $k === 1 ? 'Deputy' : 'First-aid volunteer', false];
            }
            $add('emergency', ['title' => $title, 'location' => $hall, 'landmark' => $note, 'color' => '#C92A2A'], $team);
        }
    }

    private function art(string $dir, int $seed): string
    {
        $palettes = [[[240, 138, 60], [120, 40, 10]], [[59, 74, 140], [15, 18, 38]], [[47, 143, 107], [11, 36, 28]], [[156, 79, 184], [30, 14, 38]], [[227, 98, 12], [40, 26, 18]], [[33, 150, 183], [10, 40, 60]]];
        [$a, $b] = $palettes[$seed % count($palettes)];
        $w = 1200;
        $h = 800;
        $img = imagecreatetruecolor($w, $h);
        for ($y = 0; $y < $h; $y++) {
            $t = $y / $h;
            imageline($img, 0, $y, $w, $y, imagecolorallocate($img, (int) ($a[0] + ($b[0] - $a[0]) * $t), (int) ($a[1] + ($b[1] - $a[1]) * $t), (int) ($a[2] + ($b[2] - $a[2]) * $t)));
        }
        mt_srand($seed * 7919);
        for ($i = 0; $i < 7; $i++) {
            $r = mt_rand(80, 420);
            imagefilledellipse($img, mt_rand(0, $w), mt_rand(0, $h), $r, $r, imagecolorallocatealpha($img, 255, 255, 255, mt_rand(96, 120)));
        }
        ob_start();
        imagejpeg($img, null, 82);
        $path = $dir.'/'.Str::uuid().'.jpg';
        Storage::disk(config('abvp.media_disk'))->put($path, ob_get_clean());
        imagedestroy($img);

        return $path;
    }

    /** Community posts with photos, hashtags, likes, replies, follows, and one reported post; covers for events. */
    private function feed($members): void
    {
        $disk = config('abvp.media_disk');
        $palettes = [[[240, 138, 60], [120, 40, 10]], [[59, 74, 140], [15, 18, 38]], [[47, 143, 107], [11, 36, 28]], [[156, 79, 184], [30, 14, 38]], [[227, 98, 12], [40, 26, 18]]];
        $image = function (string $dir, int $seed) use ($disk, $palettes): string {
            [$a, $b] = $palettes[$seed % count($palettes)];
            $w = 1200;
            $h = 800;
            $img = imagecreatetruecolor($w, $h);
            for ($y = 0; $y < $h; $y++) {
                $t = $y / $h;
                $c = imagecolorallocate($img, (int) ($a[0] + ($b[0] - $a[0]) * $t), (int) ($a[1] + ($b[1] - $a[1]) * $t), (int) ($a[2] + ($b[2] - $a[2]) * $t));
                imageline($img, 0, $y, $w, $y, $c);
            }
            mt_srand($seed * 7919);
            for ($i = 0; $i < 7; $i++) {
                $col = imagecolorallocatealpha($img, 255, 255, 255, mt_rand(96, 120));
                $r = mt_rand(80, 420);
                imagefilledellipse($img, mt_rand(0, $w), mt_rand(0, $h), $r, $r, $col);
            }
            ob_start();
            imagejpeg($img, null, 82);
            $path = $dir.'/'.Str::uuid().'.jpg';
            Storage::disk($disk)->put($path, ob_get_clean());
            imagedestroy($img);

            return $path;
        };

        foreach (Event::orderBy('id')->get() as $i => $event) {
            if ($i % 3 !== 1) { // leave one on the gradient fallback
                $event->forceFill(['cover_path' => $image('events/covers', $i + 3)])->save();
            }
        }

        $lines = [
            ['Sadasyata abhiyan at Arts College today – 46 new members signed up before lunch. Thank you to every karyakarta who stood at the gate since 8 AM! #SadasyataAbhiyan #OU', 2],
            ['Blood donation camp with NSS at Kakatiya University: 112 units collected. #SevaHiSangathan', 3],
            ['Preparations for the Pranth Adhiveshan are in full swing. Volunteers, please check your duties in the app before tomorrow. #Adhiveshan2026', 1],
            ['Study circle on the new education policy this Saturday, 5 PM, Keshav Memorial. Bring a friend. #NEP #StudyCircle', 0],
            ['Swachh campus drive done at Nizam College. Small work, big change. #SwachhCampus', 2],
            ['Reminder: membership renewals for this year close on the 30th. Ask your Ikai Mantri if you need help.', 0],
            ['Our Kala Manch team rehearsing for the cultural evening at the Adhiveshan. 🎶 #Adhiveshan2026 #KalaManch', 4],
            ['Tree plantation along the Hanamkonda bypass with SFD – 300 saplings. #SFD #Paryavaran', 3],
            ['Visited the girls hostel at Kukatpally to hear their concerns about the bus timings. Taking it to the principal on Monday. #CampusIssues', 0],
            ['Great discussion at the Think India session on startups and rural innovation. #ThinkIndia', 1],
        ];
        $authors = $members->take(40)->values();
        $posts = [];
        foreach ($lines as $i => [$body, $photos]) {
            $author = $authors[($i * 7) % $authors->count()];
            $post = Post::create([
                'user_id' => $author->id, 'body' => $body, 'audience' => 'members',
                'photos' => $photos ? collect(range(1, $photos))->map(fn ($k) => $image('posts/demo', $i * 5 + $k))->all() : null,
            ]);
            $post->forceFill(['created_at' => now()->subHours(3 + $i * 9 + mt_rand(0, 5))])->save();
            foreach (Post::extractTags($body) as $tag) {
                DB::table('post_tags')->insert(['post_id' => $post->id, 'tag' => $tag, 'created_at' => $post->created_at]);
            }
            foreach ($members->random(mt_rand(4, 30)) as $fan) {
                DB::table('post_likes')->insertOrIgnore(['post_id' => $post->id, 'user_id' => $fan->id, 'created_at' => now()]);
            }
            $posts[] = $post;
        }
        $replies = ['Proud of the team! 🙌', 'Count me in for the next one.', 'Please share the photos in the Vibhag group as well.', 'Well organised, bhaiya.', 'Which time should we report?'];
        foreach ($posts as $i => $post) {
            foreach (range(0, $i % 4) as $k) {
                PostComment::create(['post_id' => $post->id, 'user_id' => $members[($i + $k * 11 + 3) % $members->count()]->id, 'body' => $replies[($i + $k) % count($replies)]]);
            }
        }
        // A repost and a quote.
        Post::create(['user_id' => $authors[5]->id, 'audience' => 'members', 'repost_of_id' => $posts[1]->id]);
        Post::create(['user_id' => $authors[9]->id, 'audience' => 'members', 'repost_of_id' => $posts[0]->id, 'body' => 'This is how it is done. Next week, Secunderabad! #SadasyataAbhiyan']);

        // A post several members reported, waiting for review.
        $bad = Post::create(['user_id' => $authors[21]->id, 'audience' => 'members', 'body' => 'Selling used textbooks cheap, call 98xxxxxx12 – DM for price list!!!']);
        foreach ($members->slice(50, 3) as $r) {
            DB::table('post_reports')->insert(['post_id' => $bad->id, 'user_id' => $r->id, 'reason' => 'spam', 'note' => null, 'created_at' => now()]);
        }

        foreach (Post::all() as $p) {
            $p->forceFill([
                'likes_count' => DB::table('post_likes')->where('post_id', $p->id)->count(),
                'comments_count' => PostComment::where('post_id', $p->id)->count(),
                'reposts_count' => Post::where('repost_of_id', $p->id)->count(),
                'reports_count' => DB::table('post_reports')->where('post_id', $p->id)->count(),
            ])->save();
        }

        // Everyone follows a few people.
        foreach ($members->take(60) as $i => $m) {
            foreach ($authors->random(4) as $f) {
                if ($f->id !== $m->id) {
                    DB::table('follows')->insertOrIgnore(['follower_id' => $m->id, 'followee_id' => $f->id, 'created_at' => now()]);
                }
            }
        }
    }

    private function person(OrgUnit $unit, Carbon $created, $vibhags, ?string $name = null): User
    {
        $this->n++;
        $woman = mt_rand(1, 100) <= 44;
        $firsts = $woman ? self::WOMEN : self::MEN;
        $name ??= $firsts[mt_rand(0, count($firsts) - 1)].' '.self::LAST[mt_rand(0, count(self::LAST) - 1)];
        $user = User::create(['mobile' => '+9170000'.str_pad((string) $this->n, 5, '0', STR_PAD_LEFT), 'name' => $name]);
        $user->forceFill(['created_at' => $created])->save();
        $p = new MemberProfile([
            'full_name' => $name, 'org_unit_id' => $unit->id,
            'gender' => mt_rand(1, 100) <= 97 ? ($woman ? 'female' : 'male') : null,
            'date_of_birth' => now()->subYears(mt_rand(17, 27))->subDays(mt_rand(0, 360))->toDateString(),
            'institution' => $unit->name, 'study_year' => ['1st', '2nd', '3rd', '4th', 'PG'][mt_rand(0, 4)],
        ]);
        $p->user_id = $user->id;
        $p->membership_status = 'approved';
        $p->approved_at = $created;
        $p->save();
        $user->vibhags()->sync($vibhags->random(mt_rand(1, 2))->pluck('id')->all());

        return $user->load('profile.orgUnit');
    }

    private function event(MembershipApplication $app, ?User $actor, string $action, Carbon $at, ?string $note = null): void
    {
        $e = new ApplicationEvent(['membership_application_id' => $app->id, 'actor_id' => $actor?->id, 'action' => $action, 'note' => $note]);
        $e->created_at = $at;
        $e->save();
    }

    private function events(OrgUnit $state, $members, ?User $admin): void
    {
        $organiser = $admin?->id ?? $members->first()->id;
        $hyd = OrgUnit::where('name', 'Hyderabad')->first();

        // Happening today: arrivals spread across gates over the morning.
        $today = Event::create(['title' => 'Telangana Pranth Adhiveshan 2026', 'category' => 'conference', 'venue' => 'Kakatiya University, Warangal',
            'starts_at' => now()->setTime(3, 0), 'ends_at' => now()->addDay()->setTime(12, 0), 'org_unit_id' => $state->id, 'organiser_id' => $organiser,
            'capacity' => 150, 'instructions' => 'Report at your gate by 8:30 AM. Carry your pass and college ID.', 'contact_name' => 'Srinivas Rao', 'contact_phone' => '9848000000']);
        $today->forceFill(['status' => 'published', 'published_at' => now()->subDays(20)])->save();
        $gates = ['Gate 1', 'Gate 1', 'Gate 2', 'Gate 3', 'Gate 3'];
        foreach ($members->take(90) as $i => $m) {
            $arrived = $i < 61;
            EventRegistration::create(['event_id' => $today->id, 'user_id' => $m->id, 'kind' => 'member', 'status' => 'registered',
                'checked_in_at' => $arrived ? now()->setTime(2, 45)->addMinutes((int) (150 * (mt_rand(0, 1000) / 1000) ** 0.7))->min(now()) : null,
                'gate' => $arrived ? $gates[mt_rand(0, 4)] : null, 'check_in_method' => $arrived ? (mt_rand(1, 10) > 1 ? 'scan' : 'manual') : null, 'created_at' => now()->subDays(mt_rand(1, 18))]);
        }
        foreach ([['Prof. K. Rao', 'Osmania University', true], ['Smt. Lakshmi Devi', 'Telangana Vidya Parishad', true], ['Dr. Suresh', 'NIT Warangal', false]] as $k => [$name, $org, $came]) {
            $g = User::create(['mobile' => '+918900000'.str_pad((string) $k, 3, '0', STR_PAD_LEFT), 'name' => $name]);
            EventRegistration::create(['event_id' => $today->id, 'user_id' => $g->id, 'kind' => 'guest', 'status' => 'registered', 'guest_name' => $name, 'guest_organisation' => $org,
                'invited_by' => $organiser, 'checked_in_at' => $came ? now()->setTime(4, 10 + $k) : null, 'gate' => $came ? 'Guest desk' : null, 'check_in_method' => $came ? 'manual' : null]);
        }
        EventStaff::create(['event_id' => $today->id, 'user_id' => $members[95]->id, 'role' => 'scanner']);
        $this->operations($today, $members, $organiser);
        $this->logistics($today, $members);

        // Upcoming, nearly full, with approvals and a waitlist.
        $soon = Event::create(['title' => 'Campus Sampark Abhiyan', 'category' => 'campaign', 'venue' => 'Arts College, Osmania University',
            'starts_at' => now()->addDays(9)->setTime(3, 30), 'ends_at' => now()->addDays(9)->setTime(10, 30), 'org_unit_id' => $hyd->id, 'organiser_id' => $organiser,
            'capacity' => 40, 'requires_approval' => true, 'registration_closes_at' => now()->addDays(6)]);
        $soon->forceFill(['status' => 'published', 'published_at' => now()->subDays(4)])->save();
        foreach ($members->slice(20, 44)->values() as $i => $m) {
            EventRegistration::create(['event_id' => $soon->id, 'user_id' => $m->id, 'kind' => 'member', 'status' => $i < 34 ? 'registered' : ($i < 40 ? 'pending' : 'waitlisted')]);
        }

        // Finished last month.
        $past = Event::create(['title' => 'Prathmik Abhyas Varg – Hyderabad', 'category' => 'training', 'venue' => 'Keshav Memorial, Narayanaguda',
            'starts_at' => now()->subDays(28)->setTime(3, 30), 'ends_at' => now()->subDays(27)->setTime(11, 30), 'org_unit_id' => $hyd->id, 'organiser_id' => $organiser]);
        $past->forceFill(['status' => 'published', 'published_at' => now()->subDays(45)])->save();
        foreach ($members->slice(5, 50)->values() as $i => $m) {
            $came = mt_rand(1, 100) <= 78;
            EventRegistration::create(['event_id' => $past->id, 'user_id' => $m->id, 'kind' => 'member', 'status' => 'registered',
                'checked_in_at' => $came ? $past->starts_at->copy()->addMinutes(mt_rand(-40, 60)) : null, 'gate' => $came ? 'Main gate' : null, 'check_in_method' => $came ? 'scan' : null]);
        }
    }

    /** Teams, duties in every state, help requests and announcements for today's event. */
    private function operations(Event $event, $members, int $organiser): void
    {
        $people = $members->take(90)->values();
        $start = $event->starts_at->copy();
        $teams = [
            ['Registration desk', 0, 'Gate 1 and Gate 3', 10],
            ['Hospitality', 1, 'Guest lounge, Admin block', 8],
            ['Stage and sound', 2, 'Main stage', 5],
            ['Parking', 3, 'North parking lot', 6],
            ['Food', 4, 'Dining hall B', 7],
        ];
        $statuses = ['done', 'done', 'in_progress', 'in_progress', 'in_progress', 'accepted', 'accepted', 'assigned', 'blocked', 'declined'];
        $blockedNotes = ['Registration desk' => 'Scanner phone battery dead at Gate 3', 'Hospitality' => 'Guest lounge AC not working',
            'Stage and sound' => 'Second microphone not working', 'Parking' => 'Lot is full, cars queuing on the main road', 'Food' => 'Running short of plates at counter 2'];
        $i = 10;
        foreach ($teams as [$name, $leadIdx, $place, $n]) {
            $lead = $people[$leadIdx];
            $team = EventTeam::create(['event_id' => $event->id, 'name' => $name, 'lead_user_id' => $lead->id]);
            EventStaff::firstOrCreate(['event_id' => $event->id, 'user_id' => $lead->id], ['role' => 'scanner']);
            for ($k = 0; $k < $n; $k++, $i++) {
                $status = $statuses[($i * 7 + $k) % count($statuses)];
                EventDuty::create(['event_id' => $event->id, 'team_id' => $team->id, 'assignee_id' => $people[$i % 90]->id,
                    'title' => $name === 'Registration desk' ? 'Pass check' : $name, 'location' => $place,
                    'starts_at' => $start->copy()->addMinutes(-30 + 30 * ($k % 3)), 'ends_at' => $start->copy()->addHours(6),
                    'status' => $status, 'status_note' => $status === 'blocked' ? $blockedNotes[$name] : ($status === 'declined' ? 'I have an exam this morning' : null), 'assigned_by' => $organiser,
                    'responded_at' => $status === 'assigned' ? null : $start->copy()->subDay(), 'completed_at' => $status === 'done' ? now()->subMinutes(20) : null]);
            }
        }

        foreach ([
            ['medical', 'A delegate feels dizzy near Hall B, needs water and a place to sit', 'Hall B entrance', 'open', 12],
            ['food', 'Lunch coupons not given at Gate 2 desk', 'Gate 2', 'in_progress', 35],
            ['stay', 'Room key for Hostel 3, room 14 not working', 'Hostel 3', 'open', 8],
            ['venue', 'Which hall is the Think India session in?', null, 'resolved', 70],
        ] as $j => [$cat, $msg, $loc, $status, $minsAgo]) {
            $h = HelpRequest::create(['event_id' => $event->id, 'raised_by' => $people[40 + $j]->id, 'category' => $cat, 'message' => $msg, 'location' => $loc,
                'status' => $status, 'handled_by' => $status === 'open' ? null : $organiser, 'resolved_at' => $status === 'resolved' ? now()->subMinutes(50) : null]);
            $h->forceFill(['created_at' => now()->subMinutes($minsAgo)])->save();
            if ($status !== 'open') {
                HelpReply::create(['help_request_id' => $h->id, 'user_id' => $organiser, 'body' => $cat === 'venue' ? 'Seminar Hall 2, first floor.' : 'Sending someone from the food team now.']);
            }
        }

        foreach ([['Volunteers: briefing at 8 AM at the main stage', 'All duty holders please be there 15 minutes early.', 'team_only', 64], ['Lunch moved to 1:30 PM', 'Lunch is now at 1:30 PM in Dining hall B.', 'everyone', 157]] as [$t, $b, $aud, $n]) {
            EventAnnouncement::create(['event_id' => $event->id, 'sent_by' => $organiser, 'title' => $t, 'body' => $b, 'audience' => $aud, 'recipients' => $n]);
        }
    }

    /** Stays, travel, meals, buses and two people sharing location for today's event. */
    private function logistics(Event $event, $members): void
    {
        $people = $members->take(90)->values();
        foreach ([['Girls Hostel 3, Kakatiya University', 'female', 'G', 10], ['Boys Hostel 1, Kakatiya University', 'male', 'B', 14]] as [$name, $g, $prefix, $rooms]) {
            $stay = EventStay::create(['event_id' => $event->id, 'name' => $name, 'for_gender' => $g, 'address' => 'Vidyaranyapuri, Hanamkonda']);
            for ($i = 1; $i <= $rooms; $i++) {
                EventRoom::create(['stay_id' => $stay->id, 'name' => "$prefix $i", 'capacity' => 4]);
            }
        }

        $modes = ['train', 'train', 'train', 'bus', 'bus', 'own'];
        $points = ['train' => 'Warangal railway station', 'bus' => 'Hanamkonda bus stand', 'own' => null];
        foreach ($people as $i => $m) {
            if ($i % 7 === 6) {
                continue; // some have not filled travel details
            }
            $mode = $modes[$i % 6];
            EventTravel::create(['event_id' => $event->id, 'user_id' => $m->id, 'mode' => $mode,
                'reference' => $mode === 'train' ? ['12723 Telangana Exp', '17201 Golconda Exp', '12759 Charminar Exp'][$i % 3] : null,
                'arriving_at' => $event->starts_at->copy()->subHours(6)->addMinutes(($i % 12) * 20), 'arrival_point' => $points[$mode],
                'needs_pickup' => $mode !== 'own', 'needs_stay' => $i % 5 !== 0]);
        }
        app(LogisticsService::class)->autoAllocate($event);
        \App\Models\RoomAllocation::where('event_id', $event->id)->orderBy('id')->limit(48)->update(['checked_in_at' => now()->subHours(3)]);

        $bus1 = EventVehicle::create(['event_id' => $event->id, 'name' => 'Bus 1', 'capacity' => 45, 'pickup_point' => 'Warangal station, exit 2', 'departs_at' => $event->starts_at->copy()->subHours(2), 'driver_name' => 'Ramesh', 'driver_phone' => '9876500001']);
        $bus2 = EventVehicle::create(['event_id' => $event->id, 'name' => 'Bus 2', 'capacity' => 30, 'pickup_point' => 'Hanamkonda bus stand', 'departs_at' => $event->starts_at->copy()->subMinutes(90), 'driver_name' => 'Suresh', 'driver_phone' => '9876500002']);
        $train = EventTravel::where('event_id', $event->id)->where('mode', 'train')->pluck('id');
        $bus = EventTravel::where('event_id', $event->id)->where('mode', 'bus')->pluck('id');
        EventTravel::whereIn('id', $train)->update(['vehicle_id' => $bus1->id, 'pickup_status' => 'picked_up', 'picked_up_at' => now()->subHours(4)]);
        EventTravel::whereIn('id', $bus->take(14))->update(['vehicle_id' => $bus2->id, 'pickup_status' => 'picked_up', 'picked_up_at' => now()->subHours(3)]);

        $day = $event->starts_at->copy();
        $meals = [['Day 1 Breakfast', -1, 1, 0.92], ['Day 1 Lunch', 0, 2, 0.38], ['Day 1 Dinner', 9, 2, 0]];
        foreach ($meals as [$name, $offsetH, $len, $share]) {
            $start = now()->addHours($offsetH)->startOfHour();
            $m = MealSession::create(['event_id' => $event->id, 'name' => $name, 'location' => 'Dining hall B', 'starts_at' => $start, 'ends_at' => $start->copy()->addHours($len)]);
            foreach ($people->take((int) round(90 * $share)) as $p) {
                MealServing::create(['meal_session_id' => $m->id, 'user_id' => $p->id, 'counter' => 'Counter '.(($p->id % 3) + 1), 'served_at' => $start->copy()->addMinutes($p->id % 50)->min(now())]);
            }
        }

        foreach ([[$people[60], 'Coming late by bus, stuck near Kazipet', 17.9784, 79.5300], [$people[61], 'Bringing banners from the press', 17.9689, 79.5941]] as [$p, $why, $lat, $lng]) {
            $sess = LocationSession::create(['user_id' => $p->id, 'event_id' => $event->id, 'shared_with' => 'coordinators', 'purpose' => $why, 'expires_at' => now()->addMinutes(50)]);
            LocationPoint::create(['location_session_id' => $sess->id, 'lat' => $lat, 'lng' => $lng, 'accuracy_m' => 30, 'recorded_at' => now()->subMinutes(2)]);
        }
    }
}
