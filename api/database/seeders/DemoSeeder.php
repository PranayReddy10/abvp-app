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
use App\Models\User;
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
