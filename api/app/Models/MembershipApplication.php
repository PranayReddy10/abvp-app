<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class MembershipApplication extends Model
{
    public const SUBMITTED = 'submitted';
    public const MORE_INFO = 'more_info_required';
    public const APPROVED = 'approved';
    public const REJECTED = 'rejected';

    protected $fillable = ['user_id', 'org_unit_id', 'status', 'submitted_at'];

    protected function casts(): array
    {
        return ['submitted_at' => 'datetime', 'decided_at' => 'datetime'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function orgUnit(): BelongsTo
    {
        return $this->belongsTo(OrgUnit::class);
    }

    public function decider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'decided_by');
    }

    public function events(): HasMany
    {
        return $this->hasMany(ApplicationEvent::class)->orderBy('id');
    }

    public function isOpen(): bool
    {
        return $this->status === self::SUBMITTED;
    }
}
