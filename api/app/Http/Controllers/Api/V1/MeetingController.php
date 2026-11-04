<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ActionItem;
use App\Models\AppNotification;
use App\Models\MemberProfile;
use App\Models\Meeting;
use App\Models\MeetingInvitee;
use App\Models\OrgUnit;
use App\Models\User;
use App\Services\AccessControl;
use App\Services\Audit;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/** Baithaks and one-to-one calls. The video happens on Meet/Zoom; we hold the link. */
class MeetingController extends Controller
{
    public function __construct(private AccessControl $access) {}

    public function index(Request $request)
    {
        $request->validate(['when' => ['nullable', 'in:upcoming,past']]);
        $user = $request->user();
        $upcoming = $request->input('when', 'upcoming') === 'upcoming';

        $meetings = Meeting::where(fn ($q) => $q->where('organiser_id', $user->id)
            ->orWhereIn('id', MeetingInvitee::where('user_id', $user->id)->select('meeting_id')))
            ->when($upcoming, fn ($q) => $q->where('ends_at', '>=', now())->orderBy('starts_at'),
                fn ($q) => $q->where('ends_at', '<', now())->orderByDesc('starts_at'))
            ->with('organiser.profile', 'vibhag')
            ->limit(50)
            ->get();

        $mine = MeetingInvitee::where('user_id', $user->id)->whereIn('meeting_id', $meetings->pluck('id'))->get()->keyBy('meeting_id');

        return $this->ok($meetings->map(fn (Meeting $m) => $this->summary($m, $user, $mine->get($m->id))));
    }

    public function store(Request $request)
    {
        $user = $request->user();
        if (! $user->isApprovedMember()) {
            throw new ApiException('NOT_A_MEMBER', 'Scheduling is available after your membership is approved.', 403);
        }

        $data = $request->validate([
            'kind' => ['required', 'in:meeting,call'],
            'title' => ['required', 'string', 'max:160'],
            'agenda' => ['nullable', 'string', 'max:3000'],
            'mode' => ['required', 'in:online,in_person,hybrid'],
            'link' => ['nullable', 'required_unless:mode,in_person', 'url:https', 'max:500'],
            'venue' => ['nullable', 'required_unless:mode,online', 'string', 'max:200'],
            'starts_at' => ['required', 'date', 'after:now'],
            'ends_at' => ['required', 'date', 'after:starts_at'],
            'org_unit_id' => ['nullable', 'required_if:kind,meeting', 'integer', 'exists:org_units,id'],
            'vibhag_id' => ['nullable', 'integer', Rule::exists('vibhags', 'id')],
            'member_ids' => ['nullable', 'array', 'max:50'],
            'member_ids.*' => ['string', 'exists:member_profiles,member_id'],
        ]);

        // Store in UTC whatever offset the phone sent (India sends +05:30).
        $data['starts_at'] = Carbon::parse($data['starts_at'])->utc();
        $data['ends_at'] = Carbon::parse($data['ends_at'])->utc();

        if ($data['kind'] === 'call') {
            if (count($data['member_ids'] ?? []) !== 1) {
                throw new ApiException('ONE_PERSON_CALL', 'A call is with exactly one member. Choose who to call.');
            }
            $data['org_unit_id'] = null;
            $data['vibhag_id'] = null;
        } else {
            $unit = OrgUnit::find($data['org_unit_id']);
            if (! $this->access->canInFor($user, 'meetings.schedule', $unit, $data['vibhag_id'] ?? null)) {
                throw new ApiException('FORBIDDEN_SCOPE', 'You can only call meetings for your own area and Vibhag.', 403);
            }
        }

        $meeting = DB::transaction(function () use ($data, $user) {
            $meeting = Meeting::create(collect($data)->except('member_ids')->all() + [
                'organiser_id' => $user->id,
                'provider' => Meeting::providerFor($data['link'] ?? null),
            ]);

            $ids = $this->resolveInvitees($meeting, $data['member_ids'] ?? [])->reject(fn ($id) => $id === $user->id)->values();
            $now = now();
            $ids->chunk(500)->each(fn ($chunk) => MeetingInvitee::insert($chunk->map(fn ($id) => [
                'meeting_id' => $meeting->id, 'user_id' => $id, 'rsvp' => 'pending', 'created_at' => $now, 'updated_at' => $now,
            ])->all()));

            $who = $user->profile->full_name;
            AppNotification::sendMany($ids, $meeting->kind === 'call' ? 'call_request' : 'meeting_invite',
                $meeting->kind === 'call' ? "$who wants a call" : $meeting->title,
                $meeting->starts_at->timezone('Asia/Kolkata')->format('D j M, g:i A').($meeting->kind === 'call' ? ' · '.$meeting->title : " · called by $who"),
                ['meeting_id' => $meeting->id]);

            return $meeting;
        });

        Audit::record('meeting.scheduled', $meeting, null, ['invitees' => $meeting->invitees()->count()]);

        return $this->ok($this->detail($meeting, $user), 201);
    }

    public function show(Request $request, Meeting $meeting)
    {
        $this->guardInvolved($request->user(), $meeting);

        return $this->ok($this->detail($meeting, $request->user()));
    }

    public function rsvp(Request $request, Meeting $meeting)
    {
        $data = $request->validate([
            'rsvp' => ['required', 'in:going,maybe,no'],
            'note' => ['nullable', 'string', 'max:300'],
        ]);
        $invite = $this->inviteFor($request->user(), $meeting);
        $invite->update(['rsvp' => $data['rsvp'], 'rsvp_note' => $data['note'] ?? null]);

        if ($meeting->kind === 'call') {
            $name = $request->user()->profile?->full_name;
            $msg = match ($data['rsvp']) { 'going' => "$name accepted your call", 'no' => "$name can't make the call", default => "$name might join the call" };
            AppNotification::sendMany([$meeting->organiser_id], 'call_reply', $msg, $data['note'] ?? null, ['meeting_id' => $meeting->id]);
        }

        return $this->ok($this->detail($meeting, $request->user()));
    }

    /** Records attendance and hands back the link to open. */
    public function join(Request $request, Meeting $meeting)
    {
        $user = $request->user();
        $this->guardInvolved($user, $meeting);

        if ($meeting->status === 'cancelled') {
            throw new ApiException('MEETING_CANCELLED', 'This meeting was cancelled.');
        }
        if (now()->lt($meeting->starts_at->copy()->subMinutes(15))) {
            throw new ApiException('TOO_EARLY', 'You can join from 15 minutes before the start.');
        }

        MeetingInvitee::where('meeting_id', $meeting->id)->where('user_id', $user->id)->whereNull('joined_at')
            ->update(['joined_at' => now(), 'rsvp' => DB::raw("CASE WHEN rsvp = 'pending' THEN 'going' ELSE rsvp END")]);

        return $this->ok(['link' => $meeting->link, 'provider' => $meeting->provider]);
    }

    public function cancel(Request $request, Meeting $meeting)
    {
        $this->guardOrganiser($request->user(), $meeting);
        $meeting->update(['status' => 'cancelled']);

        AppNotification::sendMany($meeting->invitees()->pluck('user_id'), 'meeting_cancelled', "Cancelled: {$meeting->title}",
            $meeting->starts_at->timezone('Asia/Kolkata')->format('D j M, g:i A'), ['meeting_id' => $meeting->id]);
        Audit::record('meeting.cancelled', $meeting);

        return $this->ok($this->detail($meeting, $request->user()));
    }

    /** Minutes and action items, after the meeting. Assignees see items on their Home. */
    public function minutes(Request $request, Meeting $meeting)
    {
        $this->guardOrganiser($request->user(), $meeting);
        $data = $request->validate([
            'minutes' => ['nullable', 'string', 'max:10000'],
            'action_items' => ['nullable', 'array', 'max:30'],
            'action_items.*.title' => ['required', 'string', 'max:200'],
            'action_items.*.member_id' => ['required', 'string', 'exists:member_profiles,member_id'],
            'action_items.*.due_on' => ['nullable', 'date'],
        ]);

        DB::transaction(function () use ($meeting, $data) {
            $meeting->update(['minutes' => $data['minutes'] ?? $meeting->minutes]);

            foreach ($data['action_items'] ?? [] as $item) {
                $assignee = MemberProfile::where('member_id', $item['member_id'])->value('user_id');
                ActionItem::create(['meeting_id' => $meeting->id, 'assignee_id' => $assignee, 'title' => $item['title'], 'due_on' => $item['due_on'] ?? null]);
                AppNotification::sendMany([$assignee], 'action_item', 'New action item: '.$item['title'], 'From '.$meeting->title, ['meeting_id' => $meeting->id]);
            }
        });

        return $this->ok($this->detail($meeting, $request->user()));
    }

    /** Calendar file so members can add the meeting to Google Calendar or any calendar app. */
    public function ics(Request $request, Meeting $meeting)
    {
        $this->guardInvolved($request->user(), $meeting);
        $fmt = fn (Carbon $d) => $d->copy()->utc()->format('Ymd\THis\Z');
        $esc = fn (?string $s) => str_replace(["\\", ';', ',', "\n"], ['\\\\', '\;', '\,', '\n'], (string) $s);

        $body = implode("\r\n", array_filter([
            'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//ABVP Connect//EN', 'BEGIN:VEVENT',
            'UID:meeting-'.$meeting->id.'@abvpconnect.in',
            'DTSTAMP:'.$fmt(now()),
            'DTSTART:'.$fmt($meeting->starts_at),
            'DTEND:'.$fmt($meeting->ends_at),
            'SUMMARY:'.$esc($meeting->title),
            'DESCRIPTION:'.$esc(trim(($meeting->agenda ?? '')."\n".($meeting->link ?? ''))),
            $meeting->venue || $meeting->link ? 'LOCATION:'.$esc($meeting->venue ?: $meeting->link) : null,
            $meeting->status === 'cancelled' ? 'STATUS:CANCELLED' : null,
            'END:VEVENT', 'END:VCALENDAR',
        ]))."\r\n";

        return response($body, 200, [
            'Content-Type' => 'text/calendar; charset=utf-8',
            'Content-Disposition' => 'attachment; filename="meeting-'.$meeting->id.'.ics"',
        ]);
    }

    public function myActionItems(Request $request)
    {
        $items = ActionItem::where('assignee_id', $request->user()->id)
            ->where(fn ($q) => $q->whereNull('done_at')->orWhere('done_at', '>=', now()->subDays(7)))
            ->with('meeting')
            ->orderByRaw('done_at is not null')->orderBy('due_on')
            ->get();

        return $this->ok($items->map(fn (ActionItem $a) => [
            'id' => $a->id,
            'title' => $a->title,
            'due_on' => $a->due_on?->toDateString(),
            'done' => $a->done_at !== null,
            'overdue' => ! $a->done_at && $a->due_on?->isPast() && ! $a->due_on->isToday(),
            'meeting' => ['id' => $a->meeting->id, 'title' => $a->meeting->title],
        ]));
    }

    public function completeActionItem(Request $request, ActionItem $actionItem)
    {
        if ($actionItem->assignee_id !== $request->user()->id && $actionItem->meeting->organiser_id !== $request->user()->id) {
            throw new ApiException('FORBIDDEN', 'Only the assignee or organiser can update this item.', 403);
        }
        $actionItem->update(['done_at' => $request->boolean('done', true) ? now() : null]);

        return $this->ok(['done' => $actionItem->done_at !== null]);
    }

    /** Everyone the meeting is for: the audience (unit + optional Vibhag) plus named members. */
    private function resolveInvitees(Meeting $meeting, array $memberIds)
    {
        $ids = collect();

        if ($meeting->org_unit_id) {
            $q = MemberProfile::where('membership_status', MemberProfile::STATUS_APPROVED)
                ->whereIn('org_unit_id', OrgUnit::within($meeting->orgUnit)->select('id'));
            if ($meeting->vibhag_id) {
                $q->whereIn('user_id', fn ($s) => $s->select('user_id')->from('member_vibhag')->where('vibhag_id', $meeting->vibhag_id));
            }
            $ids = $q->pluck('user_id');
        }

        if ($memberIds) {
            $ids = $ids->merge(MemberProfile::whereIn('member_id', $memberIds)->where('membership_status', MemberProfile::STATUS_APPROVED)->pluck('user_id'));
        }

        return $ids->unique();
    }

    private function guardInvolved(User $user, Meeting $meeting): void
    {
        $adminView = $meeting->org_unit_id && $this->access->canIn($user, 'meetings.schedule', $meeting->orgUnit);
        if (! $meeting->involves($user) && ! $adminView) {
            throw new ApiException('NOT_INVITED', 'You are not invited to this meeting.', 403);
        }
    }

    private function guardOrganiser(User $user, Meeting $meeting): void
    {
        if ($meeting->organiser_id !== $user->id) {
            throw new ApiException('NOT_ORGANISER', 'Only the person who scheduled this can change it.', 403);
        }
    }

    private function inviteFor(User $user, Meeting $meeting): MeetingInvitee
    {
        return MeetingInvitee::where('meeting_id', $meeting->id)->where('user_id', $user->id)->first()
            ?? throw new ApiException('NOT_INVITED', 'You are not invited to this meeting.', 403);
    }

    private function summary(Meeting $m, User $user, ?MeetingInvitee $invite): array
    {
        return [
            'id' => $m->id,
            'kind' => $m->kind,
            'title' => $m->title,
            'mode' => $m->mode,
            'provider' => $m->provider,
            'venue' => $m->venue,
            'starts_at' => $m->starts_at->toIso8601String(),
            'ends_at' => $m->ends_at->toIso8601String(),
            'status' => $m->status,
            'organiser' => $m->organiser?->profile?->full_name,
            'is_organiser' => $m->organiser_id === $user->id,
            'vibhag' => $m->vibhag?->name,
            'my_rsvp' => $invite?->rsvp,
        ];
    }

    private function detail(Meeting $meeting, User $user): array
    {
        $meeting->refresh()->load('organiser.profile', 'vibhag', 'orgUnit', 'actionItems.assignee.profile');
        $invite = MeetingInvitee::where('meeting_id', $meeting->id)->where('user_id', $user->id)->first();
        $counts = MeetingInvitee::where('meeting_id', $meeting->id)->selectRaw('rsvp, count(*) as n')->groupBy('rsvp')->pluck('n', 'rsvp');
        $isOrganiser = $meeting->organiser_id === $user->id;

        $data = $this->summary($meeting, $user, $invite) + [
            'agenda' => $meeting->agenda,
            'link' => $meeting->link,
            'audience' => $meeting->orgUnit ? trim(($meeting->vibhag?->name ? $meeting->vibhag->name.' · ' : '').$meeting->orgUnit->name) : null,
            'rsvp_counts' => [
                'going' => (int) ($counts['going'] ?? 0),
                'maybe' => (int) ($counts['maybe'] ?? 0),
                'no' => (int) ($counts['no'] ?? 0),
                'pending' => (int) ($counts['pending'] ?? 0),
            ],
            'attended' => MeetingInvitee::where('meeting_id', $meeting->id)->whereNotNull('joined_at')->count(),
            'minutes' => $meeting->minutes,
            'action_items' => $meeting->actionItems->map(fn (ActionItem $a) => [
                'id' => $a->id, 'title' => $a->title, 'assignee' => $a->assignee?->profile?->full_name,
                'due_on' => $a->due_on?->toDateString(), 'done' => $a->done_at !== null,
            ]),
        ];

        if ($meeting->kind === 'call' || $isOrganiser) {
            $data['people'] = MeetingInvitee::where('meeting_id', $meeting->id)->with('user.profile')->limit(200)->get()
                ->map(fn ($i) => ['name' => $i->user?->profile?->full_name, 'member_id' => $i->user?->profile?->member_id, 'rsvp' => $i->rsvp, 'note' => $i->rsvp_note, 'joined' => $i->joined_at !== null]);
        }

        return $data;
    }
}
