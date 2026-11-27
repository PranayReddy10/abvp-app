<?php

namespace App\Services;

use App\Models\Event;
use App\Models\EventTeam;
use App\Models\EventTeamMember;
use App\Models\User;
use Illuminate\Support\Collection;

/**
 * Who belongs where in the conference volunteer tree, and what they may do.
 *
 * - A ghat chat: the ghat heads (Pramukh, Saha Pramukh, Palak) and every department Pramukh in it.
 * - A department chat: its Pramukh(s), its volunteers and the heads of its ghat.
 * - Heads manage their own ghat (and its departments) or their own department.
 * - Admins with events.manage on the event can do everything.
 */
class ConferenceTeams
{
    public function __construct(private AccessControl $access) {}

    /** The national conference people see in the app: the next published conference that has not ended. */
    public static function current(): ?Event
    {
        return Event::where('status', 'published')->where('category', 'conference')->where('ends_at', '>=', now()->subDay())
            ->withCount(['teams as ghat_count' => fn ($q) => $q->whereNull('parent_id')->where('kind', 'ghat')])
            ->orderByDesc('ghat_count')->orderBy('starts_at')->first();
    }

    public function isAdmin(User $user, Event $event): bool
    {
        return $this->access->canIn($user, 'events.manage', $event->orgUnit);
    }

    /** @return Collection<int, EventTeamMember> this user's places in the event's tree */
    public function placesOf(User $user, Event $event): Collection
    {
        return EventTeamMember::where('user_id', $user->id)
            ->whereHas('team', fn ($q) => $q->where('event_id', $event->id))
            ->with('team.parent')->get();
    }

    public function canChat(User $user, EventTeam $team): bool
    {
        if ($this->isAdmin($user, $team->event)) {
            return true;
        }

        return $this->chatUserIds($team)->contains($user->id);
    }

    public function canManage(User $user, EventTeam $team): bool
    {
        if ($this->isAdmin($user, $team->event)) {
            return true;
        }
        $mine = EventTeamMember::where('user_id', $user->id);
        // Heads of this ghat, or of the ghat this department is in.
        $ghatId = $team->parent_id ?? $team->id;
        if ((clone $mine)->where('team_id', $ghatId)->whereIn('role', EventTeam::HEAD_ROLES)->exists()) {
            return true;
        }

        // A department's own Pramukh / Saha Pramukh.
        return $team->parent_id !== null
            && (clone $mine)->where('team_id', $team->id)->whereIn('role', ['pramukh', 'saha_pramukh'])->exists();
    }

    /** @return Collection<int, int> account ids who are in this team's chat */
    public function chatUserIds(EventTeam $team): Collection
    {
        if ($team->parent_id === null) {
            $heads = EventTeamMember::where('team_id', $team->id)->pluck('user_id');
            $deptLeads = EventTeamMember::whereIn('team_id', $team->children()->select('id'))
                ->whereIn('role', ['pramukh', 'saha_pramukh'])->pluck('user_id');

            return $heads->merge($deptLeads)->filter()->unique()->values();
        }
        $own = EventTeamMember::where('team_id', $team->id)->pluck('user_id');
        $ghatHeads = EventTeamMember::where('team_id', $team->parent_id)->whereIn('role', EventTeam::HEAD_ROLES)->pluck('user_id');

        return $own->merge($ghatHeads)->filter()->unique()->values();
    }

    /** Everyone in a team and, for a ghat, everyone in its departments (for announcements and meetings). */
    public function everyoneUnder(EventTeam $team): Collection
    {
        $ids = collect([$team->id]);
        if ($team->parent_id === null) {
            $ids = $ids->merge($team->children()->pluck('id'));
        }

        return EventTeamMember::whereIn('team_id', $ids)->pluck('user_id')
            ->merge($team->parent_id ? EventTeamMember::where('team_id', $team->parent_id)->whereIn('role', EventTeam::HEAD_ROLES)->pluck('user_id') : [])
            ->filter()->unique()->values();
    }
}
