<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\ActivityReport;
use App\Models\ApplicationEvent;
use App\Models\Circular;
use App\Models\MemberProfile;
use App\Models\MembershipApplication as Application;
use App\Models\Meeting;
use App\Models\MeetingInvitee;
use App\Models\OrgUnit;
use App\Models\Vibhag;
use App\Services\AccessControl;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * Analysis for one area (the admin's scope, or any unit inside it) over the last N months.
 * Grouping by month is done in PHP so the same code runs on MySQL and SQLite.
 */
class AnalyticsController extends Controller
{
    public function __invoke(Request $request, AccessControl $access)
    {
        $request->validate([
            'months' => ['nullable', 'integer', 'in:3,6,12'],
            'unit_id' => ['nullable', 'integer', 'exists:org_units,id'],
        ]);
        $user = $request->user();
        $this->authorizeIn('analytics.view');

        $scope = $request->filled('unit_id') ? OrgUnit::find($request->integer('unit_id')) : $access->primaryScope($user);
        if (! $access->canIn($user, 'analytics.view', $scope)) {
            throw new ApiException('FORBIDDEN_SCOPE', 'That area is outside your scope.', 403);
        }

        $months = $request->integer('months', 6);
        $from = now()->startOfMonth()->subMonths($months - 1);
        $to = now();
        $unitIds = OrgUnit::within($scope)->pluck('id');

        $members = fn () => MemberProfile::whereIn('org_unit_id', $unitIds);
        $apps = fn () => Application::whereIn('org_unit_id', $unitIds);
        $meetings = fn () => Meeting::where('kind', 'meeting')->where('status', 'scheduled')->whereIn('org_unit_id', $unitIds);
        $reports = fn () => ActivityReport::whereIn('org_unit_id', $unitIds);

        // Rows for the period, fetched once and reused.
        $newMembers = $members()->where('membership_status', MemberProfile::STATUS_APPROVED)->whereBetween('approved_at', [$from, $to])->get(['org_unit_id', 'approved_at']);
        $received = $apps()->whereBetween('submitted_at', [$from, $to])->get(['id', 'org_unit_id', 'submitted_at']);
        $decided = $apps()->whereIn('status', [Application::APPROVED, Application::REJECTED])->whereBetween('decided_at', [$from, $to])->get(['status', 'submitted_at', 'decided_at']);
        $heldMeetings = $meetings()->whereBetween('starts_at', [$from, $to])->get(['id', 'org_unit_id', 'vibhag_id', 'starts_at']);
        $periodReports = $reports()->whereDate('held_on', '>=', $from->toDateString())->whereDate('held_on', '<=', $to->toDateString())->get(['org_unit_id', 'vibhag_id', 'programme_type', 'held_on', 'participants']);

        $invited = MeetingInvitee::whereIn('meeting_id', $heldMeetings->pluck('id'))->count();
        $attended = MeetingInvitee::whereIn('meeting_id', $heldMeetings->pluck('id'))->whereNotNull('joined_at')->count();

        $circulars = Circular::whereIn('org_unit_id', $unitIds)->whereBetween('published_at', [$from, $to])->withCount('reads')->get(['id', 'audience_size']);
        $audience = $circulars->sum('audience_size');

        $eventRows = \App\Models\Event::whereIn('org_unit_id', $unitIds)->where('status', '!=', 'draft')->where('status', '!=', 'cancelled')
            ->whereBetween('starts_at', [$from, $to])->pluck('id');
        $eventRegs = \App\Models\EventRegistration::whereIn('event_id', $eventRows)->where('status', 'registered');
        $eventRegistered = (clone $eventRegs)->count();
        $eventArrived = (clone $eventRegs)->whereNotNull('checked_in_at')->count();

        $approvedCount = $decided->where('status', Application::APPROVED)->count();
        $decisionDays = $decided->map(fn ($a) => $a->submitted_at ? $a->submitted_at->diffInHours($a->decided_at) / 24 : null)->filter(fn ($d) => $d !== null)->sort()->values();

        $pending = $apps()->where('status', Application::SUBMITTED);
        $leafUnits = OrgUnit::within($scope)->where('type', 'unit')->pluck('id');
        $activeUnits = $reports()->whereIn('org_unit_id', $leafUnits)->whereDate('held_on', '>=', now()->subDays(30))->distinct()->count('org_unit_id');

        return $this->ok([
            'scope' => [
                'id' => $scope->id, 'name' => $scope->name, 'type' => $scope->type, 'label' => $scope->label() ?: $scope->name,
                'parent_id' => $access->canIn($user, 'analytics.view', $scope->parent) ? $scope->parent_id : null,
            ],
            'period' => ['months' => $months, 'from' => $from->toDateString(), 'to' => $to->toDateString()],
            'summary' => [
                'members_total' => $members()->where('membership_status', MemberProfile::STATUS_APPROVED)->count(),
                'members_new' => $newMembers->count(),
                'applications_received' => $received->count(),
                'approval_rate' => $decided->count() ? round($approvedCount / $decided->count() * 100) : null,
                'median_days_to_decision' => $decisionDays->isEmpty() ? null : round($decisionDays[intdiv($decisionDays->count(), 2)], 1),
                'pending_now' => (clone $pending)->count(),
                'pending_over_7_days' => (clone $pending)->where('submitted_at', '<', now()->subDays(7))->count(),
                'meetings_held' => $heldMeetings->where('starts_at', '<=', now())->count(),
                'attendance_rate' => $invited ? round($attended / $invited * 100) : null,
                'circulars_issued' => $circulars->count(),
                'circular_read_rate' => $audience ? round($circulars->sum('reads_count') / $audience * 100) : null,
                'reports_submitted' => $periodReports->count(),
                'participants_reached' => (int) $periodReports->sum('participants'),
                'events_held' => $eventRows->count(),
                'event_registrations' => $eventRegistered,
                'event_turnout' => $eventRegistered ? round($eventArrived / $eventRegistered * 100) : null,
                'units_total' => $leafUnits->count(),
                'units_active_30_days' => $activeUnits,
            ],
            'monthly' => $this->monthly($from, $months, $newMembers, $received, $heldMeetings, $periodReports),
            'funnel' => [
                'received' => $received->count(),
                'approved' => $approvedCount,
                'returned' => ApplicationEvent::whereIn('membership_application_id', $apps()->select('id'))->where('action', 'returned')->whereBetween('created_at', [$from, $to])->count(),
                'rejected' => $decided->where('status', Application::REJECTED)->count(),
                'pending' => (clone $pending)->count(),
            ],
            'units' => $this->unitBreakdown($scope, $from, $to),
            'vibhags' => $this->vibhagBreakdown($unitIds, $heldMeetings, $periodReports),
            'programme_types' => $periodReports->groupBy('programme_type')->map(fn ($g, $k) => [
                'key' => $k, 'label' => ActivityReport::TYPES[$k] ?? $k, 'reports' => $g->count(), 'participants' => (int) $g->sum('participants'),
            ])->sortByDesc('reports')->values(),
            'demographics' => $this->demographics($members()->where('membership_status', MemberProfile::STATUS_APPROVED)->get(['gender', 'date_of_birth', 'study_year'])),
            'reviewers' => $this->reviewers($apps()->select('id'), $from, $to),
        ]);
    }

    private function monthly(Carbon $from, int $months, Collection ...$sets): array
    {
        [$newMembers, $received, $meetings, $reports] = $sets;
        $key = fn ($d) => Carbon::parse($d)->format('Y-m');

        $count = fn (Collection $rows, string $field) => $rows->groupBy(fn ($r) => $key($r->{$field}))->map->count();
        $m = $count($newMembers, 'approved_at');
        $a = $count($received, 'submitted_at');
        $mt = $count($meetings, 'starts_at');
        $r = $count($reports, 'held_on');
        $p = $reports->groupBy(fn ($x) => $key($x->held_on))->map(fn ($g) => (int) $g->sum('participants'));

        return collect(range(0, $months - 1))->map(function ($i) use ($from, $m, $a, $mt, $r, $p) {
            $month = $from->copy()->addMonths($i);
            $k = $month->format('Y-m');

            return [
                'month' => $k,
                'label' => $month->format('M'),
                'new_members' => $m[$k] ?? 0,
                'applications' => $a[$k] ?? 0,
                'meetings' => $mt[$k] ?? 0,
                'reports' => $r[$k] ?? 0,
                'participants' => $p[$k] ?? 0,
            ];
        })->all();
    }

    /** One row per child unit, rolled up from everything beneath it. */
    private function unitBreakdown(OrgUnit $scope, Carbon $from, Carbon $to): array
    {
        $children = OrgUnit::where('parent_id', $scope->id)->orderBy('name')->get();
        $rows = $children->isEmpty() ? collect([$scope]) : $children;

        $subtree = OrgUnit::within($scope)->get(['id', 'path']);
        $owner = $subtree->mapWithKeys(fn ($u) => [$u->id => $rows->first(fn ($r) => str_starts_with($u->path, $r->path))?->id]);
        $ids = $subtree->pluck('id');

        $roll = fn (Collection $byUnit) => $byUnit->groupBy(fn ($v, $unitId) => $owner[$unitId] ?? null)->map(fn ($g) => $g->sum());

        $members = $roll(MemberProfile::whereIn('org_unit_id', $ids)->where('membership_status', 'approved')->selectRaw('org_unit_id, count(*) n')->groupBy('org_unit_id')->pluck('n', 'org_unit_id'));
        $new = $roll(MemberProfile::whereIn('org_unit_id', $ids)->where('membership_status', 'approved')->whereBetween('approved_at', [$from, $to])->selectRaw('org_unit_id, count(*) n')->groupBy('org_unit_id')->pluck('n', 'org_unit_id'));
        $pending = $roll(Application::whereIn('org_unit_id', $ids)->where('status', 'submitted')->selectRaw('org_unit_id, count(*) n')->groupBy('org_unit_id')->pluck('n', 'org_unit_id'));
        $stale = $roll(Application::whereIn('org_unit_id', $ids)->where('status', 'submitted')->where('submitted_at', '<', now()->subDays(7))->selectRaw('org_unit_id, count(*) n')->groupBy('org_unit_id')->pluck('n', 'org_unit_id'));
        $reportRows = ActivityReport::whereIn('org_unit_id', $ids)->whereDate('held_on', '>=', $from->toDateString())->whereDate('held_on', '<=', $to->toDateString())->get(['org_unit_id', 'participants', 'held_on']);
        $reports = $roll($reportRows->groupBy('org_unit_id')->map->count());
        $participants = $roll($reportRows->groupBy('org_unit_id')->map(fn ($g) => $g->sum('participants')));
        $meetings = $roll(Meeting::where('kind', 'meeting')->where('status', 'scheduled')->whereIn('org_unit_id', $ids)->whereBetween('starts_at', [$from, $to])->selectRaw('org_unit_id, count(*) n')->groupBy('org_unit_id')->pluck('n', 'org_unit_id'));
        $lastReport = ActivityReport::whereIn('org_unit_id', $ids)->selectRaw('org_unit_id, max(held_on) d')->groupBy('org_unit_id')->pluck('d', 'org_unit_id')
            ->groupBy(fn ($v, $unitId) => $owner[$unitId] ?? null)->map(fn ($g) => $g->max());

        return $rows->map(function (OrgUnit $u) use ($members, $new, $pending, $stale, $reports, $participants, $meetings, $lastReport) {
            $last = $lastReport[$u->id] ?? null;
            $daysSince = $last ? (int) Carbon::parse($last)->diffInDays(now()) : null;
            $attention = collect([
                ($stale[$u->id] ?? 0) > 0 ? 'Applications waiting over 7 days' : null,
                $daysSince === null ? 'No activity reported yet' : ($daysSince > 30 ? "No activity for $daysSince days" : null),
            ])->filter()->values();

            return [
                'id' => $u->id,
                'name' => $u->name,
                'type' => $u->type,
                'has_children' => $u->children()->exists(),
                'members' => (int) ($members[$u->id] ?? 0),
                'new_members' => (int) ($new[$u->id] ?? 0),
                'pending' => (int) ($pending[$u->id] ?? 0),
                'meetings' => (int) ($meetings[$u->id] ?? 0),
                'reports' => (int) ($reports[$u->id] ?? 0),
                'participants' => (int) ($participants[$u->id] ?? 0),
                'last_report_on' => $last ? Carbon::parse($last)->toDateString() : null,
                'attention' => $attention,
            ];
        })->values()->all();
    }

    private function vibhagBreakdown(Collection $unitIds, Collection $meetings, Collection $reports): array
    {
        $members = MemberProfile::whereIn('org_unit_id', $unitIds)->where('membership_status', 'approved')
            ->join('member_vibhag', 'member_vibhag.user_id', '=', 'member_profiles.user_id')
            ->selectRaw('member_vibhag.vibhag_id, count(*) n')->groupBy('member_vibhag.vibhag_id')->pluck('n', 'vibhag_id');

        return Vibhag::where('is_active', true)->orderBy('sort_order')->get()->map(fn (Vibhag $v) => [
            'id' => $v->id,
            'name' => $v->name,
            'members' => (int) ($members[$v->id] ?? 0),
            'meetings' => $meetings->where('vibhag_id', $v->id)->count(),
            'reports' => $reports->where('vibhag_id', $v->id)->count(),
            'participants' => (int) $reports->where('vibhag_id', $v->id)->sum('participants'),
        ])->sortByDesc('members')->values()->all();
    }

    private function demographics(Collection $profiles): array
    {
        $bands = ['Under 18' => 0, '18–21' => 0, '22–25' => 0, '26 and over' => 0, 'Not given' => 0];
        foreach ($profiles as $p) {
            $age = $p->date_of_birth?->age;
            $band = match (true) {
                $age === null => 'Not given',
                $age < 18 => 'Under 18',
                $age <= 21 => '18–21',
                $age <= 25 => '22–25',
                default => '26 and over',
            };
            $bands[$band]++;
        }

        $gender = ['female' => 0, 'male' => 0, 'other' => 0, 'not_given' => 0];
        foreach ($profiles as $p) {
            $gender[$p->gender ?: 'not_given']++;
        }

        return [
            'gender' => collect($gender)->map(fn ($n, $k) => ['key' => $k, 'label' => ucfirst(str_replace('_', ' ', $k)), 'count' => $n])->values(),
            'age' => collect($bands)->map(fn ($n, $k) => ['label' => $k, 'count' => $n])->values(),
            'study_year' => $profiles->groupBy(fn ($p) => $p->study_year ?: 'Not given')->map->count()->sortDesc()->take(6)
                ->map(fn ($n, $k) => ['label' => (string) $k, 'count' => $n])->values(),
        ];
    }

    /** Who is deciding applications, and how quickly. */
    private function reviewers($appIds, Carbon $from, Carbon $to): array
    {
        $events = ApplicationEvent::whereIn('membership_application_id', $appIds)
            ->whereIn('action', ['approved', 'returned', 'rejected'])
            ->whereBetween('created_at', [$from, $to])
            ->with('actor.profile')
            ->get();

        $submitted = Application::whereIn('id', $events->pluck('membership_application_id'))->pluck('submitted_at', 'id');

        return $events->groupBy('actor_id')->map(function ($g) use ($submitted) {
            $days = $g->map(fn ($e) => isset($submitted[$e->membership_application_id])
                ? Carbon::parse($submitted[$e->membership_application_id])->diffInHours($e->created_at) / 24 : null)->filter();

            return [
                'name' => $g->first()->actor?->profile?->full_name ?? $g->first()->actor?->name,
                'decisions' => $g->count(),
                'approved' => $g->where('action', 'approved')->count(),
                'returned' => $g->where('action', 'returned')->count(),
                'rejected' => $g->where('action', 'rejected')->count(),
                'avg_days' => $days->isEmpty() ? null : round($days->avg(), 1),
            ];
        })->sortByDesc('decisions')->values()->all();
    }
}
