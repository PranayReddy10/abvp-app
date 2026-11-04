<?php

namespace Database\Seeders;

use App\Models\ActivityReport;
use App\Models\ApplicationEvent;
use App\Models\Circular;
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
    private const FIRST = ['Anusha', 'Ravi', 'Kiran', 'Sneha', 'Vamshi', 'Lakshmi', 'Rahul', 'Divya', 'Sai', 'Harika', 'Naveen', 'Pooja', 'Arjun', 'Keerthi', 'Manoj', 'Swathi', 'Teja', 'Bhavana', 'Srikanth', 'Meghana', 'Praveen', 'Sowmya', 'Ajay', 'Nikitha'];

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
        $name ??= self::FIRST[mt_rand(0, count(self::FIRST) - 1)].' '.self::LAST[mt_rand(0, count(self::LAST) - 1)];
        $user = User::create(['mobile' => '+9170000'.str_pad((string) $this->n, 5, '0', STR_PAD_LEFT), 'name' => $name]);
        $user->forceFill(['created_at' => $created])->save();
        $p = new MemberProfile([
            'full_name' => $name, 'org_unit_id' => $unit->id,
            'gender' => mt_rand(1, 100) <= 44 ? 'female' : (mt_rand(1, 100) <= 97 ? 'male' : null),
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
}
