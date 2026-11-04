<?php

namespace App\Http\Resources;

use App\Services\AccessControl;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Everything the app needs after sign-in, in one call. */
class MeResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $access = app(AccessControl::class);
        $roles = $access->rolesOf($this->resource);
        $application = $this->application;

        return [
            'id' => $this->id,
            'name' => $this->profile?->full_name ?? $this->name,
            'mobile' => $this->mobile,
            'locale' => $this->locale,
            'profile' => $this->profile ? new ProfileResource($this->profile) : null,
            'application' => $application ? [
                'id' => $application->id,
                'status' => $application->status,
                'submitted_at' => $application->submitted_at?->toIso8601String(),
                'decision_note' => $application->decision_note,
                'reviewing_office' => $application->orgUnit?->label(),
                'history' => $application->events->map(fn ($e) => [
                    'action' => $e->action,
                    'note' => $e->note,
                    'at' => $e->created_at?->toIso8601String(),
                ]),
            ] : null,
            'roles' => $roles->map(fn ($r) => [
                'role' => $r->role,
                'label' => config("abvp.roles.{$r->role}.label"),
                'org_unit' => ['id' => $r->orgUnit->id, 'name' => $r->orgUnit->name, 'type' => $r->orgUnit->type, 'label' => $r->orgUnit->label() ?: $r->orgUnit->name],
            ])->values(),
            // Invited guest without membership: the app shows the guest view.
            'is_guest' => ! $this->isApprovedMember() && \App\Models\EventRegistration::where('user_id', $this->id)->where('kind', 'guest')
                ->whereIn('status', ['registered'])->exists(),
            // Shows "Gate check-in" in the app.
            'can_check_in' => \App\Models\EventStaff::where('user_id', $this->id)
                ->whereHas('event', fn ($q) => $q->where('status', 'published')->where('ends_at', '>=', now()->subDay()))->exists()
                || $access->can($this->resource, 'events.manage'),
            'permissions' => collect(config('abvp.permissions'))->keys()
                ->filter(fn ($p) => $access->can($this->resource, $p))->values(),
        ];
    }
}
