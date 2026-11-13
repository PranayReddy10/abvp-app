<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Event;
use App\Models\EventAnnouncement;
use App\Models\EventDuty;
use App\Models\EventRegistration;
use App\Models\EventStaff;
use App\Models\EventTeam;
use App\Models\HelpReply;
use App\Models\HelpRequest;
use App\Models\User;
use App\Services\DutyPresenter;
use App\Services\EventService;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Event day for members: my duties, my teams, help requests and announcements. */
class OperationsController extends Controller
{
    public function __construct(private EventService $events) {}

    public function myDuties(Request $request)
    {
        $duties = EventDuty::where('assignee_id', $request->user()->id)
            ->where('status', '!=', 'cancelled')
            ->where('ends_at', '>=', now()->subDays(2))
            ->with('event', 'team.lead.profile', 'reportingTo.profile', 'assignee.profile')
            ->orderBy('starts_at')->get();

        return $this->ok($duties->map(fn ($d) => DutyPresenter::present($d, withPhone: true)));
    }

    /** Accept, or say you can't do it (with a reason, so the coordinator can reassign). */
    public function respond(Request $request, EventDuty $duty)
    {
        $data = $request->validate(['response' => ['required', 'in:accept,decline'], 'reason' => ['nullable', 'required_if:response,decline', 'string', 'max:300']]);
        if ($duty->assignee_id !== $request->user()->id) {
            throw new ApiException('NOT_YOUR_DUTY', 'This duty is assigned to someone else.', 403);
        }
        if (! in_array($duty->status, ['assigned', 'accepted'], true)) {
            throw new ApiException('DUTY_STARTED', 'This duty has already started or ended.');
        }

        $accept = $data['response'] === 'accept';
        $duty->update(['status' => $accept ? 'accepted' : 'declined', 'status_note' => $data['reason'] ?? null, 'responded_at' => now()]);

        if (! $accept) {
            $name = $request->user()->profile?->full_name;
            AppNotification::sendMany($this->supervisors($duty), 'duty_declined', "$name can't do: {$duty->title}", $data['reason'], ['event_id' => $duty->event_id, 'duty_id' => $duty->id]);
        }

        return $this->ok(DutyPresenter::present($duty->fresh(['event', 'team.lead.profile', 'reportingTo.profile', 'assignee.profile']), withPhone: true));
    }

    /** Progress from the duty holder or their team lead: started, done, or a problem. */
    public function progress(Request $request, EventDuty $duty)
    {
        $data = $request->validate(['status' => ['required', 'in:in_progress,done,blocked'], 'note' => ['nullable', 'required_if:status,blocked', 'string', 'max:500']]);
        $user = $request->user();
        $isLead = $duty->team?->lead_user_id === $user->id;

        if ($duty->assignee_id !== $user->id && ! $isLead && ! $this->events->canCoordinate($user, $duty->event)) {
            throw new ApiException('NOT_YOUR_DUTY', 'Only the duty holder, their team lead or a coordinator can update this.', 403);
        }
        if (in_array($duty->status, ['declined', 'cancelled'], true)) {
            throw new ApiException('DUTY_CLOSED', 'This duty is no longer active.');
        }

        $duty->update([
            'status' => $data['status'],
            'status_note' => $data['note'] ?? null,
            'completed_at' => $data['status'] === 'done' ? now() : null,
            'responded_at' => $duty->responded_at ?? now(),
        ]);

        if ($data['status'] === 'blocked') {
            AppNotification::sendMany(collect($this->supervisors($duty))->reject(fn ($id) => $id === $user->id), 'duty_blocked',
                "Problem at {$duty->title}", $data['note'], ['event_id' => $duty->event_id, 'duty_id' => $duty->id]);
        }

        return $this->ok(DutyPresenter::present($duty->fresh(['event', 'team.lead.profile', 'reportingTo.profile', 'assignee.profile']), withPhone: $duty->assignee_id === $user->id));
    }

    /** Teams this person leads, with every duty and its state. */
    public function myTeams(Request $request)
    {
        $teams = EventTeam::where('lead_user_id', $request->user()->id)
            ->whereHas('event', fn ($q) => $q->where('status', 'published')->where('ends_at', '>=', now()->subDay()))
            ->with('event', 'duties.assignee.profile', 'duties.team.lead.profile', 'duties.reportingTo.profile')->get();

        return $this->ok($teams->map(fn (EventTeam $t) => [
            'id' => $t->id,
            'name' => $t->name,
            'event' => ['id' => $t->event->id, 'title' => $t->event->title],
            'duties' => $t->duties->where('status', '!=', 'cancelled')->sortBy('starts_at')->values()
                ->map(fn ($d) => DutyPresenter::present($d) + ['assignee_phone' => $d->assignee?->mobile]),
        ]));
    }

    public function announcements(Request $request, Event $event)
    {
        if (! $event->guide_enabled) {
            $this->guardParticipant($request->user(), $event);
        }

        return $this->ok(EventAnnouncement::where('event_id', $event->id)->latest('id')->limit(30)->get()->map(fn ($a) => [
            'id' => $a->id, 'title' => $a->title, 'body' => $a->body, 'at' => $a->created_at->toIso8601String(),
        ]));
    }

    public function raiseHelp(Request $request, Event $event)
    {
        $data = $request->validate([
            'category' => ['required', Rule::in(array_keys(HelpRequest::CATEGORIES))],
            'message' => ['required', 'string', 'min:5', 'max:1000'],
            'location' => ['nullable', 'string', 'max:160'],
        ]);
        // With the conference guide on, anyone signed in can ask for help (guests have no list).
        if (! $event->guide_enabled) {
            $this->guardParticipant($request->user(), $event);
        }

        $help = HelpRequest::create($data + ['event_id' => $event->id, 'raised_by' => $request->user()->id, 'status' => 'open']);

        $coordinators = EventStaff::where('event_id', $event->id)->where('role', 'coordinator')->pluck('user_id')->push($event->organiser_id);
        AppNotification::sendMany($coordinators, 'help_request', HelpRequest::CATEGORIES[$data['category']].' help needed', $data['message'], ['event_id' => $event->id, 'help_id' => $help->id]);

        return $this->ok($this->presentHelp($help->fresh('replies.user.profile', 'raiser.profile', 'event')) + [
            'emergency_note' => $data['category'] === 'medical' ? 'For a medical emergency call 108 now. This request also alerts the event team.' : null,
        ], 201);
    }

    public function myHelp(Request $request)
    {
        $rows = HelpRequest::where('raised_by', $request->user()->id)->with('replies.user.profile', 'raiser.profile', 'event')->latest('id')->limit(30)->get();

        return $this->ok($rows->map(fn ($h) => $this->presentHelp($h, $request->user()->id)));
    }

    /** One conversation, for the chat screen (it polls this every few seconds). */
    public function showHelp(Request $request, HelpRequest $help)
    {
        $user = $request->user();
        if ($help->raised_by !== $user->id && ! $this->events->canCoordinate($user, $help->event)) {
            throw new ApiException('FORBIDDEN', 'This conversation is not yours.', 403);
        }

        return $this->ok($this->presentHelp($help->load('replies.user.profile', 'raiser.profile', 'event'), $user->id));
    }

    public function reply(Request $request, HelpRequest $help)
    {
        $data = $request->validate(['body' => ['required', 'string', 'max:1000']]);
        $user = $request->user();
        $isCoordinator = $this->events->canCoordinate($user, $help->event);
        if ($help->raised_by !== $user->id && ! $isCoordinator) {
            throw new ApiException('FORBIDDEN', 'You cannot reply to this request.', 403);
        }

        HelpReply::create(['help_request_id' => $help->id, 'user_id' => $user->id, 'body' => $data['body']]);
        if ($isCoordinator) {
            $help->update(['status' => $help->status === 'open' ? 'in_progress' : $help->status, 'handled_by' => $help->handled_by ?? $user->id]);
            AppNotification::sendMany([$help->raised_by], 'help_reply', 'Reply to your help request', $data['body'], ['event_id' => $help->event_id, 'help_id' => $help->id]);
        } elseif ($help->handled_by) {
            AppNotification::sendMany([$help->handled_by], 'help_reply', 'New message on a help request', $data['body'], ['event_id' => $help->event_id, 'help_id' => $help->id]);
        }

        return $this->ok($this->presentHelp($help->fresh('replies.user.profile', 'raiser.profile', 'event'), $user->id));
    }

    public static function presentHelp(HelpRequest $h, ?int $viewerId = null): array
    {
        return [
            'id' => $h->id,
            'event' => ['id' => $h->event->id, 'title' => $h->event->title],
            'category' => $h->category,
            'category_label' => HelpRequest::CATEGORIES[$h->category] ?? $h->category,
            'message' => $h->message,
            'location' => $h->location,
            'status' => $h->status,
            'raised_by' => $h->raiser?->profile?->full_name ?? $h->raiser?->name,
            'at' => $h->created_at->toIso8601String(),
            'resolved_at' => $h->resolved_at?->toIso8601String(),
            'replies' => $h->replies->map(fn ($r) => [
                'id' => $r->id,
                'mine' => $viewerId !== null && $r->user_id === $viewerId,
                'by' => $r->user?->profile?->full_name ?? $r->user?->name,
                'from_team' => $r->user_id !== $h->raised_by,
                'body' => $r->body,
                'at' => $r->created_at->toIso8601String(),
            ]),
        ];
    }

    private function supervisors(EventDuty $duty): array
    {
        return array_values(array_unique(array_filter([$duty->team?->lead_user_id, $duty->reporting_user_id, $duty->assigned_by])));
    }

    private function guardParticipant(User $user, Event $event): void
    {
        $in = EventRegistration::where('event_id', $event->id)->where('user_id', $user->id)->where('status', 'registered')->exists()
            || EventStaff::where('event_id', $event->id)->where('user_id', $user->id)->exists()
            || EventDuty::where('event_id', $event->id)->where('assignee_id', $user->id)->exists()
            || $this->events->canCoordinate($user, $event);
        if (! $in) {
            throw new ApiException('NOT_PARTICIPANT', 'This is for people taking part in the event.', 403);
        }
    }
}
