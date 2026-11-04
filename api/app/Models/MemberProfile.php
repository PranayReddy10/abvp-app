<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MemberProfile extends Model
{
    public const STATUS_DRAFT = 'draft';
    public const STATUS_SUBMITTED = 'submitted';
    public const STATUS_MORE_INFO = 'more_info_required';
    public const STATUS_APPROVED = 'approved';
    public const STATUS_REJECTED = 'rejected';
    public const STATUS_SUSPENDED = 'suspended';

    protected $fillable = [
        'full_name', 'gender', 'date_of_birth', 'org_unit_id', 'institution', 'course',
        'study_year', 'bio', 'languages', 'skills', 'links', 'privacy',
    ];

    protected function casts(): array
    {
        return [
            'date_of_birth' => 'date',
            'approved_at' => 'datetime',
            'verified_at' => 'datetime',
            'languages' => 'array',
            'skills' => 'array',
            'links' => 'array',
            'privacy' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function orgUnit(): BelongsTo
    {
        return $this->belongsTo(OrgUnit::class);
    }

    public function isVerified(): bool
    {
        return $this->verified_at !== null && $this->membership_status === self::STATUS_APPROVED;
    }

    public function privacyFor(string $field): string
    {
        return $this->privacy[$field] ?? config("abvp.privacy_defaults.$field", 'nobody');
    }
}
