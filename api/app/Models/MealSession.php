<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class MealSession extends Model
{
    protected $table = 'meal_sessions';

    protected $fillable = ['event_id', 'name', 'starts_at', 'ends_at', 'location'];

    protected function casts(): array
    {
        return ['starts_at' => 'datetime', 'ends_at' => 'datetime'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function servings(): HasMany
    {
        return $this->hasMany(MealServing::class);
    }
}
