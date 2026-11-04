<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Event;
use App\Models\EventRegistration as Reg;
use App\Models\EventStaff;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\User;
use App\Services\AccessControl;
use App\Services\Audit;
use App\Services\EventService;
use App\Support\ApiException;
use App\Support\Mobile;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class EventController extends Controller
{
    public function __construct(private AccessControl $access, private EventService $events) {}

    public function index(Request $request)
    {
        $this->authorizeIn('events.manage');
        $request->validate(['when' => ['nullable', 'in:upcoming,past,draft']]);
        $when = $request->input('when', 'upcoming');

        $page = $this->access->scopeQuery(Event::query(), $request->user(), 'events.manage')
            ->with('orgUnit')
            ->withCount([
                'registrations as registered_count' => fn ($q) => $q->where('status', Reg::REGISTERED),
                'registrations as pending_count' => fn ($q) => $q->where('status', Reg::PENDING),
                'registrations as waitlisted_count' => fn ($q) => $q->where('status', Reg::WAITLISTED),
                'registrations as arrived_count' => fn ($q) => $q->whereNotNull('checked_in_at'),
            ])
            ->when($when === 'draft', fn ($q) => $q->where('status', 'draft')->latest('id'))
            ->when($when === 'upcoming', fn ($q) => $q->where('status', '!=', 'draft')->where('ends_at', '>=', now())->orderBy('starts_at'))
            ->when($when === 'past', fn ($q) => $q->where('status', '!=', 'draft')->where('ends_at', '<', now())->orderByDesc('starts_at'))
            ->paginate(25);

        return $this->ok($page->getCollection()->map(fn (Event $e) => [
            'id' => $e->id,
            'title' => $e->title,
            'category_label' => Event::CATEGORIES[$e->category] ?? $e->category,
            'status' => $e->status,
            'starts_at' => $e->starts_at->toIso8601String(),
            'ends_at' => $e->ends_at->toIso8601String(),
            'venue' => $e->venue,
            'organised_by' => $e->orgUnit->name,
            'capacity' => $e->capacity,
            'registered' => $e->registered_count,
            'pending' => $e->pending_count,
            'waitlisted' => $e->waitlisted_count,
            'arrived' => $e->arrived_count,
        ]), meta: ['page' => $page->currentPage(), 'last_page' => $page->lastPage()]);
    }

    public function show(Request $request, Event $event)
    {
        $this->guard($request, $event);
        $event->load('orgUnit', 'organiser.profile', 'rules.orgUnit', 'rules.vibhag');

        return $this->ok($this->detail($event));
    }

    public function store(Request $request)
    {
        $data = $this->validated($request);
        $unit = OrgUnit::findOrFail($data['org_unit_id']);
        if (! $this->access->canIn($request->user(), 'events.manage', $unit)) {
            throw new ApiException('FORBIDDEN_SCOPE', 'You can only create events for your own area.', 403);
        }

        $event = DB::transaction(function () use ($data, $request) {
            $event = Event::create(collect($data)->except('rules')->all() + ['organiser_id' => $request->user()->id]);
            $this->syncRules($event, $data['rules'] ?? []);

            return $event;
        });
        Audit::record('event.created', $event, null, ['title' => $event->title]);

        return $this->ok($this->detail($event->load('orgUnit', 'organiser.profile', 'rules.orgUnit', 'rules.vibhag')), 201);
    }

    public function update(Request $request, Event $event)
    {
        $this->guard($request, $event);
        if (in_array($event->status, ['cancelled', 'completed'], true)) {
            throw new ApiException('EVENT_CLOSED', 'A cancelled or finished event cannot be edited.');
        }
        $data = $this->validated($request, partial: true);

        $before = $event->only(['starts_at', 'ends_at', 'venue']);
        DB::transaction(function () use ($event, $data) {
            $event->update(collect($data)->except(['rules', 'org_unit_id'])->all());
            if (array_key_exists('rules', $data)) {
                $this->syncRules($event, $data['rules'] ?? []);
            }
            if (isset($data['capacity'])) {
                $this->events->promoteWaitlist($event->fresh());
            }
        });

        // Tell registered people when the time or place changes.
        $event->refresh();
        $changed = $event->status === 'published' && ($before['venue'] !== $event->venue || ! $before['starts_at']->eq($event->starts_at));
        if ($changed) {
            AppNotification::sendMany($this->activeUserIds($event), 'event_changed', "Changed: {$event->title}",
                $event->starts_at->timezone('Asia/Kolkata')->format('D j M, g:i A').' · '.$event->venue, ['event_id' => $event->id]);
        }
        Audit::record('event.updated', $event, null, collect($data)->except('rules')->all());

        return $this->ok($this->detail($event->load('orgUnit', 'organiser.profile', 'rules.orgUnit', 'rules.vibhag')) + ['notified' => $changed]);
    }

    public function publish(Request $request, Event $event)
    {
        $this->guard($request, $event);
        if ($event->status !== 'draft') {
            throw new ApiException('NOT_DRAFT', 'Only a draft can be published.');
        }
        $event->forceFill(['status' => 'published', 'published_at' => now()])->save();
        Audit::record('event.published', $event);

        return $this->ok($this->detail($event->load('orgUnit', 'organiser.profile', 'rules.orgUnit', 'rules.vibhag')));
    }

    public function cancel(Request $request, Event $event)
    {
        $request->validate(['reason' => ['required', 'string', 'min:5', 'max:300']]);
        $this->guard($request, $event);

        $event->forceFill(['status' => 'cancelled'])->save();
        AppNotification::sendMany($this->activeUserIds($event), 'event_cancelled', "Cancelled: {$event->title}", $request->input('reason'), ['event_id' => $event->id]);
        Audit::record('event.cancelled', $event, null, ['reason' => $request->input('reason')]);

        return $this->ok($this->detail($event->load('orgUnit', 'organiser.profile', 'rules.orgUnit', 'rules.vibhag')));
    }

    public function registrations(Request $request, Event $event)
    {
        $this->guard($request, $event);
        $request->validate([
            'status' => ['nullable', 'in:registered,waitlisted,pending,cancelled,rejected,arrived,not_arrived'],
            'kind' => ['nullable', 'in:member,guest'],
            'q' => ['nullable', 'string', 'max:60'],
        ]);

        $query = Reg::where('event_id', $event->id)->with('user.profile.orgUnit')->orderBy('id')
            ->when($request->input('kind'), fn ($q, $k) => $q->where('kind', $k))
            ->when($request->input('status'), fn ($q, $s) => match ($s) {
                'arrived' => $q->whereNotNull('checked_in_at'),
                'not_arrived' => $q->where('status', Reg::REGISTERED)->whereNull('checked_in_at'),
                default => $q->where('status', $s),
            })
            ->when($request->input('q'), fn ($q, $s) => $q->where(fn ($w) => $w->where('guest_name', 'like', "%$s%")
                ->orWhereHas('user', fn ($u) => $u->where('mobile', 'like', "%$s%")->orWhereHas('profile', fn ($p) => $p->where('full_name', 'like', "%$s%")))));

        $page = $query->paginate(50);

        return $this->ok($page->getCollection()->map(fn (Reg $r) => [
            'id' => $r->id,
            'name' => $r->displayName(),
            'kind' => $r->kind,
            'member_id' => $r->user?->profile?->member_id,
            'mobile' => $r->user ? Mobile::mask($r->user->mobile) : null,
            'place' => $r->kind === 'guest' ? $r->guest_organisation : $r->user?->profile?->orgUnit?->name,
            'status' => $r->status,
            'registered_at' => $r->created_at?->toIso8601String(),
            'checked_in_at' => $r->checked_in_at?->toIso8601String(),
            'gate' => $r->gate,
            'method' => $r->check_in_method,
        ]), meta: ['page' => $page->currentPage(), 'last_page' => $page->lastPage(), 'total' => $page->total()]);
    }

    public function decide(Request $request, Event $event, Reg $registration)
    {
        $data = $request->validate(['decision' => ['required', 'in:approve,reject'], 'note' => ['nullable', 'required_if:decision,reject', 'string', 'max:300']]);
        $this->guard($request, $event);
        if ($registration->event_id !== $event->id || $registration->status !== Reg::PENDING) {
            throw new ApiException('NOT_PENDING', 'Only registrations waiting for approval can be decided.');
        }

        $approve = $data['decision'] === 'approve';
        $registration->update(['status' => $approve ? Reg::REGISTERED : Reg::REJECTED, 'decision_note' => $data['note'] ?? null]);
        if (! $approve) {
            $this->events->promoteWaitlist($event);
        }
        AppNotification::sendMany([$registration->user_id], 'event_registration_decided',
            $approve ? "Confirmed: {$event->title}" : "Not approved: {$event->title}", $data['note'] ?? null, ['event_id' => $event->id]);

        return $this->ok(['status' => $registration->status]);
    }

    /** Invite a guest by mobile. They sign in with OTP and see only this invitation and pass. */
    public function inviteGuest(Request $request, Event $event)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'mobile' => ['required', 'string', 'max:20'],
            'organisation' => ['nullable', 'string', 'max:160'],
        ]);
        $this->guard($request, $event);
        if (in_array($event->status, ['cancelled', 'completed'], true)) {
            throw new ApiException('EVENT_CLOSED', 'This event is closed.');
        }

        $mobile = Mobile::normalize($data['mobile']) ?? throw new ApiException('INVALID_MOBILE', 'Enter a valid 10-digit Indian mobile number.');
        $user = User::firstOrCreate(['mobile' => $mobile], ['name' => $data['name']]);

        $reg = Reg::where('event_id', $event->id)->where('user_id', $user->id)->first();
        if ($reg && ! in_array($reg->status, [Reg::CANCELLED, Reg::REJECTED], true)) {
            throw new ApiException('ALREADY_REGISTERED', 'This number is already on the list for this event.', 409);
        }

        // Guests are invited personally, so they take a seat even when the event is full.
        $reg ??= new Reg(['event_id' => $event->id, 'user_id' => $user->id]);
        $reg->fill(['kind' => 'guest', 'status' => Reg::REGISTERED, 'guest_name' => $data['name'], 'guest_organisation' => $data['organisation'] ?? null, 'invited_by' => $request->user()->id])->save();

        AppNotification::sendMany([$user->id], 'event_guest_invite', "You're invited: {$event->title}",
            $event->starts_at->timezone('Asia/Kolkata')->format('D j M, g:i A').' · '.$event->venue, ['event_id' => $event->id]);
        Audit::record('event.guest_invited', $reg, null, ['name' => $data['name']]);

        return $this->ok(['id' => $reg->id, 'sign_in_mobile' => Mobile::mask($mobile)], 201);
    }

    public function staff(Request $request, Event $event)
    {
        $this->guard($request, $event);

        return $this->ok(EventStaff::where('event_id', $event->id)->with('user.profile')->get()->map(fn ($s) => [
            'id' => $s->id, 'role' => $s->role, 'name' => $s->user->profile?->full_name, 'member_id' => $s->user->profile?->member_id,
        ]));
    }

    public function addStaff(Request $request, Event $event)
    {
        $data = $request->validate(['member_id' => ['required', 'exists:member_profiles,member_id'], 'role' => ['required', 'in:scanner,coordinator']]);
        $this->guard($request, $event);
        $userId = MemberProfile::where('member_id', $data['member_id'])->where('membership_status', 'approved')->value('user_id')
            ?? throw new ApiException('NOT_A_MEMBER', 'Only approved members can be on the event team.');

        $s = EventStaff::updateOrCreate(['event_id' => $event->id, 'user_id' => $userId], ['role' => $data['role']]);
        AppNotification::sendMany([$userId], 'event_staff', "You're on the gate team: {$event->title}", 'Open Me › Gate check-in in the app on the day.', ['event_id' => $event->id]);

        return $this->ok(['id' => $s->id], 201);
    }

    public function removeStaff(Request $request, Event $event, EventStaff $staff)
    {
        $this->guard($request, $event);
        abort_unless($staff->event_id === $event->id, 404);
        $staff->delete();

        return $this->ok(['removed' => true]);
    }

    /** Arrivals right now. The admin page polls this every 15 seconds. */
    public function live(Request $request, Event $event)
    {
        $this->guard($request, $event);
        $regs = Reg::where('event_id', $event->id)->where('status', Reg::REGISTERED)->get(['id', 'kind', 'checked_in_at', 'gate', 'check_in_method', 'guest_name', 'user_id']);
        $arrived = $regs->whereNotNull('checked_in_at');

        // Arrivals in 30-minute buckets from the first arrival (or the start) to now.
        $first = $arrived->min('checked_in_at') ?? $event->starts_at;
        $from = Carbon::parse($first)->copy()->setTime(Carbon::parse($first)->hour, Carbon::parse($first)->minute >= 30 ? 30 : 0);
        $until = now()->min($event->ends_at)->max($from->copy()->addMinutes(30));
        $buckets = [];
        for ($t = $from->copy(); $t->lt($until) && count($buckets) < 48; $t->addMinutes(30)) {
            $end = $t->copy()->addMinutes(30);
            $buckets[] = ['at' => $t->toIso8601String(), 'count' => $arrived->filter(fn ($r) => $r->checked_in_at->gte($t) && $r->checked_in_at->lt($end))->count()];
        }

        $recent = Reg::where('event_id', $event->id)->whereNotNull('checked_in_at')->with('user.profile.orgUnit')->latest('checked_in_at')->limit(10)->get();

        return $this->ok([
            'expected' => ['members' => $regs->where('kind', 'member')->count(), 'guests' => $regs->where('kind', 'guest')->count()],
            'arrived' => ['members' => $arrived->where('kind', 'member')->count(), 'guests' => $arrived->where('kind', 'guest')->count()],
            'pending_approval' => Reg::where('event_id', $event->id)->where('status', Reg::PENDING)->count(),
            'waitlisted' => Reg::where('event_id', $event->id)->where('status', Reg::WAITLISTED)->count(),
            'by_gate' => $arrived->groupBy(fn ($r) => $r->gate ?: 'No gate given')->map(fn ($g, $k) => ['gate' => $k, 'count' => $g->count()])->sortByDesc('count')->values(),
            'by_method' => $arrived->groupBy('check_in_method')->map->count(),
            'timeline' => $buckets,
            'recent' => $recent->map(fn (Reg $r) => [
                'name' => $r->displayName(), 'kind' => $r->kind, 'gate' => $r->gate,
                'place' => $r->kind === 'guest' ? $r->guest_organisation : $r->user?->profile?->orgUnit?->name,
                'at' => $r->checked_in_at->toIso8601String(),
            ]),
            'updated_at' => now()->toIso8601String(),
        ]);
    }

    private function validated(Request $request, bool $partial = false): array
    {
        $req = $partial ? 'sometimes' : 'required';

        $data = $request->validate([
            'title' => [$req, 'string', 'max:200'],
            'description' => ['nullable', 'string', 'max:5000'],
            'category' => [$req, Rule::in(array_keys(Event::CATEGORIES))],
            'instructions' => ['nullable', 'string', 'max:3000'],
            'venue' => [$req, 'string', 'max:250'],
            'venue_map_url' => ['nullable', 'url:https', 'max:500'],
            'starts_at' => [$req, 'date'],
            'ends_at' => [$req, 'date', 'after:starts_at'],
            'org_unit_id' => [$partial ? 'prohibited' : 'required', 'integer', 'exists:org_units,id'],
            'registration_opens_at' => ['nullable', 'date'],
            'registration_closes_at' => ['nullable', 'date'],
            'capacity' => ['nullable', 'integer', 'min:1', 'max:200000'],
            'requires_approval' => ['sometimes', 'boolean'],
            'waitlist_enabled' => ['sometimes', 'boolean'],
            'contact_name' => ['nullable', 'string', 'max:120'],
            'contact_phone' => ['nullable', 'string', 'max:20'],
            'rules' => ['nullable', 'array', 'max:20'],
            'rules.*.org_unit_id' => ['nullable', 'integer', 'exists:org_units,id'],
            'rules.*.vibhag_id' => ['nullable', 'integer', 'exists:vibhags,id'],
        ]);

        // Store in UTC whatever offset the browser or phone sent.
        foreach (['starts_at', 'ends_at', 'registration_opens_at', 'registration_closes_at'] as $k) {
            if (! empty($data[$k])) {
                $data[$k] = Carbon::parse($data[$k])->utc();
            }
        }

        return $data;
    }

    private function syncRules(Event $event, array $rules): void
    {
        $event->rules()->delete();
        foreach ($rules as $r) {
            if (! empty($r['org_unit_id']) || ! empty($r['vibhag_id'])) {
                $event->rules()->create(['org_unit_id' => $r['org_unit_id'] ?? null, 'vibhag_id' => $r['vibhag_id'] ?? null]);
            }
        }
    }

    private function guard(Request $request, Event $event): void
    {
        if (! $this->access->canIn($request->user(), 'events.manage', $event->orgUnit)) {
            throw new ApiException('FORBIDDEN_SCOPE', 'This event is outside your area.', 403);
        }
    }

    private function activeUserIds(Event $event)
    {
        return Reg::where('event_id', $event->id)->whereIn('status', [Reg::REGISTERED, Reg::PENDING, Reg::WAITLISTED])->pluck('user_id');
    }

    private function detail(Event $e): array
    {
        $counts = Reg::where('event_id', $e->id)->selectRaw('status, kind, count(*) n')->groupBy('status', 'kind')->get();
        $n = fn ($status, $kind = null) => (int) $counts->where('status', $status)->when($kind, fn ($c) => $c->where('kind', $kind))->sum('n');

        return [
            'id' => $e->id,
            'title' => $e->title,
            'description' => $e->description,
            'category' => $e->category,
            'category_label' => Event::CATEGORIES[$e->category] ?? $e->category,
            'instructions' => $e->instructions,
            'venue' => $e->venue,
            'venue_map_url' => $e->venue_map_url,
            'starts_at' => $e->starts_at->toIso8601String(),
            'ends_at' => $e->ends_at->toIso8601String(),
            'status' => $e->status,
            'org_unit' => ['id' => $e->orgUnit->id, 'name' => $e->orgUnit->name],
            'organiser' => $e->organiser?->profile?->full_name,
            'registration_opens_at' => $e->registration_opens_at?->toIso8601String(),
            'registration_closes_at' => $e->registration_closes_at?->toIso8601String(),
            'capacity' => $e->capacity,
            'requires_approval' => $e->requires_approval,
            'waitlist_enabled' => $e->waitlist_enabled,
            'contact_name' => $e->contact_name,
            'contact_phone' => $e->contact_phone,
            'rules' => $e->rules->map(fn ($r) => ['org_unit_id' => $r->org_unit_id, 'vibhag_id' => $r->vibhag_id, 'label' => $r->describe()]),
            'counts' => [
                'members' => $n(Reg::REGISTERED, 'member'),
                'guests' => $n(Reg::REGISTERED, 'guest'),
                'pending' => $n(Reg::PENDING),
                'waitlisted' => $n(Reg::WAITLISTED),
                'cancelled' => $n(Reg::CANCELLED),
                'arrived' => Reg::where('event_id', $e->id)->whereNotNull('checked_in_at')->count(),
            ],
        ];
    }
}
