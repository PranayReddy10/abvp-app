<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** An event team: a conference ghat (no parent), one of its departments, or a plain team. */
class EventTeam extends Model
{
    protected $fillable = ['event_id', 'parent_id', 'kind', 'name', 'name_local', 'description', 'lead_user_id', 'sort', 'color'];

    public const HEAD_ROLES = ['ghat_pramukh', 'ghat_saha_pramukh', 'ghat_palak'];

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function parent(): BelongsTo
    {
        return $this->belongsTo(self::class, 'parent_id');
    }

    public function children(): HasMany
    {
        return $this->hasMany(self::class, 'parent_id')->orderBy('sort')->orderBy('id');
    }

    public function members(): HasMany
    {
        return $this->hasMany(EventTeamMember::class, 'team_id')->orderBy('sort')->orderBy('id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(EventTeamMessage::class, 'team_id');
    }

    public function lead(): BelongsTo
    {
        return $this->belongsTo(User::class, 'lead_user_id');
    }

    public function duties(): HasMany
    {
        return $this->hasMany(EventDuty::class, 'team_id');
    }

    /** The ghat this team belongs to (itself for a ghat). */
    public function ghat(): self
    {
        return $this->parent_id ? ($this->parent ?? $this) : $this;
    }
}
