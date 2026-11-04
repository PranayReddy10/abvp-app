<?php

namespace App\Services;

use App\Models\EventDuty;

class DutyPresenter
{
    public static function present(EventDuty $d, bool $withPhone = false): array
    {
        $report = $d->reportingTo ?? $d->team?->lead;
        $badge = fn ($u) => (bool) $u?->profile?->isVerified();

        return [
            'id' => $d->id,
            'title' => $d->title,
            'instructions' => $d->instructions,
            'location' => $d->location,
            'starts_at' => $d->starts_at->toIso8601String(),
            'ends_at' => $d->ends_at->toIso8601String(),
            'status' => $d->status,
            'status_note' => $d->status_note,
            'team' => $d->team ? ['id' => $d->team->id, 'name' => $d->team->name] : null,
            'assignee' => ['name' => $d->assignee?->profile?->full_name ?? $d->assignee?->name, 'member_id' => $d->assignee?->profile?->member_id, 'verified' => $badge($d->assignee)],
            // The person to report to. Their number is shared only with the duty holder.
            'report_to' => $report ? [
                'name' => $report->profile?->full_name ?? $report->name,
                'verified' => $badge($report),
                'phone' => $withPhone ? $report->mobile : null,
            ] : null,
            // The rest of the team, so the duty holder can reach them directly.
            'team_contacts' => $withPhone && $d->team ? self::teamContacts($d) : [],
            'event' => $d->relationLoaded('event') ? ['id' => $d->event->id, 'title' => $d->event->title, 'venue' => $d->event->venue] : null,
        ];
    }

    public static function teamContacts(EventDuty $d): array
    {
        $lead = $d->team->lead;
        $others = EventDuty::where('team_id', $d->team_id)->where('assignee_id', '!=', $d->assignee_id)
            ->whereNotIn('status', ['cancelled', 'declined'])->with('assignee.profile')->get()->unique('assignee_id');

        $rows = collect();
        if ($lead && $lead->id !== $d->assignee_id) {
            $rows->push(['name' => $lead->profile?->full_name ?? $lead->name, 'role' => 'Team lead', 'duty' => null, 'location' => null,
                'phone' => $lead->mobile, 'verified' => (bool) $lead->profile?->isVerified()]);
        }
        foreach ($others as $o) {
            if ($o->assignee_id === $lead?->id) {
                continue;
            }
            $rows->push(['name' => $o->assignee->profile?->full_name ?? $o->assignee->name, 'role' => 'Teammate', 'duty' => $o->title,
                'location' => $o->location, 'phone' => $o->assignee->mobile, 'verified' => (bool) $o->assignee->profile?->isVerified()]);
        }

        return $rows->values()->all();
    }
}
