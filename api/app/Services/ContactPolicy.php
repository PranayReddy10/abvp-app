<?php

namespace App\Services;

use App\Models\Event;
use App\Models\EventDuty;
use App\Models\EventStaff;
use App\Models\EventTeam;
use App\Models\User;

/**
 * Who may see someone's phone number regardless of their privacy setting:
 * people working together at a current event. Teammates on the same duty team
 * (and its lead) see each other; coordinators see everyone with a duty at their
 * event. Admins see members inside their own area.
 */
class ContactPolicy
{
    public function __construct(private AccessControl $access, private EventService $events) {}

    public function canSeePhone(User $viewer, User $target): bool
    {
        if ($viewer->id === $target->id) {
            return true;
        }
        $unit = $target->profile?->orgUnit;
        if ($unit && $this->access->canIn($viewer, 'members.view', $unit)) {
            return true;
        }

        return $this->workTogether($viewer, $target);
    }

    public function workTogether(User $viewer, User $target): bool
    {
        $active = fn ($q) => $q->where('status', 'published')->where('ends_at', '>=', now()->subDay());

        // Teams either person is part of (with a duty, or as lead) at current events.
        $teamsOf = fn (User $u) => EventDuty::where('assignee_id', $u->id)->whereNotIn('status', ['cancelled', 'declined'])
            ->whereHas('event', $active)->whereNotNull('team_id')->pluck('team_id')
            ->merge(EventTeam::where('lead_user_id', $u->id)->whereHas('event', $active)->pluck('id'));

        if ($teamsOf($viewer)->intersect($teamsOf($target))->isNotEmpty()) {
            return true;
        }

        // Coordinators of an event see everyone with a duty there.
        $targetEvents = EventDuty::where('assignee_id', $target->id)->whereNotIn('status', ['cancelled'])
            ->whereHas('event', $active)->pluck('event_id')->unique();
        foreach (Event::whereIn('id', $targetEvents)->get() as $event) {
            if ($this->events->canCoordinate($viewer, $event)) {
                return true;
            }
        }

        // Someone the viewer must report to, or who reports to the viewer.
        return EventDuty::whereHas('event', $active)->whereNotIn('status', ['cancelled'])
            ->where(fn ($q) => $q->where(fn ($w) => $w->where('assignee_id', $viewer->id)->where('reporting_user_id', $target->id))
                ->orWhere(fn ($w) => $w->where('assignee_id', $target->id)->where('reporting_user_id', $viewer->id)))
            ->exists();
    }
}
