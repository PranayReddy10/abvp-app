<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EventTeamMessage extends Model
{
    protected $fillable = ['team_id', 'user_id', 'body', 'is_announcement'];

    protected function casts(): array
    {
        return ['is_announcement' => 'boolean'];
    }

    public function team(): BelongsTo
    {
        return $this->belongsTo(EventTeam::class, 'team_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
