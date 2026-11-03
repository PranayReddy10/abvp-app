<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\MeResource;
use App\Models\MemberProfile;
use App\Models\MembershipApplication as Application;
use App\Services\QrToken;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MembershipController extends Controller
{
    /** Submit, or resubmit after the office asked for corrections. */
    public function submit(Request $request)
    {
        $request->validate(['confirm' => ['accepted']]);

        $user = $request->user();
        $profile = $user->profile;

        $missing = collect([
            'full_name' => $profile?->full_name,
            'date_of_birth' => $profile?->date_of_birth,
            'org_unit_id' => $profile?->org_unit_id,
            'photo' => $profile?->photo_path,
        ])->filter(fn ($v) => blank($v))->keys();

        if ($missing->isNotEmpty()) {
            throw new ApiException('PROFILE_INCOMPLETE', 'Complete your name, date of birth, unit and photo before applying. Missing: '.$missing->implode(', '));
        }

        $existing = $user->application;

        if ($existing?->status === Application::SUBMITTED) {
            throw new ApiException('ALREADY_SUBMITTED', 'Your application is already with the office for review.');
        }
        if ($existing?->status === Application::APPROVED) {
            throw new ApiException('ALREADY_MEMBER', 'You are already an approved member.');
        }

        DB::transaction(function () use ($user, $profile, $existing) {
            if ($existing?->status === Application::MORE_INFO) {
                $existing->update(['status' => Application::SUBMITTED, 'org_unit_id' => $profile->org_unit_id, 'submitted_at' => now()]);
                $existing->events()->create(['actor_id' => $user->id, 'action' => 'resubmitted']);
            } else {
                $application = Application::create([
                    'user_id' => $user->id,
                    'org_unit_id' => $profile->org_unit_id,
                    'status' => Application::SUBMITTED,
                    'submitted_at' => now(),
                ]);
                $application->events()->create(['actor_id' => $user->id, 'action' => 'submitted']);
            }

            $profile->membership_status = MemberProfile::STATUS_SUBMITTED;
            $profile->save();
        });

        return $this->ok(new MeResource($user->fresh()->load('profile.orgUnit', 'vibhags', 'responsibilities', 'application.events', 'application.orgUnit')), 201);
    }

    /** Signed, daily-rotating code for the member pass. */
    public function qr(Request $request, QrToken $qr)
    {
        $profile = $request->user()->profile;

        if ($profile?->membership_status !== MemberProfile::STATUS_APPROVED) {
            throw new ApiException('NOT_A_MEMBER', 'Your pass appears after your membership is approved.', 403);
        }

        return $this->ok([
            'token' => $qr->issue($profile),
            'member_id' => $profile->member_id,
            'valid_until' => now()->endOfDay()->toIso8601String(),
        ]);
    }
}
