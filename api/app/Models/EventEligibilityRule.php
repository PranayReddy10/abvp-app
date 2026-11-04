<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EventEligibilityRule extends Model
{
    public $timestamps = false;

    protected $fillable = ['event_id', 'org_unit_id', 'vibhag_id'];

    public function orgUnit(): BelongsTo
    {
        return $this->belongsTo(OrgUnit::class);
    }

    public function vibhag(): BelongsTo
    {
        return $this->belongsTo(Vibhag::class);
    }

    public function describe(): string
    {
        return collect([$this->vibhag?->name, $this->orgUnit ? 'members in '.$this->orgUnit->name : null])
            ->filter()->implode(' · ') ?: 'All members';
    }
}
