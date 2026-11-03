<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    // Mirror the database defaults so a freshly created user is not read as blank.
    protected $attributes = ['locale' => 'en', 'status' => 'active'];

    protected $fillable = ['name', 'mobile', 'email', 'locale', 'status', 'mobile_verified_at', 'last_login_at'];

    protected function casts(): array
    {
        return [
            'mobile_verified_at' => 'datetime',
            'last_login_at' => 'datetime',
        ];
    }

    public function profile(): HasOne
    {
        return $this->hasOne(MemberProfile::class);
    }

    public function application(): HasOne
    {
        return $this->hasOne(MembershipApplication::class)->latestOfMany();
    }

    public function vibhags(): BelongsToMany
    {
        return $this->belongsToMany(Vibhag::class, 'member_vibhag')->withPivot('joined_at');
    }

    public function roleAssignments(): HasMany
    {
        return $this->hasMany(RoleAssignment::class);
    }

    public function responsibilities(): HasMany
    {
        return $this->hasMany(Responsibility::class)->orderByDesc('starts_on');
    }

    /** Role assignments in force today. */
    public function activeRoles()
    {
        return $this->roleAssignments()->active()->with('orgUnit')->get();
    }

    public function isApprovedMember(): bool
    {
        return $this->profile?->membership_status === MemberProfile::STATUS_APPROVED;
    }
}
