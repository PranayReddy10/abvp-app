<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\URL;

/** The member's own profile (or an authorised reviewer's view): every field. */
class ProfileResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $user = $this->user;

        return [
            'member_id' => $this->member_id,
            'full_name' => $this->full_name,
            'gender' => $this->gender,
            'date_of_birth' => $this->date_of_birth?->toDateString(),
            'photo_url' => $this->photo_path
                ? URL::temporarySignedRoute('media.photo', now()->addMinutes(30), ['profile' => $this->id])
                : null,
            'org_unit' => $this->orgUnit ? [
                'id' => $this->orgUnit->id,
                'name' => $this->orgUnit->name,
                'label' => $this->orgUnit->label(),
            ] : null,
            'institution' => $this->institution,
            'course' => $this->course,
            'study_year' => $this->study_year,
            'bio' => $this->bio,
            'languages' => $this->languages ?? [],
            'skills' => $this->skills ?? [],
            'links' => $this->links ?? [],
            'privacy' => collect(config('abvp.privacy_defaults'))->keys()
                ->mapWithKeys(fn ($f) => [$f => $this->privacyFor($f)]),
            'membership_status' => $this->membership_status,
            'approved_at' => $this->approved_at?->toIso8601String(),
            'vibhags' => $user->vibhags->map(fn ($v) => ['id' => $v->id, 'name' => $v->name, 'code' => $v->code])->values(),
            'responsibilities' => ResponsibilityResource::collection($user->responsibilities),
        ];
    }
}
