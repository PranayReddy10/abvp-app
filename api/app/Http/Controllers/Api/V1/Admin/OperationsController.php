<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\OperationsController as MemberOps;
use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Event;
use App\Models\EventAnnouncement;
use App\Models\EventDuty;
use App\Models\EventStaff;
use App\Models\EventTeam;
use App\Models\HelpRequest;
use App\Models\MemberProfile;
use App\Services\Audit;
use App\Services\DutyPresenter;
use App\Services\EventService;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/** Event-day operations for coordinators: teams, duties, help desk, announcements. */
class OperationsController extends Controller
{
    public function __construct(private EventService $events) {}

    // ---- Teams ---------------------------------------------------------------

    public function teams(Request $request, Event $event)
    {
        $this->guard($request, $event);
        $teams = EventTeam::where('event_id', $event->id)->with('lead.profile')->withCount([
            'duties as duties_count' => fn ($q) => $q->where('status', '!=', 'cancelled'),
            'duties as done_count' => fn ($q) => $q->where('status', 'done'),
            'duties as problem_count' => fn ($q) => $q->whereIn('status', ['blocked', 'declined']),
        ])->orderBy('name')->get();

        return $this->ok($teams->map(fn ($t) => [
            'id' => $t->id, 'name' => $t->name, 'description' => $t->description,
            'lead' => $t->lead ? ['name' => $t->lead->profile?->full_name, 'member_id' => $t->lead->profile?->member_id] : null,
            'duties' => $t->duties_count, 'done' => $t->done_count, 'problems' => $t->problem_count,
        ]));
    }

    public function storeTeam(Request $request, Event $event)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:80', Rule::unique('event_teams')->where('event_id', $event->id)],
            'description' => ['nullable', 'string', 'max:500'],
            'lead_member_id' => ['nullable', 'string', 'exists:member_profiles,member_id'],
        ]);
        $this->guard($request, $event);

        $lead = isset($data['lead_member_id']) ? MemberProfile::where('member_id', $data['lead_member_id'])->value('user_id') : null;
        $team = EventTeam::create(['event_id' => $event->id, 'name' => $data['name'], 'description' => $data['description'] ?? null, 'lead_user_id' => $lead]);
        if ($lead) {
            // Team leads can see their team and update duties from the app.
            EventStaff::firstOrCreate(['event_id' => $event->id, 'user_id' => $lead], ['role' => 'scanner']);
            AppNotification::sendMany([$lead], 'team_lead', "You lead {$team->name}", $event->title, ['event_id' => $event->id]);
        }

        return $this->ok(['id' => $team->id], 201);
    }

    public function deleteTeam(Request $request, Event $event, EventTeam $team)
    {
        $this->guard($request, $event);
        abort_unless($team->event_id === $event->id, 404);
        $team->delete();

        return $this->ok(['deleted' => true]);
    }

    // ---- Duties --------------------------------------------------------------

    public function duties(Request $request, Event $event)
    {
        $this->guard($request, $event);
        $request->validate(['team_id' => ['nullable', 'integer'], 'status' => ['nullable', 'string']]);

        $duties = EventDuty::where('event_id', $event->id)
            ->when($request->input('team_id'), fn ($q, $t) => $q->where('team_id', $t))
            ->when($request->input('status'), fn ($q, $s) => $s === 'problems' ? $q->whereIn('status', ['blocked', 'declined']) : $q->where('status', $s))
            ->with('team.lead.profile', 'assignee.profile', 'reportingTo.profile')
            ->orderBy('starts_at')->orderBy('team_id')->get();

        $counts = EventDuty::where('event_id', $event->id)->selectRaw('status, count(*) n')->groupBy('status')->pluck('n', 'status');

        return $this->ok($duties->map(fn ($d) => DutyPresenter::present($d) + ['assignee_phone' => $d->assignee?->mobile]), meta: ['counts' => $counts]);
    }

    /**
     * Give one duty to one or many people. Clashes with their other duties are
     * reported first; send again with force=true to assign anyway.
     */
    public function assign(Request $request, Event $event)
    {
        $data = $this->validateDuty($request);
        $data += $request->validate([
            'member_ids' => ['required', 'array', 'min:1', 'max:200'],
            'member_ids.*' => ['string', 'exists:member_profiles,member_id'],
            'force' => ['sometimes', 'boolean'],
        ]);
        $this->guard($request, $event);

        $people = MemberProfile::whereIn('member_id', $data['member_ids'])->with('user')->get();
        $allowed = $this->events->participantIds($event);
        $outsiders = $people->reject(fn ($p) => $allowed->contains($p->user_id));
        if ($outsiders->isNotEmpty()) {
            throw new ApiException('NOT_PARTICIPANT', 'Not registered for this event or on its team: '.$outsiders->pluck('full_name')->implode(', ').'.', 422);
        }

        $clashes = $this->clashes($people->pluck('user_id'), $data['starts_at'], $data['ends_at']);
        if ($clashes->isNotEmpty() && ! $request->boolean('force')) {
            return response()->json([
                'success' => false,
                'error' => ['code' => 'DUTY_CLASH', 'message' => 'Some people already have a duty at that time. Assign anyway, or choose others.'],
                'clashes' => $clashes,
                'meta' => ['request_id' => $request->attributes->get('request_id')],
            ], 409);
        }

        $team = isset($data['team_id']) ? EventTeam::where('event_id', $event->id)->findOrFail($data['team_id']) : null;
        $created = DB::transaction(fn () => $people->map(fn ($p) => EventDuty::create(collect($data)->except(['member_ids', 'force', 'reporting_member_id'])->all() + [
            'event_id' => $event->id,
            'assignee_id' => $p->user_id,
            'reporting_user_id' => $this->reportingId($data) ?? $team?->lead_user_id,
            'assigned_by' => $request->user()->id,
            'status' => 'assigned',
        ])));

        $when = $data['starts_at']->copy()->timezone('Asia/Kolkata')->format('D j M, g:i A');
        AppNotification::sendMany($people->pluck('user_id'), 'duty_assigned', "New duty: {$data['title']}", "$when · ".($data['location'] ?? $event->venue).' · please accept', ['event_id' => $event->id]);
        Audit::record('duty.assigned', $event, null, ['title' => $data['title'], 'people' => $people->count()]);

        return $this->ok(['created' => $created->count(), 'clashes_ignored' => $clashes->count()], 201);
    }

    /** Edit or reassign. Reassigning tells both people. */
    public function updateDuty(Request $request, Event $event, EventDuty $duty)
    {
        abort_unless($duty->event_id === $event->id, 404);
        $this->guard($request, $event);
        $data = $this->validateDuty($request, partial: true);
        $data += $request->validate(['member_id' => ['sometimes', 'string', 'exists:member_profiles,member_id']]);

        if (isset($data['member_id'])) {
            $newId = MemberProfile::where('member_id', $data['member_id'])->value('user_id');
            if (! $this->events->participantIds($event)->contains($newId)) {
                throw new ApiException('NOT_PARTICIPANT', 'That person is not registered for this event or on its team.', 422);
            }
            if ($newId !== $duty->assignee_id) {
                AppNotification::sendMany([$duty->assignee_id], 'duty_removed', "Duty moved to someone else: {$duty->title}", null, ['event_id' => $event->id]);
                AppNotification::sendMany([$newId], 'duty_assigned', "New duty: {$duty->title}", 'Please accept in the app.', ['event_id' => $event->id]);
                $data['assignee_id'] = $newId;
                $data['status'] = 'assigned';
                $data['status_note'] = null;
                $data['responded_at'] = null;
            }
        }
        if (array_key_exists('reporting_member_id', $data)) {
            $data['reporting_user_id'] = $this->reportingId($data);
        }

        $duty->update(collect($data)->except(['member_id', 'reporting_member_id'])->all());

        return $this->ok(DutyPresenter::present($duty->fresh(['team.lead.profile', 'assignee.profile', 'reportingTo.profile'])));
    }

    public function cancelDuty(Request $request, Event $event, EventDuty $duty)
    {
        abort_unless($duty->event_id === $event->id, 404);
        $this->guard($request, $event);
        $duty->update(['status' => 'cancelled']);
        AppNotification::sendMany([$duty->assignee_id], 'duty_removed', "Duty cancelled: {$duty->title}", null, ['event_id' => $event->id]);

        return $this->ok(['cancelled' => true]);
    }

    // ---- Help desk -----------------------------------------------------------

    public function help(Request $request, Event $event)
    {
        $this->guard($request, $event);
        $rows = HelpRequest::where('event_id', $event->id)
            ->when($request->input('status'), fn ($q, $s) => $q->where('status', $s))
            ->with('replies.user.profile', 'raiser.profile', 'event')
            ->orderByRaw("CASE status WHEN 'open' THEN 0 WHEN 'in_progress' THEN 1 ELSE 2 END")
            ->orderByRaw("CASE category WHEN 'medical' THEN 0 ELSE 1 END")
            ->latest('id')->limit(200)->get();

        return $this->ok($rows->map(fn ($h) => MemberOps::presentHelp($h) + [
            'raiser_mobile' => $h->raiser?->mobile,
            'waiting_minutes' => $h->status === 'resolved' ? null : (int) $h->created_at->diffInMinutes(now()),
        ]));
    }

    public function updateHelp(Request $request, Event $event, HelpRequest $help)
    {
        abort_unless($help->event_id === $event->id, 404);
        $data = $request->validate(['status' => ['required', 'in:open,in_progress,resolved']]);
        $this->guard($request, $event);

        $help->update(['status' => $data['status'], 'handled_by' => $help->handled_by ?? $request->user()->id, 'resolved_at' => $data['status'] === 'resolved' ? now() : null]);
        if ($data['status'] === 'resolved') {
            AppNotification::sendMany([$help->raised_by], 'help_resolved', 'Your help request is marked resolved', 'Reply in the app if you still need help.', ['event_id' => $event->id, 'help_id' => $help->id]);
        }

        return $this->ok(['status' => $help->status]);
    }

    // ---- Announcements -------------------------------------------------------

    public function announcements(Request $request, Event $event)
    {
        $this->guard($request, $event);

        return $this->ok(EventAnnouncement::where('event_id', $event->id)->with('sender.profile')->latest('id')->get()->map(fn ($a) => [
            'id' => $a->id, 'title' => $a->title, 'body' => $a->body, 'audience' => $a->audience, 'recipients' => $a->recipients,
            'sent_by' => $a->sender?->profile?->full_name, 'at' => $a->created_at->toIso8601String(),
        ]));
    }

    public function announce(Request $request, Event $event)
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'max:160'],
            'body' => ['required', 'string', 'max:2000'],
            'audience' => ['required', 'in:everyone,team_only'],
        ]);
        $this->guard($request, $event);

        $team = EventDuty::where('event_id', $event->id)->where('status', '!=', 'cancelled')->pluck('assignee_id')
            ->merge(EventStaff::where('event_id', $event->id)->pluck('user_id'));
        $ids = ($data['audience'] === 'everyone' ? $this->events->participantIds($event)->merge($team) : $team)->unique()->values();

        $a = EventAnnouncement::create($data + ['event_id' => $event->id, 'sent_by' => $request->user()->id, 'recipients' => $ids->count()]);
        AppNotification::sendMany($ids, 'event_announcement', $data['title'], $data['body'], ['event_id' => $event->id]);

        return $this->ok(['id' => $a->id, 'recipients' => $ids->count()], 201);
    }

    // ---- Helpers -------------------------------------------------------------

    private function validateDuty(Request $request, bool $partial = false): array
    {
        $req = $partial ? 'sometimes' : 'required';
        $data = $request->validate([
            'title' => [$req, 'string', 'max:160'],
            'instructions' => ['nullable', 'string', 'max:2000'],
            'location' => ['nullable', 'string', 'max:160'],
            'starts_at' => [$req, 'date'],
            'ends_at' => [$req, 'date', 'after:starts_at'],
            'team_id' => ['nullable', 'integer', 'exists:event_teams,id'],
            'reporting_member_id' => ['nullable', 'string', 'exists:member_profiles,member_id'],
        ]);
        foreach (['starts_at', 'ends_at'] as $k) {
            if (! empty($data[$k])) {
                $data[$k] = Carbon::parse($data[$k])->utc();
            }
        }

        return $data;
    }

    private function reportingId(array $data): ?int
    {
        return empty($data['reporting_member_id']) ? null : MemberProfile::where('member_id', $data['reporting_member_id'])->value('user_id');
    }

    /** Open duties (any event) that overlap the given time for these people. */
    private function clashes($userIds, Carbon $start, Carbon $end)
    {
        return EventDuty::whereIn('assignee_id', $userIds)->whereIn('status', EventDuty::OPEN)
            ->where('starts_at', '<', $end)->where('ends_at', '>', $start)
            ->with('assignee.profile', 'event')->get()
            ->map(fn ($d) => [
                'name' => $d->assignee?->profile?->full_name,
                'member_id' => $d->assignee?->profile?->member_id,
                'duty' => $d->title,
                'event' => $d->event->title,
                'starts_at' => $d->starts_at->toIso8601String(),
                'ends_at' => $d->ends_at->toIso8601String(),
            ])->values();
    }

    private function guard(Request $request, Event $event): void
    {
        if (! $this->events->canCoordinate($request->user(), $event)) {
            throw new ApiException('FORBIDDEN_SCOPE', 'Only coordinators of this event can do this.', 403);
        }
    }
}
