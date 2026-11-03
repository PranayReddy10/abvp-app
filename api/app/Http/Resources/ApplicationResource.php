<?php

namespace App\Http\Resources;

use App\Support\Mobile;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ApplicationResource extends JsonResource
{
    /** Detail view adds the full profile, contact and history. */
    public bool $detailed = false;

    public function detailed(): static
    {
        $this->detailed = true;

        return $this;
    }

    public function toArray(Request $request): array
    {
        $profile = $this->user->profile;

        $data = [
            'id' => $this->id,
            'status' => $this->status,
            'submitted_at' => $this->submitted_at?->toIso8601String(),
            'decided_at' => $this->decided_at?->toIso8601String(),
            'decision_note' => $this->decision_note,
            'waiting_days' => $this->submitted_at ? (int) $this->submitted_at->diffInDays(now()) : null,
            'org_unit' => ['id' => $this->orgUnit->id, 'name' => $this->orgUnit->name, 'label' => $this->orgUnit->label()],
            'applicant' => [
                'user_id' => $this->user->id,
                'name' => $profile?->full_name ?? $this->user->name,
                'mobile' => $this->detailed ? $this->user->mobile : Mobile::mask($this->user->mobile),
                'institution' => $profile?->institution,
            ],
        ];

        if ($this->detailed) {
            $data['profile'] = $profile ? new ProfileResource($profile) : null;
            $data['history'] = $this->events->map(fn ($e) => [
                'action' => $e->action,
                'note' => $e->note,
                'actor' => $e->actor?->profile?->full_name ?? $e->actor?->name,
                'at' => $e->created_at?->toIso8601String(),
            ]);
        }

        return $data;
    }
}
