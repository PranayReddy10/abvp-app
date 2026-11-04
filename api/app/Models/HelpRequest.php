<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class HelpRequest extends Model
{
    public const CATEGORIES = [
        'medical' => 'Medical',
        'registration' => 'Registration or pass',
        'stay' => 'Stay',
        'food' => 'Food',
        'transport' => 'Transport',
        'venue' => 'Venue or directions',
        'lost' => 'Lost and found',
        'other' => 'Something else',
    ];

    protected $fillable = ['event_id', 'raised_by', 'category', 'message', 'location', 'status', 'team_id', 'handled_by', 'resolved_at'];

    protected function casts(): array
    {
        return ['resolved_at' => 'datetime'];
    }

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function raiser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'raised_by');
    }

    public function team(): BelongsTo
    {
        return $this->belongsTo(EventTeam::class, 'team_id');
    }

    public function replies(): HasMany
    {
        return $this->hasMany(HelpReply::class)->orderBy('id');
    }
}
