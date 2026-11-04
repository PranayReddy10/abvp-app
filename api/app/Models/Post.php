<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Post extends Model
{
    /** Five reports hide a post until an admin reviews it. */
    public const AUTO_HIDE_REPORTS = 5;

    protected $fillable = ['user_id', 'body', 'audience', 'org_unit_id', 'vibhag_id', 'repost_of_id', 'photos'];

    protected function casts(): array
    {
        return ['photos' => 'array', 'hidden_at' => 'datetime', 'reviewed_at' => 'datetime'];
    }

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function original(): BelongsTo
    {
        return $this->belongsTo(Post::class, 'repost_of_id');
    }

    public function vibhag(): BelongsTo
    {
        return $this->belongsTo(Vibhag::class);
    }

    public function orgUnit(): BelongsTo
    {
        return $this->belongsTo(OrgUnit::class);
    }

    public function comments(): HasMany
    {
        return $this->hasMany(PostComment::class)->orderBy('id');
    }

    /** Posts this member may see: visible, and addressed to them. */
    public function scopeVisibleTo(Builder $q, User $viewer): Builder
    {
        $unit = $viewer->profile?->orgUnit;
        $ancestors = $unit ? array_values(array_filter(explode('/', $unit->path))) : [];
        $vibhags = $viewer->vibhags()->pluck('vibhags.id')->all();

        return $q->where(fn ($w) => $w->whereNull('hidden_at')->orWhere('user_id', $viewer->id))
            ->where(fn ($w) => $w->where('user_id', $viewer->id)
                ->orWhere('audience', 'members')
                ->orWhere(fn ($a) => $a->where('audience', 'area')->whereIn('org_unit_id', $ancestors))
                ->orWhere(fn ($a) => $a->where('audience', 'vibhag')->whereIn('vibhag_id', $vibhags)));
    }

    /** Lower-case #tags in the text, letters/digits/underscore, Indic scripts included. */
    public static function extractTags(?string $body): array
    {
        preg_match_all('/#([\p{L}\p{M}\p{N}_]{2,40})/u', (string) $body, $m);

        return array_values(array_unique(array_map(fn ($t) => mb_strtolower($t), $m[1])));
    }
}
