<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Circular extends Model
{
    protected $fillable = ['title', 'body', 'attachment_path', 'org_unit_id', 'vibhag_id', 'issued_by', 'audience_size', 'published_at'];

    protected function casts(): array
    {
        return ['published_at' => 'datetime'];
    }

    public function orgUnit(): BelongsTo
    {
        return $this->belongsTo(OrgUnit::class);
    }

    public function vibhag(): BelongsTo
    {
        return $this->belongsTo(Vibhag::class);
    }

    public function issuer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'issued_by');
    }

    public function reads(): HasMany
    {
        return $this->hasMany(CircularRead::class);
    }

    /** Circulars addressed to this member: issued at their unit or any unit above it. */
    public function scopeFor(Builder $query, User $user): Builder
    {
        $unit = $user->profile?->orgUnit;
        if (! $unit) {
            return $query->whereRaw('1 = 0');
        }

        $ancestorIds = array_values(array_filter(explode('/', $unit->path)));
        $vibhagIds = $user->vibhags()->pluck('vibhags.id');

        return $query->whereIn('org_unit_id', $ancestorIds)
            ->where(fn ($q) => $q->whereNull('vibhag_id')->orWhereIn('vibhag_id', $vibhagIds))
            ->where('published_at', '<=', now());
    }

    /** Approved members this circular reaches. */
    public function audienceQuery(): Builder
    {
        $q = MemberProfile::query()
            ->where('membership_status', MemberProfile::STATUS_APPROVED)
            ->whereIn('org_unit_id', OrgUnit::within($this->orgUnit)->select('id'));

        if ($this->vibhag_id) {
            $q->whereIn('user_id', fn ($s) => $s->select('user_id')->from('member_vibhag')->where('vibhag_id', $this->vibhag_id));
        }

        return $q;
    }
}
