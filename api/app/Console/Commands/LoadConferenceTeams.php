<?php

namespace App\Console\Commands;

use App\Models\Event;
use App\Models\EventTeam;
use App\Models\EventTeamMember;
use App\Services\ConferenceTeams;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Loads the 72nd National Conference volunteer structure (ghats, their heads, departments and
 * department Pramukhs) from the organising sheets. Safe to run again: nothing is duplicated and
 * phone numbers already entered are never touched. Admins add phones in the admin panel.
 */
class LoadConferenceTeams extends Command
{
    protected $signature = 'abvp:load-conference-teams
        {--event= : Event id (defaults to the current national conference)}
        {--keep-details : Do not rename the event or change its dates}';

    protected $description = 'Load the conference ghats, departments and names from the organising sheets';

    /** [ghat, colour, [Pramukh, Saha Pramukh, Palak], [[department, Pramukh…], …]] */
    public const SHEET = [
        ['Karyalaya', '#E3620C', ['Shri A Shyam Kiran', 'Shri Druhan', 'Dr I Uday'], [
            ['Adhiveshan office', 'Gowtham'], ['Vyavasta office', 'Sai Kiran'], ['Central Office', 'Vishwa Teja'],
            ['Sanchalan samiti', 'Amruth'], ['Nimantran', 'Anil, HCU'], ['Printing', 'Sai Teja'],
            ['Anumathi office', 'Vikram, DC'], ['Smaarika', 'Ayush'],
        ]],
        ['Baithak', '#2563C9', ['Shri B Laxman', 'Kum M Sri Varsha', 'Shri K Sailu'], [
            ['Sanchalan samiti', 'Avinash'], ['Prastav samiti', 'Pandu'], ['Kendriya karya samiti', 'Shiva'],
            ['Kendriya Team', 'Deepika'], ['NEC', 'Preetham'], ['Anya baithak', 'Praneeth'],
        ]],
        ['Yatha Yath', '#0E9F8E', ['Shri G Pruthvi Teja', 'Shri M Chatrapathi', 'Shri K Pandu Rangareddy'], [
            ['Welcome', 'Mruthyunjay'], ['Pratinidhi', 'Akhil'], ['Guest', 'Ragavendhra'],
            ['Reservation', 'Vijay Singh'], ['Paryatan', 'Dama Sunil'],
        ]],
        ['Nivas', '#7C4DDB', ['Shri K Harsha', 'Shri Ch Balakrishna', 'Dr N Jana Reddy'], [
            ['Boys', 'Harish Sagar'], ['Girls', 'Kalyani'], ['Central Team', 'Gyaneshwar'], ['Guest & Parivar', 'Pradeep'],
            ['Teachers', 'Parshuram'], ['Sanchalan Samiti', 'Mohan TU'], ['Vyavasta', 'Rajinikanth HCU'], ['Karmachari House', 'Prashant'],
        ]],
        ['Bhojan', '#D97706', ['Shri K Navendra', 'Shri S Adithya', 'Shri A Murali'], [
            ['Apoorthi', 'Shekhar OU'], ['Storeroom', 'Revanth'], ['Kitchen', 'Nandu'],
            ['Distribution', 'Raju'], ['Tea', 'Durga'], ['Leftover food', 'Omesh'],
        ]],
        ['Jala Evam Swachatha', '#0891B2', ['Shri D Malikarjun', 'Shri Krishmani', 'Dr Narender'], [
            ['Water Collection', 'Pavan'], ['Drinking Water', 'Akshay'], ['Cleaning', 'Shankar'], ['Hot Water', 'Praneeth'],
        ]],
        ['Nirmaan', '#92400E', ['Dr Jeevan', 'Shri G Prudvi', 'Shri Srikanth Ramineni'], [
            ['Tent', 'Manikanta'], ['Plumbing', 'Raghavendra'], ['Decoration', 'Sai Pranathi'], ['Flag Host', 'Poojith JNTU'],
        ]],
        ['Karyakram', '#DB2777', ['Shri V Ramakrishna', 'Kum T Neethu Singh', 'Dr T Pratigna'], [
            ['Stage', 'Bhakti HCU'], ['Sabhagar', 'Ajay'], ['Cultural Program', 'Manikanta'], ['State Conference', 'Sujith'],
        ]],
        ['Dvani Evam Prakash', '#CA8A04', ['Shri Arjun', 'Shri Mahesh A', 'Dr P Shyam'], [
            ['Sound', 'Surendar'], ['Lights', 'Gopi'], ['Live stream', 'Sai Harshith'],
        ]],
        ['Prachar Prasar', '#DC2626', ['Shri M Devendar', 'Shri A Raju', ['Shri Rambabu', 'Shri Aswhini']], [
            ['Media', 'Anthariksh'], ['Social Media', 'Sai Teja'], ['City Decoration', 'Ganga Charan'],
            ['Photo & Video', 'Sapthagiri'], ['Stall', 'Naresh Teja'],
        ]],
        ['Adhiveshan Parisar', '#16A34A', ['Shri M Sandeep', 'Kum Siddika', 'Shri Mohan Chary'], [
            ['Medical', 'Jaychandra', 'Sai Vinay'], ['Enquiry', 'Mamatha'], ['Suraksha', 'Vishnu KNR'],
            ['Parking', 'Mahendra'], ['Parisar Sajavat', 'Naresh'],
        ]],
        ['Athidi', '#9333EA', ['Shri A Nikhil', 'Kum J Deepika', 'Dr R Malobika'], [
            ['Guest Room', 'Vinisha'], ['Central Team', 'Anitha'], ['Guest Welcome', 'Mokshith'],
        ]],
        ['Kosh', '#475569', ['Shri Bapu Rao', null, null], [
            ['Accounts'], ['Small Accounts'], ['Vastu Sangraha'], ['Vignapana'],
        ]],
        ['Karyakarta', '#B45309', ['Shri Vishnu Vardhan', 'Shri Rajasekhar', null], [
            ['Vistarak vyavasta', 'Akhil'], ['Reserved force', 'Rajkumar'],
        ]],
        ['Aapoorti', '#0F766E', ['Shri Nagesh', 'Shri Bharat', null], [
            ['Aapoorti Vyavasta'],
        ]],
        ['Pradarshini', '#BE185D', ['Kum Ch Nikitha', 'Shri P Sumanth', 'Dr Karunakar'], [
            ['Pradarshini', 'Shivapriya'],
        ]],
        ['Shobhayathra / Kuladhiveshan', '#C2410C', ['Shri Balakrishna', 'Shri Hariprasad', 'Shri Srihari'], [
            ['Shobhayathra', 'Vinay'], ['Public Speech', 'Shiva (TU)'],
        ]],
    ];

    public function handle(): int
    {
        $event = $this->option('event') ? Event::find($this->option('event')) : ConferenceTeams::current()
            ?? Event::where('category', 'conference')->latest('starts_at')->first();
        if (! $event) {
            $this->error('No conference event found. Create it first: php artisan abvp:setup-conference');

            return self::FAILURE;
        }

        if (! $this->option('keep-details')) {
            $event->forceFill([
                'title' => '72nd National Conference – Bhagyanagar',
                'starts_at' => Carbon::parse('2026-12-24 09:00', 'Asia/Kolkata')->utc(),
                'ends_at' => Carbon::parse('2026-12-27 18:00', 'Asia/Kolkata')->utc(),
            ])->save();
        }

        $added = ['ghats' => 0, 'departments' => 0, 'people' => 0];
        DB::transaction(function () use ($event, &$added) {
            foreach (self::SHEET as $gi => [$ghatName, $color, $heads, $departments]) {
                $ghat = EventTeam::firstOrCreate(
                    ['event_id' => $event->id, 'parent_id' => null, 'name' => $ghatName],
                    ['kind' => 'ghat', 'color' => $color, 'sort' => $gi + 1],
                );
                $ghat->forceFill(['kind' => 'ghat', 'color' => $ghat->color ?? $color])->save();
                $added['ghats'] += (int) $ghat->wasRecentlyCreated;

                foreach (EventTeam::HEAD_ROLES as $ri => $role) {
                    foreach ((array) ($heads[$ri] ?? []) as $name) {
                        $added['people'] += $this->person($ghat, $name, $role, $ri);
                    }
                }
                foreach ($departments as $di => $row) {
                    $dept = EventTeam::firstOrCreate(
                        ['event_id' => $event->id, 'parent_id' => $ghat->id, 'name' => $row[0]],
                        ['kind' => 'department', 'sort' => $di + 1],
                    );
                    $added['departments'] += (int) $dept->wasRecentlyCreated;
                    foreach (array_slice($row, 1) as $pi => $name) {
                        $added['people'] += $this->person($dept, $name, 'pramukh', $pi);
                    }
                }
            }
        });

        $this->info("{$event->title} (event #{$event->id}): added {$added['ghats']} ghats, {$added['departments']} departments, {$added['people']} people.");
        $this->line('Next: admin panel → Conference team → add phone numbers. People are linked as soon as they sign in with that number.');

        return self::SUCCESS;
    }

    private function person(EventTeam $team, ?string $name, string $role, int $sort): int
    {
        if (! $name) {
            return 0;
        }
        $m = EventTeamMember::firstOrCreate(['team_id' => $team->id, 'name' => $name], ['role' => $role, 'sort' => $sort]);

        return (int) $m->wasRecentlyCreated;
    }
}
