<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EventRegistration extends Model
{
    public const REGISTERED = 'registered';
    public const WAITLISTED = 'waitlisted';
    public const PENDING = 'pending';
    public const CANCELLED = 'cancelled';
    public const REJECTED = 'rejected';

    protected $fillable = [
        'event_id', 'user_id', 'kind', 'status', 'guest_name', 'guest_organisation', 'invited_by',
        'decision_note', 'checked_in_at', 'checked_in_by', 'gate', 'check_in_method',
    ];

    protected function casts(): array
    {
        return ['checked_in_at' => 'datetime'];
    }

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function displayName(): string
    {
        return $this->guest_name ?? $this->user?->profile?->full_name ?? $this->user?->name ?? 'Unknown';
    }
}
