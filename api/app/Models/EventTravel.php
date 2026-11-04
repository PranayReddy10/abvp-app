<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class EventTravel extends Model
{
    protected $table = 'event_travel';

    protected $fillable = ['event_id', 'user_id', 'mode', 'reference', 'arriving_at', 'arrival_point', 'departing_at', 'needs_pickup', 'needs_stay', 'vehicle_id', 'pickup_status', 'picked_up_at', 'notes'];

    protected function casts(): array
    {
        return ['arriving_at' => 'datetime', 'departing_at' => 'datetime', 'picked_up_at' => 'datetime', 'needs_pickup' => 'boolean', 'needs_stay' => 'boolean'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function vehicle(): BelongsTo
    {
        return $this->belongsTo(EventVehicle::class, 'vehicle_id');
    }
}
