<?php

namespace App\Models;

use App\Support\Mobile;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A person in a ghat or department. Linked to an account by mobile number when they sign in. */
class EventTeamMember extends Model
{
    protected $fillable = ['team_id', 'user_id', 'name', 'mobile', 'role', 'note', 'sort'];

    public const ROLES = [
        'ghat_pramukh' => 'Ghat Pramukh',
        'ghat_saha_pramukh' => 'Ghat Saha Pramukh',
        'ghat_palak' => 'Ghat Palak',
        'pramukh' => 'Pramukh',
        'saha_pramukh' => 'Saha Pramukh',
        'volunteer' => 'Volunteer',
    ];

    public function team(): BelongsTo
    {
        return $this->belongsTo(EventTeam::class, 'team_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function isHead(): bool
    {
        return in_array($this->role, ['ghat_pramukh', 'ghat_saha_pramukh', 'ghat_palak', 'pramukh', 'saha_pramukh'], true);
    }

    /** Link this row to the account with the same mobile number, if there is one. */
    public function linkByMobile(): void
    {
        if ($this->user_id || ! $this->mobile) {
            return;
        }
        $this->user_id = User::where('mobile', $this->mobile)->where('status', '!=', 'deleted')->value('id');
    }

    /** Link every unlinked row with this account's number (called when someone signs in or up). */
    public static function linkUser(User $user): void
    {
        if (! str_starts_with((string) $user->mobile, '+')) {
            return;
        }
        static::whereNull('user_id')->where('mobile', $user->mobile)->update(['user_id' => $user->id]);
    }

    public function setMobileAttribute(?string $value): void
    {
        $this->attributes['mobile'] = $value ? (Mobile::normalize($value) ?? $value) : null;
    }
}
