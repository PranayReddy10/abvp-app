<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ResponsibilityResource;
use App\Models\MemberProfile;
use App\Models\User;
use App\Services\AccessControl;
use App\Services\QrToken;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\URL;

class DirectoryController extends Controller
{
    /** A member's profile as another member sees it, filtered by their privacy choices. */
    public function show(Request $request, string $memberId, AccessControl $access)
    {
        $viewer = $request->user();
        $isAdmin = $access->can($viewer, 'members.view');

        if (! $isAdmin && ! $viewer->isApprovedMember()) {
            throw new ApiException('NOT_A_MEMBER', 'Profiles are visible to approved members.', 403);
        }

        $profile = MemberProfile::where('member_id', $memberId)
            ->where('membership_status', MemberProfile::STATUS_APPROVED)
            ->with('orgUnit', 'user.vibhags', 'user.responsibilities.orgUnit', 'user.responsibilities.vibhag')
            ->firstOrFail();

        return $this->ok($this->publicView($profile, $viewer, $isAdmin));
    }

    /** Scanner check: who does this pass belong to? */
    public function verifyQr(Request $request, QrToken $qr)
    {
        $request->validate(['token' => ['required', 'string', 'max:200']]);
        $this->authorizeIn('members.view');

        $profile = $qr->resolve($request->input('token'));

        if (! $profile) {
            throw new ApiException('QR_INVALID', 'This pass is not valid today. Ask the member to refresh it.', 422);
        }

        return $this->ok([
            'member_id' => $profile->member_id,
            'full_name' => $profile->full_name,
            'membership_status' => $profile->membership_status,
            'org_unit' => $profile->orgUnit?->label(),
            'photo_url' => $profile->photo_path ? URL::temporarySignedRoute('media.photo', now()->addMinutes(10), ['profile' => $profile->id]) : null,
        ]);
    }

    private function publicView(MemberProfile $p, User $viewer, bool $isAdmin): array
    {
        $viewerProfile = $viewer->profile;
        $isOfficeBearer = $isAdmin || $viewer->responsibilities()->whereNull('ends_on')->exists();

        $canSee = function (string $field) use ($p, $viewer, $viewerProfile, $isOfficeBearer) {
            if ($viewer->id === $p->user_id) {
                return true;
            }

            return match ($p->privacyFor($field)) {
                'members' => true,
                'my_unit' => $isOfficeBearer || ($viewerProfile && $viewerProfile->org_unit_id === $p->org_unit_id),
                'office_bearers' => $isOfficeBearer,
                default => false,
            };
        };

        return [
            'member_id' => $p->member_id,
            'full_name' => $p->full_name,
            'photo_url' => $p->photo_path ? URL::temporarySignedRoute('media.photo', now()->addMinutes(30), ['profile' => $p->id]) : null,
            'org_unit' => $p->orgUnit?->label(),
            'bio' => $p->bio,
            'languages' => $p->languages ?? [],
            'skills' => $p->skills ?? [],
            'links' => $p->links ?? [],
            'vibhags' => $p->user->vibhags->pluck('name')->values(),
            'responsibilities' => ResponsibilityResource::collection($p->user->responsibilities),
            'institution' => $canSee('institution') ? $p->institution : null,
            'course' => $canSee('institution') ? $p->course : null,
            'email' => $canSee('email') ? $p->user->email : null,
            'mobile' => $canSee('mobile') ? $p->user->mobile : null,
            'date_of_birth' => $canSee('date_of_birth') ? $p->date_of_birth?->toDateString() : null,
        ];
    }
}
