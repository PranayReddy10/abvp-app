<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class EventVehicle extends Model
{
    protected $table = 'event_vehicles';

    protected $fillable = ['event_id', 'name', 'capacity', 'pickup_point', 'departs_at', 'driver_name', 'driver_phone'];

    protected function casts(): array
    {
        return ['departs_at' => 'datetime'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function passengers(): HasMany
    {
        return $this->hasMany(EventTravel::class, 'vehicle_id');
    }
}
