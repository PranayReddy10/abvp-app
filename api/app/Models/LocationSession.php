<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class LocationSession extends Model
{
    protected $table = 'location_sessions';

    protected $fillable = ['user_id', 'event_id', 'shared_with', 'purpose', 'expires_at', 'stopped_at'];

    protected function casts(): array
    {
        return ['expires_at' => 'datetime', 'stopped_at' => 'datetime'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function points(): HasMany
    {
        return $this->hasMany(LocationPoint::class)->orderByDesc('recorded_at');
    }

    public function isActive(): bool
    {
        return $this->stopped_at === null && $this->expires_at->isFuture();
    }
}
