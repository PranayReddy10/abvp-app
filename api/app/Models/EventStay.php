<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class EventStay extends Model
{
    protected $table = 'event_stays';

    protected $fillable = ['event_id', 'name', 'address', 'map_url', 'for_gender'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function rooms(): HasMany
    {
        return $this->hasMany(EventRoom::class, 'stay_id')->orderBy('id');
    }
}
