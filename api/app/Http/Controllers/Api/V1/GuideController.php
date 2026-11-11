<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\EventDuty;
use App\Models\EventRegistration;
use App\Models\EventStaff;
use App\Models\GuideItem;
use App\Models\HelpRequest;
use App\Models\User;
use App\Services\EventService;
use App\Services\GuidePresenter;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\URL;

/** The conference guide delegates see: stay, transport, food, offices and more, with whom to call. */
class GuideController extends Controller
{
    public function __construct(private EventService $events) {}

    /** Events with a guide that I take part in and that have not ended. */
    public function myEvents(Request $request)
    {
        $user = $request->user();
        $ids = EventRegistration::where('user_id', $user->id)->where('status', 'registered')->pluck('event_id')
            ->merge(EventStaff::where('user_id', $user->id)->pluck('event_id'))
            ->merge(EventDuty::where('assignee_id', $user->id)->pluck('event_id'))->unique();

        $rows = Event::whereIn('id', $ids)->where('guide_enabled', true)->where('status', 'published')
            ->where('ends_at', '>', now())->orderBy('starts_at')->get();

        return $this->ok($rows->map(fn (Event $e) => $this->summary($e)));
    }

    public function hub(Request $request, Event $event)
    {
        $user = $request->user();
        $this->guard($user, $event);
        $counts = GuideItem::where('event_id', $event->id)->selectRaw('kind, count(*) n')->groupBy('kind')->pluck('n', 'kind');
        $myRegion = $this->myRegion($user);

        return $this->ok($this->summary($event) + [
            'sections' => collect(GuidePresenter::kinds())->map(fn ($k) => $k + ['count' => (int) ($counts[$k['kind']] ?? 0)])->values(),
            'my_region' => $myRegion,
            'my_stays' => $myRegion
                ? GuideItem::where('event_id', $event->id)->where('kind', 'stay')->where('region', $myRegion)->with('contacts.user.profile')->orderBy('sort')->get()
                    ->map(fn ($i) => GuidePresenter::item($i, $event))->values()
                : [],
            'open_tickets' => HelpRequest::where('event_id', $event->id)->where('raised_by', $user->id)->whereNotIn('status', ['resolved', 'closed'])->count(),
            'help_categories' => collect(HelpRequest::CATEGORIES)->map(fn ($label, $key) => ['key' => $key, 'label' => $label])->values(),
        ]);
    }

    public function section(Request $request, Event $event, string $kind)
    {
        abort_unless(array_key_exists($kind, config('abvp.guide_kinds')), 404);
        $this->guard($request->user(), $event);
        $items = GuideItem::where('event_id', $event->id)->where('kind', $kind)
            ->with('contacts.user.profile')->orderBy('sort')->orderBy('id')->get();

        return $this->ok($items->map(fn ($i) => GuidePresenter::item($i, $event))->values(), meta: [
            'kind' => $kind,
            'regions' => $kind === 'stay' ? $items->groupBy('region')->map(fn ($g, $r) => ['region' => $r, 'count' => $g->count()])->sortKeys()->values() : null,
        ]);
    }

    private function summary(Event $e): array
    {
        $now = now();

        return [
            'event' => [
                'id' => $e->id,
                'title' => $e->title,
                'venue' => $e->venue,
                'venue_map_url' => $e->venue_map_url,
                'venue_lat' => $e->venue_lat,
                'venue_lng' => $e->venue_lng,
                'starts_at' => $e->starts_at->toIso8601String(),
                'ends_at' => $e->ends_at->toIso8601String(),
                'cover_url' => $e->cover_path ? URL::temporarySignedRoute('media.event', now()->addDay(), ['event' => $e->id]) : null,
                'helpline' => $e->helpline_phone ?: $e->contact_phone,
                'contact_name' => $e->contact_name,
            ],
            // The app opens the guide first from two days before the event until it ends.
            'open_first' => $now->gte($e->starts_at->copy()->subDays(2)) && $now->lt($e->ends_at),
            'live' => $now->between($e->starts_at, $e->ends_at),
        ];
    }

    /** The ABVP prant to suggest for "my stay": the state above the member's unit. */
    private function myRegion(User $user): ?string
    {
        $unit = $user->profile?->orgUnit;
        $state = $unit?->ancestorOfType('state') ?? ($unit?->type === 'state' ? $unit : null);

        return $state?->name;
    }

    private function guard(User $user, Event $event): void
    {
        abort_unless($event->guide_enabled && $event->status === 'published', 404);
        $in = EventRegistration::where('event_id', $event->id)->where('user_id', $user->id)->where('status', 'registered')->exists()
            || EventStaff::where('event_id', $event->id)->where('user_id', $user->id)->exists()
            || EventDuty::where('event_id', $event->id)->where('assignee_id', $user->id)->exists()
            || $this->events->canCoordinate($user, $event);
        if (! $in) {
            throw new ApiException('NOT_PARTICIPANT', 'The conference guide opens once your registration is confirmed.', 403);
        }
    }
}
