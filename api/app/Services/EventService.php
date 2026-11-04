<?php

namespace App\Services;

use App\Models\AppNotification;
use App\Models\Event;
use App\Models\EventRegistration as Reg;
use App\Models\EventStaff;
use App\Models\User;
use App\Support\ApiException;
use Illuminate\Support\Facades\DB;

class EventService
{
    public function __construct(private AccessControl $access) {}

    /** @return array{0: bool, 1: string} eligible, and a sentence the member can read */
    public function eligibility(User $user, Event $event): array
    {
        if (! $user->isApprovedMember()) {
            return [false, 'Registration is for approved members.'];
        }

        $rules = $event->rules()->with('orgUnit', 'vibhag')->get();
        if ($rules->isEmpty()) {
            return [true, 'Open to all approved members.'];
        }

        $unit = $user->profile->orgUnit;
        $vibhags = $user->vibhags()->pluck('vibhags.id')->all();

        foreach ($rules as $r) {
            $inUnit = ! $r->orgUnit || ($unit && $r->orgUnit->contains($unit));
            $inVibhag = ! $r->vibhag_id || in_array($r->vibhag_id, $vibhags, true);
            if ($inUnit && $inVibhag) {
                return [true, 'You can register. Open to '.$rules->map->describe()->implode(' or ').'.'];
            }
        }

        return [false, 'Not open to you. This event is for '.$rules->map->describe()->implode(' or ').'.'];
    }

    public function register(User $user, Event $event): Reg
    {
        [$ok, $why] = $this->eligibility($user, $event);
        if (! $ok) {
            throw new ApiException('NOT_ELIGIBLE', $why, 403);
        }
        if (! $event->registrationOpen()) {
            throw new ApiException('REGISTRATION_CLOSED', 'Registration for this event is not open.');
        }

        return DB::transaction(function () use ($user, $event) {
            // Lock the event row so two people cannot take the last seat at once.
            $event = Event::whereKey($event->id)->lockForUpdate()->first();

            $existing = Reg::where('event_id', $event->id)->where('user_id', $user->id)->first();
            if ($existing && ! in_array($existing->status, [Reg::CANCELLED], true)) {
                throw new ApiException('ALREADY_REGISTERED', 'You are already registered for this event.', 409);
            }

            $full = $event->capacity !== null && $event->seatsTaken() >= $event->capacity;
            if ($full && ! $event->waitlist_enabled) {
                throw new ApiException('EVENT_FULL', 'This event is full.', 409);
            }

            $status = $full ? Reg::WAITLISTED : ($event->requires_approval ? Reg::PENDING : Reg::REGISTERED);

            $reg = $existing ?? new Reg(['event_id' => $event->id, 'user_id' => $user->id, 'kind' => 'member']);
            $reg->status = $status;
            $reg->save();

            return $reg;
        });
    }

    /** Frees the seat and moves the first person on the waitlist up. */
    public function cancel(Reg $reg): void
    {
        DB::transaction(function () use ($reg) {
            $event = Event::whereKey($reg->event_id)->lockForUpdate()->first();
            $heldSeat = in_array($reg->status, [Reg::REGISTERED, Reg::PENDING], true);
            $reg->update(['status' => Reg::CANCELLED]);

            if ($heldSeat) {
                $this->promoteWaitlist($event);
            }
        });
    }

    public function promoteWaitlist(Event $event): void
    {
        while ($event->capacity === null || $event->seatsTaken() < $event->capacity) {
            $next = Reg::where('event_id', $event->id)->where('status', Reg::WAITLISTED)->orderBy('id')->first();
            if (! $next) {
                return;
            }
            $next->update(['status' => $event->requires_approval ? Reg::PENDING : Reg::REGISTERED]);
            AppNotification::sendMany([$next->user_id], 'event_waitlist_promoted', "You're in: {$event->title}",
                'A seat opened up and your registration is confirmed.', ['event_id' => $event->id]);
        }
    }

    // ---- Passes --------------------------------------------------------------

    /** Opaque, signed pass. Only the registration id; no personal data. */
    public function passToken(Reg $reg): string
    {
        $id = base_convert((string) $reg->id, 10, 36);

        return 'EP1.'.$id.'.'.$this->sign($id);
    }

    public function registrationFromToken(string $token): ?Reg
    {
        $parts = explode('.', trim($token));
        if (count($parts) !== 3 || $parts[0] !== 'EP1' || ! hash_equals($this->sign($parts[1]), $parts[2])) {
            return null;
        }

        return Reg::find((int) base_convert($parts[1], 36, 10));
    }

    private function sign(string $id): string
    {
        $secret = config('abvp.qr_secret') ?: config('app.key');

        return substr(rtrim(strtr(base64_encode(hash_hmac('sha256', 'event-pass:'.$id, $secret, true)), '+/', '-_'), '='), 0, 16);
    }

    // ---- Check-in ------------------------------------------------------------

    public function canStaff(User $user, Event $event): bool
    {
        return EventStaff::where('event_id', $event->id)->where('user_id', $user->id)->exists()
            || $this->access->canIn($user, 'events.manage', $event->orgUnit);
    }

    /**
     * Mark arrival. Returns [registration, already]. Never creates a registration:
     * people not on the list go to the coordinator.
     */
    public function checkIn(User $staff, Event $event, Reg $reg, ?string $gate, string $method, $at = null): array
    {
        if ($reg->event_id !== $event->id) {
            throw new ApiException('WRONG_EVENT', 'This pass is for a different event.', 422);
        }
        if ($event->status !== 'published') {
            throw new ApiException('EVENT_NOT_ACTIVE', 'This event is not open for check-in.', 422);
        }
        if ($reg->status !== Reg::REGISTERED) {
            $why = match ($reg->status) {
                Reg::WAITLISTED => 'This person is on the waitlist, not confirmed.',
                Reg::PENDING => 'This registration is still waiting for approval.',
                default => 'This registration was cancelled or not approved.',
            };
            throw new ApiException('NOT_CONFIRMED', $why.' Send them to the coordinator.', 422);
        }

        $updated = Reg::whereKey($reg->id)->whereNull('checked_in_at')->update([
            'checked_in_at' => $at ?? now(),
            'checked_in_by' => $staff->id,
            'gate' => $gate,
            'check_in_method' => $method,
        ]);

        return [$reg->fresh(['user.profile']), $updated === 0];
    }
}
