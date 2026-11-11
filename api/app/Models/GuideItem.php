<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class GuideItem extends Model
{
    protected $fillable = ['event_id', 'kind', 'title', 'subtitle', 'region', 'description', 'location', 'landmark', 'color', 'timings', 'tags', 'steps', 'map_url', 'lat', 'lng', 'distance_km', 'travel_time', 'photos', 'sort'];

    protected function casts(): array
    {
        return ['tags' => 'array', 'steps' => 'array', 'photos' => 'array', 'lat' => 'float', 'lng' => 'float', 'distance_km' => 'float'];
    }

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function contacts(): HasMany
    {
        return $this->hasMany(GuideContact::class)->orderByDesc('is_lead')->orderBy('sort');
    }
}
