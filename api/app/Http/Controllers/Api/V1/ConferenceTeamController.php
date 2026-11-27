<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Event;
use App\Models\EventDuty;
use App\Models\EventTeam;
use App\Models\EventTeamMember;
use App\Models\EventTeamMessage;
use App\Models\Meeting;
use App\Models\MeetingInvitee;
use App\Models\User;
use App\Services\Audit;
use App\Services\ConferenceTeams;
use App\Services\DutyPresenter;
use App\Support\ApiException;
use App\Support\Mobile;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * The conference volunteer tree: ghats → departments → people, open for everyone to browse
 * (phone numbers only for signed-in users), plus "My seva", team chat and the heads' tools.
 */
class ConferenceTeamController extends Controller
{
    public function __construct(private ConferenceTeams $teams) {}

    /** The national conference the app is built around (public). */
    public function conference()
    {
        $e = ConferenceTeams::current();
        if (! $e) {
            return $this->ok(null);
        }

        return $this->ok($this->eventCard($e));
    }

    /** The whole tree. Phones only when the viewer is signed in. */
    public function tree(Request $request, Event $event)
    {
        if ($event->status !== 'published') {
            throw new ApiException('NOT_FOUND', 'Not found.', 404);
        }
        ConferenceTeams::ensureReady();
        $viewer = $request->user('sanctum');

        return $this->ok([
            'event' => $this->eventCard($event),
            'ghats' => self::present($event, $viewer !== null),
            'signed_in' => $viewer !== null,
        ]);
    }

    /** My places in the tree with everything I need for seva: chats, meetings, tasks, announcements. */
    public function mySeva(Request $request)
    {
        $user = $request->user();
        $event = $request->filled('event_id') ? Event::findOrFail($request->integer('event_id')) : ConferenceTeams::current();
        if (! $event) {
            return $this->ok(['event' => null, 'places' => [], 'chats' => [], 'meetings' => [], 'tasks' => [], 'announcements' => []]);
        }
        ConferenceTeams::ensureReady();
        $places = $this->teams->placesOf($user, $event);
        $isAdmin = $this->teams->isAdmin($user, $event);

        // Chats: my own teams, the departments of a ghat I head, the ghat of a department I lead.
        $chatTeams = collect();
        foreach ($places as $p) {
            $chatTeams->push($p->team);
            if ($p->team->parent_id === null && in_array($p->role, EventTeam::HEAD_ROLES, true)) {
                $chatTeams = $chatTeams->merge($p->team->children);
            }
            if ($p->team->parent_id !== null && in_array($p->role, ['pramukh', 'saha_pramukh'], true)) {
                $chatTeams->push($p->team->parent);
            }
        }
        $chatTeams = $chatTeams->filter()->unique('id')->sortBy([['parent_id', 'asc'], ['sort', 'asc']])->values();
        $teamIds = $chatTeams->pluck('id');
        $last = EventTeamMessage::whereIn('id', EventTeamMessage::whereIn('team_id', $teamIds)->selectRaw('max(id)')->groupBy('team_id'))
            ->with('user.profile')->get()->keyBy('team_id');

        $meetingIds = MeetingInvitee::where('user_id', $user->id)->pluck('meeting_id');
        $meetings = Meeting::where(fn ($q) => $q->whereIn('event_team_id', $teamIds)->whereIn('id', $meetingIds)->orWhere(fn ($o) => $o->whereIn('event_team_id', $teamIds)->where('organiser_id', $user->id)))
            ->where('status', 'scheduled')->where('ends_at', '>=', now())->orderBy('starts_at')->limit(10)->get();

        $tasks = EventDuty::where('event_id', $event->id)->where('assignee_id', $user->id)->where('status', '!=', 'cancelled')
            ->with('event', 'team.lead.profile', 'reportingTo.profile', 'assignee.profile')->orderBy('starts_at')->limit(20)->get();

        $announcements = EventTeamMessage::whereIn('team_id', $teamIds)->where('is_announcement', true)
            ->with('user.profile', 'team')->latest('id')->limit(10)->get();

        return $this->ok([
            'event' => $this->eventCard($event),
            'is_admin' => $isAdmin,
            'places' => $places->map(fn (EventTeamMember $p) => [
                'member_id' => $p->id,
                'role' => $p->role,
                'role_label' => EventTeamMember::ROLES[$p->role] ?? $p->role,
                'team' => ['id' => $p->team->id, 'name' => $p->team->name, 'kind' => $p->team->parent_id ? 'department' : 'ghat', 'color' => $p->team->color ?? $p->team->parent?->color],
                'ghat' => $p->team->parent ? ['id' => $p->team->parent->id, 'name' => $p->team->parent->name] : null,
                'can_manage' => $this->teams->canManage($user, $p->team),
            ])->values(),
            'chats' => $chatTeams->map(fn (EventTeam $t) => [
                'team_id' => $t->id,
                'name' => $t->name,
                'kind' => $t->parent_id ? 'department' : 'ghat',
                'ghat' => $t->parent?->name,
                'color' => $t->color ?? $t->parent?->color,
                'can_manage' => $this->teams->canManage($user, $t),
                'last' => ($m = $last->get($t->id)) ? ['id' => $m->id, 'body' => $m->body, 'by' => $this->nameOf($m->user), 'at' => $m->created_at->toIso8601String()] : null,
            ])->values(),
            'meetings' => $meetings->map(fn (Meeting $m) => [
                'id' => $m->id, 'title' => $m->title, 'mode' => $m->mode, 'link' => $m->link, 'venue' => $m->venue,
                'starts_at' => $m->starts_at->toIso8601String(), 'ends_at' => $m->ends_at->toIso8601String(),
                'team' => $chatTeams->firstWhere('id', $m->event_team_id)?->name,
            ]),
            'tasks' => $tasks->map(fn ($d) => DutyPresenter::present($d, withPhone: true)),
            'announcements' => $announcements->map(fn (EventTeamMessage $m) => [
                'id' => $m->id, 'team' => $m->team->name, 'body' => $m->body, 'by' => $this->nameOf($m->user), 'at' => $m->created_at->toIso8601String(),
            ]),
        ]);
    }

    public function messages(Request $request, EventTeam $team)
    {
        $this->guardChat($request->user(), $team);
        $q = EventTeamMessage::where('team_id', $team->id)->with('user.profile');
        $rows = $request->filled('after')
            ? $q->where('id', '>', $request->integer('after'))->orderBy('id')->limit(200)->get()
            : $q->latest('id')->limit(100)->get()->reverse()->values();

        return $this->ok([
            'team' => ['id' => $team->id, 'name' => $team->name, 'kind' => $team->parent_id ? 'department' : 'ghat', 'ghat' => $team->parent?->name, 'color' => $team->color ?? $team->parent?->color],
            'can_manage' => $this->teams->canManage($request->user(), $team),
            'people' => $this->teams->chatUserIds($team)->count(),
            'messages' => $rows->map(fn ($m) => $this->message($m, $request->user())),
        ]);
    }

    public function post(Request $request, EventTeam $team)
    {
        $data = $request->validate(['body' => ['required', 'string', 'min:1', 'max:2000'], 'announcement' => ['sometimes', 'boolean']]);
        $user = $request->user();
        $this->guardChat($user, $team);
        $announce = (bool) ($data['announcement'] ?? false);
        if ($announce && ! $this->teams->canManage($user, $team)) {
            throw new ApiException('HEADS_ONLY', 'Only the heads of this team can post announcements.', 403);
        }
        $m = EventTeamMessage::create(['team_id' => $team->id, 'user_id' => $user->id, 'body' => trim($data['body']), 'is_announcement' => $announce]);

        if ($announce) {
            $to = $this->teams->everyoneUnder($team)->reject(fn ($id) => $id === $user->id);
            AppNotification::sendMany($to, 'team_announcement', "📣 {$team->name}", str($m->body)->limit(120)->toString(), ['team_id' => $team->id, 'event_id' => $team->event_id]);
        }

        return $this->ok($this->message($m->load('user.profile'), $user), 201);
    }

    /** Heads add a person to their ghat or department (by name and mobile). */
    public function addMember(Request $request, EventTeam $team)
    {
        $user = $request->user();
        $this->guardManage($user, $team);
        $roles = $team->parent_id === null ? EventTeam::HEAD_ROLES : ['pramukh', 'saha_pramukh', 'volunteer'];
        $data = $request->validate([
            'name' => ['required', 'string', 'min:2', 'max:120'],
            'mobile' => ['nullable', 'string', 'max:20'],
            'role' => ['required', Rule::in($roles)],
            'note' => ['nullable', 'string', 'max:190'],
        ]);
        if (! empty($data['mobile']) && ! Mobile::normalize($data['mobile'])) {
            throw new ApiException('INVALID_MOBILE', 'Enter a valid 10-digit Indian mobile number.');
        }
        $member = new EventTeamMember($data + ['team_id' => $team->id, 'sort' => (int) EventTeamMember::where('team_id', $team->id)->max('sort') + 1]);
        $member->linkByMobile();
        $member->save();
        if ($member->user_id) {
            AppNotification::sendMany([$member->user_id], 'team_added', "You are now in {$team->name}", (EventTeamMember::ROLES[$member->role] ?? $member->role).' · '.$team->event->title, ['team_id' => $team->id, 'event_id' => $team->event_id]);
        }
        Audit::record('team.member_added', $team, null, ['name' => $member->name, 'role' => $member->role]);

        return $this->ok(self::person($member, true), 201);
    }

    public function updateMember(Request $request, EventTeamMember $member)
    {
        $team = $member->team;
        $this->guardManage($request->user(), $team);
        $roles = $team->parent_id === null ? EventTeam::HEAD_ROLES : ['pramukh', 'saha_pramukh', 'volunteer'];
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'min:2', 'max:120'],
            'mobile' => ['nullable', 'string', 'max:20'],
            'role' => ['sometimes', Rule::in($roles)],
            'note' => ['nullable', 'string', 'max:190'],
            'team_id' => ['sometimes', 'integer', Rule::exists('event_teams', 'id')->where('event_id', $team->event_id)],
        ]);
        if (! empty($data['mobile']) && ! Mobile::normalize($data['mobile'])) {
            throw new ApiException('INVALID_MOBILE', 'Enter a valid 10-digit Indian mobile number.');
        }
        if (isset($data['team_id']) && $data['team_id'] !== $team->id) {
            $this->guardManage($request->user(), EventTeam::findOrFail($data['team_id']));
        }
        if (array_key_exists('mobile', $data) && Mobile::normalize((string) $data['mobile']) !== $member->mobile) {
            $member->user_id = null; // re-link to the new number
        }
        $member->fill($data);
        $member->linkByMobile();
        $member->save();

        return $this->ok(self::person($member, true));
    }

    public function removeMember(Request $request, EventTeamMember $member)
    {
        $this->guardManage($request->user(), $member->team);
        Audit::record('team.member_removed', $member->team, ['name' => $member->name, 'role' => $member->role]);
        $member->delete();

        return $this->ok(['deleted' => true]);
    }

    /** A meeting for the whole team (and, for a ghat, all its departments). */
    public function meeting(Request $request, EventTeam $team)
    {
        $user = $request->user();
        $this->guardManage($user, $team);
        $data = $request->validate([
            'title' => ['required', 'string', 'max:160'],
            'agenda' => ['nullable', 'string', 'max:3000'],
            'mode' => ['required', 'in:online,in_person,hybrid'],
            'link' => ['nullable', 'required_unless:mode,in_person', 'url:https', 'max:500'],
            'venue' => ['nullable', 'required_unless:mode,online', 'string', 'max:200'],
            'starts_at' => ['required', 'date', 'after:now'],
            'ends_at' => ['required', 'date', 'after:starts_at'],
        ]);
        $data['starts_at'] = Carbon::parse($data['starts_at'])->utc();
        $data['ends_at'] = Carbon::parse($data['ends_at'])->utc();

        $meeting = DB::transaction(function () use ($data, $user, $team) {
            $meeting = Meeting::create($data + [
                'kind' => 'meeting', 'organiser_id' => $user->id, 'event_team_id' => $team->id,
                'provider' => Meeting::providerFor($data['link'] ?? null),
            ]);
            $ids = $this->teams->everyoneUnder($team)->reject(fn ($id) => $id === $user->id)->values();
            $now = now();
            MeetingInvitee::insert($ids->map(fn ($id) => ['meeting_id' => $meeting->id, 'user_id' => $id, 'rsvp' => 'pending', 'created_at' => $now, 'updated_at' => $now])->all());
            AppNotification::sendMany($ids, 'meeting_invite', $meeting->title,
                $meeting->starts_at->timezone('Asia/Kolkata')->format('D j M, g:i A')." · {$team->name}", ['meeting_id' => $meeting->id]);

            return $meeting;
        });
        EventTeamMessage::create(['team_id' => $team->id, 'user_id' => $user->id, 'is_announcement' => true,
            'body' => "Meeting: {$meeting->title} · ".$meeting->starts_at->timezone('Asia/Kolkata')->format('D j M, g:i A').($meeting->link ? " · {$meeting->link}" : '').($meeting->venue ? " · {$meeting->venue}" : '')]);

        return $this->ok(['id' => $meeting->id, 'invited' => $meeting->invitees()->count()], 201);
    }

    /** Assign a task to someone in the team (uses the event duty flow: accept, start, done). */
    public function task(Request $request, EventTeam $team)
    {
        $user = $request->user();
        $this->guardManage($user, $team);
        $data = $request->validate([
            'member_id' => ['required', 'integer', 'exists:event_team_members,id'],
            'title' => ['required', 'string', 'max:160'],
            'instructions' => ['nullable', 'string', 'max:2000'],
            'location' => ['nullable', 'string', 'max:160'],
            'starts_at' => ['required', 'date'],
            'ends_at' => ['required', 'date', 'after:starts_at'],
        ]);
        $member = EventTeamMember::findOrFail($data['member_id']);
        $allowed = collect([$team->id])->merge($team->parent_id === null ? $team->children()->pluck('id') : []);
        if (! $allowed->contains($member->team_id)) {
            throw new ApiException('NOT_IN_TEAM', 'This person is not in your team.', 422);
        }
        if (! $member->user_id) {
            throw new ApiException('NOT_SIGNED_UP', "{$member->name} has not signed in to the app yet, so tasks cannot reach them. Add their mobile number and ask them to sign in.", 422);
        }
        $duty = EventDuty::create([
            'event_id' => $team->event_id, 'team_id' => $member->team_id, 'assignee_id' => $member->user_id, 'reporting_user_id' => $user->id,
            'title' => $data['title'], 'instructions' => $data['instructions'] ?? null, 'location' => $data['location'] ?? null,
            'starts_at' => Carbon::parse($data['starts_at'])->utc(), 'ends_at' => Carbon::parse($data['ends_at'])->utc(),
            'status' => 'assigned', 'assigned_by' => $user->id,
        ]);
        AppNotification::sendMany([$member->user_id], 'duty_assigned', "New task: {$duty->title}",
            $duty->starts_at->timezone('Asia/Kolkata')->format('D j M, g:i A').' · please accept', ['event_id' => $team->event_id]);

        return $this->ok(['id' => $duty->id], 201);
    }

    /** @return array<int, array<string, mixed>> */
    public static function present(Event $event, bool $phones): array
    {
        $ghats = EventTeam::where('event_id', $event->id)->whereNull('parent_id')->where('kind', 'ghat')
            ->with(['members.user.profile', 'children.members.user.profile'])->orderBy('sort')->orderBy('id')->get();

        return $ghats->map(fn (EventTeam $g) => [
            'id' => $g->id,
            'name' => $g->name,
            'name_local' => $g->name_local,
            'color' => $g->color,
            'heads' => $g->members->map(fn ($m) => self::person($m, $phones))->values(),
            'departments' => $g->children->map(fn (EventTeam $d) => [
                'id' => $d->id,
                'name' => $d->name,
                'name_local' => $d->name_local,
                'people' => $d->members->map(fn ($m) => self::person($m, $phones))->values(),
            ])->values(),
            'counts' => [
                'departments' => $g->children->count(),
                'people' => $g->members->count() + $g->children->sum(fn ($d) => $d->members->count()),
            ],
        ])->values()->all();
    }

    public static function person(EventTeamMember $m, bool $phones): array
    {
        $p = $m->user?->profile;

        return [
            'id' => $m->id,
            'name' => $m->name,
            'role' => $m->role,
            'role_label' => EventTeamMember::ROLES[$m->role] ?? $m->role,
            'mobile' => $phones ? $m->mobile : null,
            'has_mobile' => (bool) $m->mobile,
            'linked' => $m->user_id !== null,
            'note' => $m->note,
            'photo_url' => $p?->photo_path ? \Illuminate\Support\Facades\URL::temporarySignedRoute('media.photo', now()->addHour(), ['profile' => $p->id]) : null,
        ];
    }

    private function eventCard(Event $e): array
    {
        return [
            'id' => $e->id,
            'title' => $e->title,
            'venue' => $e->venue,
            'starts_at' => $e->starts_at->toIso8601String(),
            'ends_at' => $e->ends_at->toIso8601String(),
            'helpline' => $e->helpline_phone,
            'guide_enabled' => (bool) $e->guide_enabled,
            'delegate_registration_open' => (bool) $e->delegate_registration_open,
            'has_teams' => EventTeam::where('event_id', $e->id)->where('kind', 'ghat')->exists(),
        ];
    }

    private function message(EventTeamMessage $m, User $viewer): array
    {
        $p = $m->user?->profile;

        return [
            'id' => $m->id,
            'body' => $m->body,
            'announcement' => $m->is_announcement,
            'by' => $this->nameOf($m->user),
            'mine' => $m->user_id === $viewer->id,
            'photo_url' => $p?->photo_path ? \Illuminate\Support\Facades\URL::temporarySignedRoute('media.photo', now()->addHour(), ['profile' => $p->id]) : null,
            'at' => $m->created_at->toIso8601String(),
        ];
    }

    private function nameOf(?User $u): string
    {
        return (string) ($u?->profile?->full_name ?: $u?->name ?: 'Someone');
    }

    private function guardChat(User $user, EventTeam $team): void
    {
        if (! $this->teams->canChat($user, $team)) {
            throw new ApiException('NOT_IN_TEAM', 'Team chat is for the people in this team.', 403);
        }
    }

    private function guardManage(User $user, EventTeam $team): void
    {
        if (! $this->teams->canManage($user, $team)) {
            throw new ApiException('HEADS_ONLY', 'Only the heads of this team can do this.', 403);
        }
    }
}
