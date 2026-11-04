<?php

namespace App\Services;

use App\Models\EventDuty;

class DutyPresenter
{
    public static function present(EventDuty $d, bool $withPhone = false): array
    {
        $report = $d->reportingTo ?? $d->team?->lead;

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
            'assignee' => ['name' => $d->assignee?->profile?->full_name ?? $d->assignee?->name, 'member_id' => $d->assignee?->profile?->member_id],
            // The person to report to. Their number is shared only with the duty holder.
            'report_to' => $report ? [
                'name' => $report->profile?->full_name ?? $report->name,
                'phone' => $withPhone ? $report->mobile : null,
            ] : null,
            'event' => $d->relationLoaded('event') ? ['id' => $d->event->id, 'title' => $d->event->title, 'venue' => $d->event->venue] : null,
        ];
    }
}
