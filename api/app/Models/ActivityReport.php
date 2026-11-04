<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ActivityReport extends Model
{
    public const TYPES = [
        'agitation' => 'Agitation / andolan',
        'campus_contact' => 'Campus contact',
        'seva' => 'Seva activity',
        'training' => 'Training / abhyas varg',
        'seminar' => 'Seminar / talk',
        'cultural' => 'Cultural programme',
        'sports' => 'Sports',
        'membership_drive' => 'Membership drive',
        'meeting' => 'Baithak',
        'other' => 'Other',
    ];

    protected $fillable = [
        'org_unit_id', 'vibhag_id', 'submitted_by', 'title', 'programme_type', 'held_on',
        'place', 'participants', 'institutions', 'description', 'photos',
    ];

    protected function casts(): array
    {
        return ['held_on' => 'date', 'photos' => 'array'];
    }

    public function orgUnit(): BelongsTo
    {
        return $this->belongsTo(OrgUnit::class);
    }

    public function vibhag(): BelongsTo
    {
        return $this->belongsTo(Vibhag::class);
    }

    public function submitter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'submitted_by');
    }
}
