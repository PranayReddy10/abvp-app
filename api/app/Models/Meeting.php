<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Meeting extends Model
{
    protected $fillable = [
        'kind', 'title', 'agenda', 'mode', 'link', 'provider', 'venue', 'starts_at', 'ends_at',
        'organiser_id', 'org_unit_id', 'vibhag_id', 'status', 'minutes',
    ];

    protected function casts(): array
    {
        return [
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'reminded_day_at' => 'datetime',
            'reminded_soon_at' => 'datetime',
        ];
    }

    public function organiser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'organiser_id');
    }

    public function orgUnit(): BelongsTo
    {
        return $this->belongsTo(OrgUnit::class);
    }

    public function vibhag(): BelongsTo
    {
        return $this->belongsTo(Vibhag::class);
    }

    public function invitees(): HasMany
    {
        return $this->hasMany(MeetingInvitee::class);
    }

    public function actionItems(): HasMany
    {
        return $this->hasMany(ActionItem::class)->orderBy('id');
    }

    public function involves(User $user): bool
    {
        return $this->organiser_id === $user->id || $this->invitees()->where('user_id', $user->id)->exists();
    }

    /** Recognise the service from the link so the app can label the Join button. */
    public static function providerFor(?string $url): ?string
    {
        if (! $url) {
            return null;
        }
        $host = strtolower((string) parse_url($url, PHP_URL_HOST));

        return match (true) {
            str_ends_with($host, 'meet.google.com') => 'google_meet',
            str_ends_with($host, 'zoom.us'), str_ends_with($host, 'zoom.com') => 'zoom',
            str_contains($host, 'teams.microsoft.com'), str_contains($host, 'teams.live.com') => 'teams',
            str_ends_with($host, 'meet.jit.si') => 'jitsi',
            str_ends_with($host, 'youtube.com'), $host === 'youtu.be' => 'youtube',
            default => 'link',
        };
    }
}
