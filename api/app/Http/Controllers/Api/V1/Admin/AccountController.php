<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProfileResource;
use App\Models\AppNotification;
use App\Models\EventRegistration;
use App\Models\EventTeamMember;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\User;
use App\Services\AccessControl;
use App\Services\AccountIds;
use App\Support\ApiException;
use App\Support\Mobile;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * One account in the admin panel: see everything about it, block or unblock it, or delete it.
 * National admins act on every account; state and district admins on accounts in their area.
 */
class AccountController extends Controller
{
    public function __construct(private AccessControl $access) {}

    /** An admin adds a person directly: account, profile in an area, member ID, optional password. */
    public function store(Request $request, AccountIds $ids)
    {
        $this->authorizeIn('accounts.manage');
        $data = $request->validate([
            'name' => ['required', 'string', 'min:2', 'max:120'],
            'mobile' => ['required', 'string', 'max:20'],
            'org_unit_id' => ['nullable', 'integer', 'exists:org_units,id'],
            'password' => ['nullable', 'string', 'min:8', 'max:72'],
            'approve' => ['boolean'],
        ]);
        $mobile = Mobile::normalize($data['mobile']);
        if (! $mobile) {
            throw new ApiException('INVALID_MOBILE', 'Enter a valid 10-digit Indian mobile number.');
        }
        if (User::where('mobile', $mobile)->exists()) {
            throw new ApiException('ACCOUNT_EXISTS', 'An account with this mobile number already exists. Find it under All accounts.', 409);
        }
        $unit = isset($data['org_unit_id']) ? OrgUnit::find($data['org_unit_id']) : null;
        $grants = $this->access->grants($request->user(), 'accounts.manage')->map->orgUnit->filter();
        $national = $grants->contains(fn ($u) => $u->type === 'national' || $u->parent_id === null);
        if (! $national && (! $unit || ! $grants->contains(fn ($g) => $g->contains($unit)))) {
            throw new ApiException('FORBIDDEN_SCOPE', 'Choose an area inside your own area.', 403);
        }

        $user = DB::transaction(function () use ($data, $mobile, $unit, $ids) {
            $user = User::create(['mobile' => $mobile, 'name' => $data['name']]);
            if (! empty($data['password'])) {
                $user->forceFill(['password' => $data['password'], 'password_set_at' => now()])->save();
            }
            $profile = new MemberProfile(['full_name' => $data['name'], 'org_unit_id' => $unit?->id]);
            $profile->user_id = $user->id;
            if ($data['approve'] ?? true) {
                $profile->membership_status = MemberProfile::STATUS_APPROVED;
                $profile->approved_at = now();
            }
            $profile->save();
            $user->setRelation('profile', $profile);
            $ids->ensure($user);

            return $user;
        });
        rescue(fn () => EventTeamMember::linkUser($user), null, true);

        return $this->ok(['user_id' => $user->id, 'name' => $data['name'], 'mobile' => $user->mobile, 'member_id' => $user->profile?->fresh()?->member_id], 201);
    }

    public function show(Request $request, User $user)
    {
        $this->guard($request, $user, 'members.view');
        $user->load('profile.orgUnit', 'vibhags', 'responsibilities', 'application.events', 'application.orgUnit');
        $regs = EventRegistration::where('user_id', $user->id)->with('event:id,title,starts_at')->latest('id')->limit(20)->get();

        return $this->ok([
            'user_id' => $user->id,
            'name' => $user->profile?->full_name ?: $user->name,
            'mobile' => $user->mobile,
            'email' => $user->email,
            'prant' => $user->prant,
            'occupation' => $user->occupation,
            'gender' => $user->profile?->gender ?? $user->gender,
            'institution' => $user->profile?->institution ?? $user->institution,
            'status' => $user->status,
            'has_password' => $user->password !== null,
            'google_linked' => (bool) $user->google_id,
            'mobile_verified' => $user->mobile_verified_at !== null,
            'signed_up_at' => $user->created_at?->toIso8601String(),
            'last_login_at' => $user->last_login_at?->toIso8601String(),
            'profile' => $user->profile ? new ProfileResource($user->profile) : null,
            'application' => $user->application ? [
                'status' => $user->application->status,
                'submitted_at' => $user->application->submitted_at?->toIso8601String(),
                'decision_note' => $user->application->decision_note,
                'office' => $user->application->orgUnit?->label(),
            ] : null,
            'roles' => $user->roleAssignments()->active()->with('orgUnit')->get()->map(fn ($r) => [
                'label' => config("abvp.roles.{$r->role}.label"),
                'org_unit' => $r->orgUnit?->label() ?: $r->orgUnit?->name,
            ]),
            'events' => $regs->map(fn ($r) => [
                'title' => $r->event?->title,
                'starts_at' => $r->event?->starts_at?->toIso8601String(),
                'kind' => $r->kind,
                'status' => $r->status,
            ]),
            'posts' => Post::where('user_id', $user->id)->count(),
            'can_manage' => $this->canManage($request->user(), $user),
            'can_edit' => $this->canEdit($request->user(), $user),
            'verified' => (bool) $user->profile?->isVerified(),
            'verified_at' => $user->profile?->verified_at?->toIso8601String(),
            'delegate' => $this->delegateOf($request, $user),
        ]);
    }

    /** The delegate form for the current conference, as the person filled it (or null). */
    private function delegateOf(Request $request, User $user): ?array
    {
        $event = \App\Services\ConferenceTeams::current();
        if (! $event) {
            return null;
        }
        $sub = Request::create('/', 'GET');
        $sub->setUserResolver(fn () => $user);
        $data = rescue(fn () => app(\App\Http\Controllers\Api\V1\DelegateController::class)->show($sub, $event)->getData(true)['data'] ?? null, null, false);

        return $data ? ['event' => $data['event'], 'registration' => $data['registration'], 'options' => $data['options'], 'prefill' => $data['prefill']] : null;
    }

    /** Admins of the area edit what a person entered (not super admins' own records from here). */
    private function canEdit(User $admin, User $user): bool
    {
        return $this->access->can($admin, 'accounts.manage') && $this->inArea($admin, $user, 'accounts.manage');
    }

    private function guardEdit(Request $request, User $user): void
    {
        $this->authorizeIn('accounts.manage');
        if (! $this->inArea($request->user(), $user, 'accounts.manage')) {
            throw new ApiException('FORBIDDEN_SCOPE', 'This account is outside your area.', 403);
        }
    }

    /** Change what the person entered: name, gender, date of birth, email, area, college, work, bio. */
    public function update(Request $request, User $user, AccountIds $ids)
    {
        $this->guardEdit($request, $user);
        $data = $request->validate([
            'full_name' => ['sometimes', 'string', 'min:2', 'max:120'],
            'gender' => ['nullable', 'in:male,female,other'],
            'date_of_birth' => ['nullable', 'date', 'before:-10 years'],
            'email' => ['nullable', 'email', 'max:190'],
            'org_unit_id' => ['nullable', 'integer', 'exists:org_units,id'],
            'institution' => ['nullable', 'string', 'max:160'],
            'course' => ['nullable', 'string', 'max:120'],
            'occupation' => ['nullable', 'string', 'max:80'],
            'bio' => ['nullable', 'string', 'max:500'],
        ]);
        $profile = $user->profile ?? $ids->ensure($user) ?? throw new ApiException('PROFILE_REQUIRED', 'Add areas first (Setup → Areas).');
        foreach (['email', 'occupation'] as $f) {
            if (array_key_exists($f, $data)) {
                $user->{$f} = $data[$f];
            }
        }
        if (array_key_exists('full_name', $data)) {
            $user->name = $data['full_name'];
        }
        if (! empty($data['org_unit_id'])) {
            $unit = OrgUnit::find($data['org_unit_id']);
            $user->prant = ($unit->type === 'state' ? $unit : $unit->ancestorOfType('state'))?->name ?? $user->prant;
        }
        $user->save();
        $profile->forceFill(collect($data)->only(['full_name', 'gender', 'date_of_birth', 'org_unit_id', 'institution', 'course', 'bio'])->all())->save();

        return $this->show($request, $user->fresh());
    }

    public function photo(Request $request, User $user, AccountIds $ids)
    {
        $this->guardEdit($request, $user);
        $request->validate(['photo' => ['required', 'image', 'mimes:jpeg,png,webp', 'max:4096']]);
        $profile = $user->profile ?? $ids->ensure($user) ?? throw new ApiException('PROFILE_REQUIRED', 'Add areas first (Setup → Areas).');
        $disk = Storage::disk(config('abvp.media_disk'));
        if ($profile->photo_path) {
            $disk->delete($profile->photo_path);
        }
        $profile->forceFill(['photo_path' => $request->file('photo')->storeAs('photos/'.$user->id, \Illuminate\Support\Str::uuid().'.'.$request->file('photo')->extension(), ['disk' => config('abvp.media_disk'), 'visibility' => 'private'])])->save();

        return $this->show($request, $user->fresh());
    }

    public function removePhoto(Request $request, User $user)
    {
        $this->guardEdit($request, $user);
        $profile = $user->profile;
        if ($profile?->photo_path) {
            Storage::disk(config('abvp.media_disk'))->delete($profile->photo_path);
            $profile->forceFill(['photo_path' => null])->save();
        }

        return $this->show($request, $user->fresh());
    }

    /** The blue tick: an admin checked who this is. */
    public function verify(Request $request, User $user, AccountIds $ids)
    {
        $data = $request->validate(['verified' => ['required', 'boolean'], 'note' => ['nullable', 'string', 'max:300']]);
        $profile = $user->profile ?? $ids->ensure($user) ?? throw new ApiException('PROFILE_REQUIRED', 'Add areas first (Setup → Areas).');
        if (! $this->access->canIn($request->user(), 'members.verify', $profile->orgUnit) && ! $this->national($request->user(), 'members.verify')) {
            throw new ApiException('FORBIDDEN_SCOPE', 'Only admins of this person\'s area can verify.', 403);
        }
        if ($profile->membership_status !== MemberProfile::STATUS_APPROVED) {
            $profile->forceFill(['membership_status' => MemberProfile::STATUS_APPROVED, 'approved_at' => now()]);
        }
        $profile->forceFill($data['verified']
            ? ['verified_at' => now(), 'verified_by' => $request->user()->id, 'verification_note' => $data['note'] ?? null]
            : ['verified_at' => null, 'verified_by' => null, 'verification_note' => $data['note'] ?? null])->save();
        if ($data['verified']) {
            AppNotification::sendMany([$user->id], 'profile_verified', 'Your profile is verified', 'A blue tick now shows next to your name.');
        }

        return $this->show($request, $user->fresh());
    }

    /** Fill in or change the person's delegate form for the current conference. */
    public function delegate(Request $request, User $user)
    {
        $this->guardEdit($request, $user);
        $event = \App\Services\ConferenceTeams::current() ?? throw new ApiException('NO_CONFERENCE', 'No published conference.', 404);
        $request->setUserResolver(fn () => $user);
        $ctrl = app(\App\Http\Controllers\Api\V1\DelegateController::class);
        $ctrl->byAdmin = true;
        $ctrl->save($request, $event);
        $admin = auth()->user();
        $request->setUserResolver(fn () => $admin);

        return $this->show($request, $user->fresh());
    }

    private function national(User $admin, string $perm): bool
    {
        return $this->access->grants($admin, $perm)->map->orgUnit->filter()->contains(fn ($u) => $u->type === 'national' || $u->parent_id === null);
    }

    /** Block (or unblock) an account: it cannot sign in, and its open sessions end at once. */
    public function block(Request $request, User $user)
    {
        $data = $request->validate(['blocked' => ['required', 'boolean'], 'reason' => ['nullable', 'string', 'max:300']]);
        $this->guardManage($request, $user);
        if ($user->status === 'deleted') {
            throw new ApiException('ACCOUNT_DELETED', 'This account was deleted.', 409);
        }
        $user->forceFill(['status' => $data['blocked'] ? 'suspended' : 'active'])->save();
        if ($data['blocked']) {
            $user->tokens()->delete();
        }

        return $this->ok(['status' => $user->status]);
    }

    /**
     * Delete an account. Personal details, photo, posts, comments, likes and follows go; the
     * mobile number is freed so the person can register again. Event history keeps a
     * placeholder ("Deleted account") so reports stay correct.
     */
    public function destroy(Request $request, User $user)
    {
        $this->guardManage($request, $user);

        DB::transaction(function () use ($user) {
            if ($photo = $user->profile?->photo_path) {
                rescue(fn () => Storage::disk(config('abvp.media_disk'))->delete($photo), null, false);
            }
            Post::where('user_id', $user->id)->get()->each(fn (Post $p) => $p->delete());
            PostComment::where('user_id', $user->id)->delete();
            DB::table('post_likes')->where('user_id', $user->id)->delete();
            DB::table('follows')->where('follower_id', $user->id)->orWhere('followee_id', $user->id)->delete();
            AppNotification::where('user_id', $user->id)->delete();
            $user->vibhags()->detach();
            $user->roleAssignments()->delete();
            $user->responsibilities()->delete();
            $user->tokens()->delete();
            \App\Models\EventTeamMember::where('user_id', $user->id)->update(['user_id' => null, 'mobile' => null]);
            $user->profile?->delete();
            $user->forceFill([
                'name' => 'Deleted account',
                'mobile' => 'deleted:'.$user->id,
                'email' => null,
                'password' => null,
                'password_set_at' => null,
                'google_id' => null,
                'google_email' => null,
                'prant' => null,
                'institution' => null,
                'occupation' => null,
                'gender' => null,
                'mobile_verified_at' => null,
                'status' => 'deleted',
            ])->save();
        });

        return $this->ok(['deleted' => true]);
    }

    private function guard(Request $request, User $user, string $permission): void
    {
        $this->authorizeIn($permission);
        if (! $this->inArea($request->user(), $user, $permission)) {
            throw new ApiException('FORBIDDEN_SCOPE', 'This account is outside your area.', 403);
        }
    }

    private function guardManage(Request $request, User $user): void
    {
        $this->guard($request, $user, 'accounts.manage');
        if (! $this->canManage($request->user(), $user)) {
            throw new ApiException('PROTECTED_ACCOUNT', $user->id === $request->user()->id
                ? 'You cannot block or delete your own account.'
                : 'This person has an admin role. Remove their role first, or ask a super admin.', 403);
        }
    }

    /** Not yourself; admins only by a super admin; super admins never from here. */
    private function canManage(User $admin, User $user): bool
    {
        if ($admin->id === $user->id || ! $this->access->can($admin, 'accounts.manage')) {
            return false;
        }
        $roles = $user->roleAssignments()->active()->pluck('role');
        if ($roles->contains('super_admin')) {
            return false;
        }

        return $roles->isEmpty() || $this->access->rolesOf($admin)->contains('role', 'super_admin');
    }

    private function inArea(User $admin, User $user, string $permission): bool
    {
        $grants = $this->access->grants($admin, $permission)->map->orgUnit->filter();
        if ($grants->contains(fn ($u) => $u->type === 'national' || $u->parent_id === null)) {
            return true;
        }
        $unit = $user->profile?->orgUnit;
        if ($unit && $grants->contains(fn ($g) => $g->contains($unit))) {
            return true;
        }

        return ! $unit && $user->prant && $grants->contains(fn ($g) => $g->type === 'state' && $g->name === $user->prant);
    }
}
