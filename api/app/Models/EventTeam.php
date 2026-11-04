<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class EventTeam extends Model
{
    protected $fillable = ['event_id', 'name', 'description', 'lead_user_id'];

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function lead(): BelongsTo
    {
        return $this->belongsTo(User::class, 'lead_user_id');
    }

    public function duties(): HasMany
    {
        return $this->hasMany(EventDuty::class, 'team_id');
    }
}
