<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LocationPoint extends Model
{
    public $timestamps = false;

    protected $fillable = ['location_session_id', 'lat', 'lng', 'accuracy_m', 'recorded_at'];

    protected function casts(): array
    {
        return ['recorded_at' => 'datetime', 'lat' => 'float', 'lng' => 'float'];
    }
}
