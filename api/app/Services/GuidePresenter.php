<?php

namespace App\Services;

use App\Models\Event;
use App\Models\GuideItem;
use Illuminate\Support\Facades\URL;

/** Turns guide items into what the app and admin panel show. */
class GuidePresenter
{
    public static function item(GuideItem $i, Event $event, bool $withPhones = true): array
    {
        [$distance, $source] = self::distance($i, $event);

        return [
            'id' => $i->id,
            'kind' => $i->kind,
            'title' => $i->title,
            'subtitle' => $i->subtitle,
            'region' => $i->region,
            'description' => $i->description,
            'location' => $i->location,
            'landmark' => $i->landmark,
            'color' => $i->color,
            'timings' => $i->timings,
            'tags' => $i->tags ?? [],
            'steps' => $i->steps ?? [],
            'map_url' => $i->map_url,
            'lat' => $i->lat,
            'lng' => $i->lng,
            'distance_km' => $distance,
            'distance_is_road' => $source === 'road',
            'travel_time' => $i->travel_time,
            'directions_url' => self::directions($i, $event),
            'photo_urls' => collect($i->photos ?? [])->keys()
                ->map(fn ($k) => URL::temporarySignedRoute('media.guide', now()->addHours(6), ['item' => $i->id, 'index' => $k]))->values(),
            'videos' => collect($i->videos ?? [])->map(fn ($v, $k) => self::video($i, $v, $k))->values(),
            'contacts' => $i->contacts->map(fn ($c) => [
                'id' => $c->id,
                'name' => $c->name,
                'role' => $c->role,
                'is_lead' => $c->is_lead,
                'member_id' => $c->user?->profile?->member_id,
                'verified' => (bool) $c->user?->profile?->isVerified(),
                // Help contacts volunteered to be reached; shown to people taking part.
                'phone' => $withPhones ? ($c->phone ?: $c->user?->mobile) : null,
            ])->values(),
            'sort' => $i->sort,
        ];
    }

    /** @return array{0: float|null, 1: string|null} road distance if entered, else straight-line from map pins */
    public static function distance(GuideItem $i, Event $event): array
    {
        if ($i->distance_km !== null) {
            return [$i->distance_km, 'road'];
        }
        if ($i->lat === null || $i->lng === null || $event->venue_lat === null || $event->venue_lng === null) {
            return [null, null];
        }
        $r = 6371;
        $dLat = deg2rad($event->venue_lat - $i->lat);
        $dLng = deg2rad($event->venue_lng - $i->lng);
        $a = sin($dLat / 2) ** 2 + cos(deg2rad($i->lat)) * cos(deg2rad($event->venue_lat)) * sin($dLng / 2) ** 2;

        return [round($r * 2 * atan2(sqrt($a), sqrt(1 - $a)), 1), 'straight'];
    }

    public static function directions(GuideItem $i, Event $event): ?string
    {
        $venue = $event->venue_lat !== null ? "{$event->venue_lat},{$event->venue_lng}" : $event->venue;
        $here = $i->lat !== null ? "{$i->lat},{$i->lng}" : null;

        // From a station or airport to the venue; everything else: from wherever you are to the place.
        if ($i->kind === 'arrival' && $here && $venue) {
            return 'https://www.google.com/maps/dir/?api=1&origin='.urlencode($here).'&destination='.urlencode($venue).'&travelmode=transit';
        }
        if ($here) {
            return 'https://www.google.com/maps/dir/?api=1&destination='.urlencode($here);
        }

        return $i->map_url;
    }

    /** A gallery video: an uploaded clip (signed link) or a link, with a YouTube thumbnail when we can. */
    public static function video(GuideItem $i, array $v, int $k): array
    {
        $url = ! empty($v['path'])
            ? URL::temporarySignedRoute('media.guideVideo', now()->addHours(6), ['item' => $i->id, 'index' => $k])
            : ($v['url'] ?? null);
        $yt = null;
        if (! empty($v['url']) && preg_match('~(?:youtu\.be/|youtube\.com/(?:watch\?v=|shorts/|embed/|live/))([A-Za-z0-9_-]{11})~', $v['url'], $m)) {
            $yt = $m[1];
        }

        return [
            'url' => $url,
            'title' => $v['title'] ?? null,
            'kind' => ! empty($v['path']) ? 'file' : ($yt ? 'youtube' : 'link'),
            'thumb_url' => $yt ? "https://img.youtube.com/vi/$yt/hqdefault.jpg" : null,
        ];
    }

    public static function kinds(): array
    {
        return collect(config('abvp.guide_kinds'))->map(fn ($k, $key) => ['kind' => $key] + $k)->values()->all();
    }
}
