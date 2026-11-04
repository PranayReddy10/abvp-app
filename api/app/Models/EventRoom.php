<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class EventRoom extends Model
{
    public $timestamps = false;

    protected $fillable = ['stay_id', 'name', 'capacity'];

    public function stay(): BelongsTo
    {
        return $this->belongsTo(EventStay::class, 'stay_id');
    }

    public function allocations(): HasMany
    {
        return $this->hasMany(RoomAllocation::class, 'room_id');
    }
}
