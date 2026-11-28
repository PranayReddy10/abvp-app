<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\EventRegistration;
use App\Models\EventTeamMember;
use App\Models\GuideItem;
use App\Models\MemberProfile;
use App\Models\Post;
use App\Models\Setting;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;

/**
 * One search box for the website and the app. What comes back depends on who asks, with the same
 * rules as everywhere else:
 *  - everyone: published, upcoming events;
 *  - signed in: members, conference volunteers and community posts they can already see;
 *  - delegates: places in the conference guide of the events they registered for.
 */
class SearchController extends Controller
{
    private const LIMIT = 8;

    public function search(Request $request)
    {
        $request->validate(['q' => ['required', 'string', 'min:2', 'max:60']]);
        $q = trim((string) $request->input('q'));
        $like = '%'.addcslashes($q, '%_\\').'%';
        $viewer = $request->user('sanctum');

        $events = Event::where('status', 'published')->where('ends_at', '>=', now())
            ->where(fn ($w) => $w->where('title', 'like', $like)->orWhere('venue', 'like', $like)->orWhere('description', 'like', $like))
            ->orderBy('starts_at')->limit(self::LIMIT)->get()
            ->map(fn (Event $e) => [
                'id' => $e->id, 'title' => $e->title, 'venue' => $e->venue,
                'starts_at' => $e->starts_at->toIso8601String(), 'ends_at' => $e->ends_at->toIso8601String(),
            ])->values();

        $out = ['q' => $q, 'signed_in' => (bool) $viewer, 'events' => $events, 'guide' => [], 'people' => [], 'members' => [], 'posts' => []];
        if (! $viewer) {
            return $this->ok($out);
        }

        // Guide places: only for events this person registered for as a delegate (or member).
        $eventIds = EventRegistration::where('user_id', $viewer->id)
            ->whereNotIn('status', [EventRegistration::CANCELLED, EventRegistration::REJECTED])->pluck('event_id');
        if ($eventIds->isNotEmpty()) {
            $kinds = config('abvp.guide_kinds');
            $out['guide'] = GuideItem::whereIn('event_id', $eventIds)
                ->where(fn ($w) => $w->where('title', 'like', $like)->orWhere('subtitle', 'like', $like)
                    ->orWhere('location', 'like', $like)->orWhere('region', 'like', $like)->orWhere('description', 'like', $like))
                ->orderBy('kind')->orderBy('sort')->limit(12)->get()
                ->map(fn (GuideItem $i) => [
                    'id' => $i->id, 'event_id' => $i->event_id, 'kind' => $i->kind,
                    'kind_label' => $kinds[$i->kind]['title'] ?? Str::headline($i->kind),
                    'title' => $i->title, 'subtitle' => $i->subtitle ?: $i->location, 'region' => $i->region,
                ])->values();
        }

        // Conference volunteers, the same people the Volunteer page shows to signed-in users.
        $out['people'] = EventTeamMember::with('team.parent', 'user.profile')
            ->whereHas('team.event', fn ($e) => $e->where('status', 'published')->where('ends_at', '>=', now()->subDays(7)))
            ->where(fn ($w) => $w->where('name', 'like', $like)->orWhereHas('team', fn ($t) => $t->where('name', 'like', $like)))
            ->orderBy('name')->limit(self::LIMIT)->get()
            ->map(fn (EventTeamMember $m) => [
                'id' => $m->id, 'name' => $m->name, 'role' => Str::headline(str_replace('_', ' ', (string) $m->role)),
                'team' => $m->team?->name, 'ghat' => $m->team?->parent?->name, 'event_id' => $m->team?->event_id,
                'mobile' => $m->mobile, 'member_id' => $m->user?->profile?->member_id, 'linked' => $m->user_id !== null,
                'verified' => (bool) $m->user?->profile?->isVerified(),
            ])->values();

        // Members by name, member ID or college – everyone who signed up is a member.
        $out['members'] = MemberProfile::where('membership_status', MemberProfile::STATUS_APPROVED)
            ->where(fn ($w) => $w->where('full_name', 'like', $like)->orWhere('member_id', $q)->orWhere('institution', 'like', $like))
            ->with('orgUnit')->orderBy('full_name')->limit(self::LIMIT)->get()
            ->map(fn (MemberProfile $p) => [
                'member_id' => $p->member_id, 'name' => $p->full_name, 'verified' => $p->isVerified(), 'place' => $p->orgUnit?->name,
                'photo_url' => $p->photo_path ? URL::temporarySignedRoute('media.photo', now()->addMinutes(30), ['profile' => $p->id]) : null,
            ])->values();

        // Community posts this person can already see in their feed.
        $out['posts'] = Post::visibleTo($viewer)->whereNull('hidden_at')->whereNull('repost_of_id')
            ->where('body', 'like', $like)->with('author.profile')->latest('id')->limit(self::LIMIT)->get()
            ->map(fn (Post $p) => [
                'id' => $p->id, 'body' => Str::limit((string) $p->body, 160),
                'author' => $p->author?->profile?->full_name ?: $p->author?->name,
                'verified' => (bool) $p->author?->profile?->isVerified(),
                'at' => $p->created_at->toIso8601String(),
            ])->values();

        return $this->ok($out);
    }

    /** Public site settings the website reads at start: analytics ID and search-engine verification. */
    public function site()
    {
        $s = Setting::allValues();

        return $this->ok([
            'ga_id' => $s['analytics.ga_id'] ?? null,
            'google_verification' => $s['seo.google_verification'] ?? null,
            'bing_verification' => $s['seo.bing_verification'] ?? null,
        ]);
    }
}
