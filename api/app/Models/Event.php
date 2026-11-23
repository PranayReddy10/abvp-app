<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Event extends Model
{
    public const CATEGORIES = [
        'conference' => 'Conference / adhiveshan',
        'training' => 'Training camp / abhyas varg',
        'programme' => 'Programme',
        'campaign' => 'Campaign',
        'cultural' => 'Cultural',
        'sports' => 'Sports',
        'seminar' => 'Seminar',
    ];

    protected $fillable = [
        'title', 'description', 'category', 'instructions', 'venue', 'venue_map_url', 'starts_at', 'ends_at',
        'org_unit_id', 'organiser_id', 'registration_opens_at', 'registration_closes_at', 'capacity',
        'requires_approval', 'members_only', 'waitlist_enabled', 'contact_name', 'contact_phone',
        'guide_enabled', 'venue_lat', 'venue_lng', 'helpline_phone', 'delegate_registration_open',
    ];

    protected function casts(): array
    {
        return [
            'guide_enabled' => 'boolean', 'delegate_registration_open' => 'boolean', 'venue_lat' => 'float', 'venue_lng' => 'float',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'registration_opens_at' => 'datetime',
            'registration_closes_at' => 'datetime',
            'published_at' => 'datetime',
            'requires_approval' => 'boolean',
            'members_only' => 'boolean',
            'waitlist_enabled' => 'boolean',
        ];
    }

    public function orgUnit(): BelongsTo
    {
        return $this->belongsTo(OrgUnit::class);
    }

    public function organiser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'organiser_id');
    }

    public function rules(): HasMany
    {
        return $this->hasMany(EventEligibilityRule::class);
    }

    public function registrations(): HasMany
    {
        return $this->hasMany(EventRegistration::class);
    }

    public function staff(): HasMany
    {
        return $this->hasMany(EventStaff::class);
    }

    /** Seats taken: registered plus pending approval. Guests count too. */
    public function seatsTaken(): int
    {
        return $this->registrations()->whereIn('status', [EventRegistration::REGISTERED, EventRegistration::PENDING])->count();
    }

    public function registrationOpen(): bool
    {
        return $this->status === 'published'
            && ($this->registration_opens_at === null || $this->registration_opens_at->isPast())
            && ($this->registration_closes_at ?? $this->starts_at)->isFuture();
    }
}
