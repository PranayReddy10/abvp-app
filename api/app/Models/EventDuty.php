<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EventDuty extends Model
{
    public const OPEN = ['assigned', 'accepted', 'in_progress', 'blocked'];

    protected $fillable = [
        'event_id', 'team_id', 'assignee_id', 'reporting_user_id', 'title', 'instructions', 'location',
        'starts_at', 'ends_at', 'status', 'status_note', 'responded_at', 'completed_at', 'assigned_by',
    ];

    protected function casts(): array
    {
        return ['starts_at' => 'datetime', 'ends_at' => 'datetime', 'responded_at' => 'datetime', 'completed_at' => 'datetime'];
    }

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function team(): BelongsTo
    {
        return $this->belongsTo(EventTeam::class, 'team_id');
    }

    public function assignee(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assignee_id');
    }

    public function reportingTo(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reporting_user_id');
    }
}
