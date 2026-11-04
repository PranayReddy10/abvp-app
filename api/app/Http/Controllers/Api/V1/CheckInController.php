<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\EventRegistration as Reg;
use App\Models\EventStaff;
use App\Services\AccessControl;
use App\Services\EventService;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\URL;

/** Gate check-in for event staff: scan, manual search, and offline batches. */
class CheckInController extends Controller
{
    public function __construct(private EventService $events) {}

    /** Events this person can scan for, from yesterday onwards. */
    public function myEvents(Request $request, AccessControl $access)
    {
        $user = $request->user();
        $staffIds = EventStaff::where('user_id', $user->id)->pluck('event_id');

        $events = Event::where('status', 'published')->where('ends_at', '>=', now()->subDay())
            ->where(fn ($q) => $q->whereIn('id', $staffIds)
                ->orWhereIn('id', $access->scopeQuery(Event::query(), $user, 'events.manage')->select('id')))
            ->orderBy('starts_at')->limit(20)->get();

        return $this->ok($events->map(fn (Event $e) => [
            'id' => $e->id,
            'title' => $e->title,
            'venue' => $e->venue,
            'starts_at' => $e->starts_at->toIso8601String(),
            'ends_at' => $e->ends_at->toIso8601String(),
            'is_today' => now()->between($e->starts_at->copy()->startOfDay(), $e->ends_at->copy()->endOfDay()),
        ]));
    }

    /**
     * Confirmed people for the scanner to keep on the phone, so it can show who a
     * pass belongs to with no signal. Arrivals made offline are confirmed on sync.
     */
    public function roster(Request $request, Event $event)
    {
        $this->guard($request, $event);

        $regs = Reg::where('event_id', $event->id)->where('status', Reg::REGISTERED)->with('user.profile.orgUnit')->get();

        return $this->ok($regs->map(fn (Reg $r) => [
            'registration_id' => $r->id,
            'pass_id' => base_convert((string) $r->id, 10, 36),
            'name' => $r->displayName(),
            'kind' => $r->kind,
            'place' => $r->kind === 'guest' ? $r->guest_organisation : $r->user?->profile?->orgUnit?->name,
            'checked_in' => $r->checked_in_at !== null,
        ]), meta: ['generated_at' => now()->toIso8601String()]);
    }

    public function scan(Request $request, Event $event)
    {
        $data = $request->validate(['token' => ['required', 'string', 'max:100'], 'gate' => ['nullable', 'string', 'max:40']]);
        $this->guard($request, $event);

        $reg = $this->events->registrationFromToken($data['token'])
            ?? throw new ApiException('PASS_INVALID', 'This is not a valid ABVP Connect event pass.', 422);

        [$reg, $already] = $this->events->checkIn($request->user(), $event, $reg, $data['gate'] ?? null, 'scan');

        return $this->ok($this->result($reg, $already));
    }

    /** Manual check-in after finding the person by name, for lost phones and dead batteries. */
    public function manual(Request $request, Event $event, Reg $registration)
    {
        $data = $request->validate(['gate' => ['nullable', 'string', 'max:40']]);
        $this->guard($request, $event);

        [$reg, $already] = $this->events->checkIn($request->user(), $event, $registration, $data['gate'] ?? null, 'manual');

        return $this->ok($this->result($reg, $already));
    }

    /** Scans made without signal, sent when the phone is back online. Each item gets its own result. */
    public function batch(Request $request, Event $event)
    {
        $data = $request->validate([
            'items' => ['required', 'array', 'max:500'],
            'items.*.token' => ['required', 'string', 'max:100'],
            'items.*.gate' => ['nullable', 'string', 'max:40'],
            'items.*.scanned_at' => ['nullable', 'date'],
        ]);
        $this->guard($request, $event);

        $results = collect($data['items'])->map(function ($item) use ($request, $event) {
            $reg = $this->events->registrationFromToken($item['token']);
            if (! $reg) {
                return ['token' => $item['token'], 'ok' => false, 'code' => 'PASS_INVALID'];
            }
            try {
                $at = isset($item['scanned_at']) ? Carbon::parse($item['scanned_at'])->utc()->min(now()) : now();
                [$reg, $already] = $this->events->checkIn($request->user(), $event, $reg, $item['gate'] ?? null, 'offline', $at);

                return ['token' => $item['token'], 'ok' => true, 'already' => $already, 'name' => $reg->displayName()];
            } catch (ApiException $e) {
                return ['token' => $item['token'], 'ok' => false, 'code' => $e->errorCode, 'message' => $e->getMessage()];
            }
        });

        return $this->ok($results->values(), meta: ['accepted' => $results->where('ok', true)->count()]);
    }

    /** Search the list by name or mobile for manual check-in. */
    public function search(Request $request, Event $event)
    {
        $request->validate(['q' => ['required', 'string', 'min:2', 'max:60']]);
        $this->guard($request, $event);
        $q = $request->input('q');

        $regs = Reg::where('event_id', $event->id)
            ->where(fn ($w) => $w->where('guest_name', 'like', "%$q%")
                ->orWhereHas('user', fn ($u) => $u->where('mobile', 'like', "%$q%")
                    ->orWhereHas('profile', fn ($p) => $p->where('full_name', 'like', "%$q%")->orWhere('member_id', $q))))
            ->with('user.profile.orgUnit')->limit(20)->get();

        return $this->ok($regs->map(fn ($r) => $this->result($r, $r->checked_in_at !== null) + ['status' => $r->status]));
    }

    private function guard(Request $request, Event $event): void
    {
        if (! $this->events->canStaff($request->user(), $event)) {
            throw new ApiException('NOT_EVENT_STAFF', 'You are not on the check-in team for this event.', 403);
        }
    }

    private function result(Reg $reg, bool $already): array
    {
        $profile = $reg->user?->profile;

        return [
            'registration_id' => $reg->id,
            'already' => $already,
            'name' => $reg->displayName(),
            'kind' => $reg->kind,
            'member_id' => $reg->kind === 'member' ? $profile?->member_id : null,
            'place' => $reg->kind === 'guest' ? $reg->guest_organisation : $profile?->orgUnit?->name,
            'photo_url' => $profile?->photo_path ? URL::temporarySignedRoute('media.photo', now()->addMinutes(10), ['profile' => $profile->id]) : null,
            'checked_in_at' => $reg->checked_in_at?->toIso8601String(),
            'gate' => $reg->gate,
        ];
    }
}
