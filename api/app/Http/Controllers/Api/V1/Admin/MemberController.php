<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProfileResource;
use App\Models\MemberProfile;
use App\Models\User;
use App\Services\AccessControl;
use App\Support\Mobile;
use Illuminate\Http\Request;

class MemberController extends Controller
{
    public function __construct(private AccessControl $access) {}

    public function index(Request $request)
    {
        $request->validate([
            'q' => ['nullable', 'string', 'max:60'],
            'org_unit_id' => ['nullable', 'integer'],
            'vibhag_id' => ['nullable', 'integer'],
            'status' => ['nullable', 'in:approved,suspended'],
        ]);
        $this->authorizeIn('members.view');

        $query = $this->access->scopeQuery(MemberProfile::query(), $request->user(), 'members.view')
            ->where('membership_status', $request->input('status', MemberProfile::STATUS_APPROVED))
            ->with('orgUnit', 'user.vibhags')
            ->orderBy('full_name');

        if ($q = $request->input('q')) {
            $query->where(fn ($w) => $w->where('full_name', 'like', "%$q%")
                ->orWhere('member_id', 'like', "%$q%")
                ->orWhereHas('user', fn ($u) => $u->where('mobile', 'like', "%$q%")));
        }
        if ($request->filled('org_unit_id')) {
            $query->whereIn('org_unit_id', fn ($s) => $s->select('id')->from('org_units')
                ->where('path', 'like', '%/'.$request->integer('org_unit_id').'/%'));
        }
        if ($request->filled('vibhag_id')) {
            $query->whereHas('user.vibhags', fn ($v) => $v->where('vibhags.id', $request->integer('vibhag_id')));
        }

        $page = $query->paginate(25);

        return $this->ok(
            $page->getCollection()->map(fn (MemberProfile $p) => [
                'user_id' => $p->user_id,
                'member_id' => $p->member_id,
                'full_name' => $p->full_name,
                'verified' => $p->isVerified(),
                'mobile' => Mobile::mask($p->user->mobile),
                'org_unit' => $p->orgUnit?->name,
                'institution' => $p->institution,
                'vibhags' => $p->user->vibhags->pluck('name'),
                'approved_at' => $p->approved_at?->toIso8601String(),
            ]),
            meta: ['page' => $page->currentPage(), 'total' => $page->total(), 'last_page' => $page->lastPage()],
        );
    }

    /**
     * Every account that signed up (website, app, Google, delegates), member or not.
     * National admins see all; state admins see accounts in their state (by district
     * or by the prant chosen at sign-up); district admins see their district.
     */
    public function accounts(Request $request)
    {
        $data = $request->validate([
            'q' => ['nullable', 'string', 'max:60'],
            'status' => ['nullable', 'in:all,not_applied,submitted,approved,delegate,verified,unverified'],
        ]);
        $this->authorizeIn('members.view');
        $grants = $this->access->grants($request->user(), 'members.view')->map->orgUnit->filter();
        $national = $grants->contains(fn ($u) => $u->type === 'national' || $u->parent_id === null);

        $query = User::query()->with('profile.orgUnit')->where('status', '!=', 'deleted')->latest('id');
        if (! $national) {
            $paths = $grants->pluck('path')->unique()->values();
            $states = $grants->where('type', 'state')->pluck('name')->all();
            $query->where(function ($w) use ($paths, $states) {
                $w->whereHas('profile', fn ($p) => $p->whereIn('org_unit_id', fn ($sub) => $sub->select('id')->from('org_units')
                    ->where(function ($o) use ($paths) {
                        foreach ($paths as $path) {
                            $o->orWhere('path', 'like', $path.'%');
                        }
                    })));
                if ($states) {
                    $w->orWhere(fn ($n) => $n->whereIn('prant', $states)
                        ->where(fn ($x) => $x->whereDoesntHave('profile')->orWhereHas('profile', fn ($p) => $p->whereNull('org_unit_id'))));
                }
            });
        }
        if ($q = $data['q'] ?? null) {
            $query->where(fn ($w) => $w->where('name', 'like', "%$q%")->orWhere('mobile', 'like', "%$q%")->orWhere('email', 'like', "%$q%")
                ->orWhereHas('profile', fn ($p) => $p->where('full_name', 'like', "%$q%")->orWhere('member_id', 'like', "%$q%")));
        }
        match ($data['status'] ?? 'all') {
            'not_applied' => $query->where(fn ($w) => $w->whereDoesntHave('profile')->orWhereHas('profile', fn ($p) => $p->where('membership_status', 'draft'))),
            'submitted' => $query->whereHas('profile', fn ($p) => $p->whereIn('membership_status', ['submitted', 'more_info_required'])),
            'approved' => $query->whereHas('profile', fn ($p) => $p->where('membership_status', 'approved')),
            'verified' => $query->whereHas('profile', fn ($p) => $p->whereNotNull('verified_at')),
            'unverified' => $query->where(fn ($w) => $w->whereDoesntHave('profile')->orWhereHas('profile', fn ($p) => $p->whereNull('verified_at'))),
            'delegate' => $query->whereHas('registrations', fn ($r) => $r->where('kind', 'delegate')->where('status', '!=', 'cancelled')),
            default => null,
        };

        $page = $query->paginate(25);
        $delegates = \App\Models\EventRegistration::whereIn('user_id', $page->getCollection()->pluck('id'))
            ->where('kind', 'delegate')->where('status', '!=', 'cancelled')->pluck('user_id')->flip();

        return $this->ok(
            $page->getCollection()->map(fn (User $u) => [
                'user_id' => $u->id,
                'name' => $u->profile?->full_name ?: ($u->name ?: null),
                'mobile' => $u->mobile,
                'email' => $u->email,
                'prant' => $u->prant,
                'area' => $u->profile?->orgUnit?->label(),
                'institution' => $u->profile?->institution ?? $u->institution,
                'occupation' => $u->occupation,
                'membership' => $u->profile?->membership_status ?? 'draft',
                'member_id' => $u->profile?->member_id,
                'verified' => (bool) $u->profile?->isVerified(),
                'photo_url' => $u->profile?->photo_path ? \Illuminate\Support\Facades\URL::temporarySignedRoute('media.photo', now()->addHour(), ['profile' => $u->profile->id]) : null,
                'profile_id' => $u->profile?->membership_status === MemberProfile::STATUS_APPROVED ? $u->profile->id : null,
                'delegate' => $delegates->has($u->id),
                'signed_up_at' => $u->created_at?->toIso8601String(),
                'last_login_at' => $u->last_login_at?->toIso8601String(),
                'status' => $u->status,
            ]),
            meta: ['page' => $page->currentPage(), 'total' => $page->total(), 'last_page' => $page->lastPage()],
        );
    }

    public function show(Request $request, MemberProfile $profile)
    {
        $this->authorizeIn('members.view', $profile->orgUnit);
        $profile->load('orgUnit', 'user.vibhags', 'user.responsibilities.orgUnit', 'user.responsibilities.vibhag', 'user.roleAssignments.orgUnit');

        return $this->ok([
            'user_id' => $profile->user_id,
            'mobile' => $profile->user->mobile,
            'profile' => new ProfileResource($profile),
            'verified_by' => $profile->verified_by ? \App\Models\User::find($profile->verified_by)?->profile?->full_name : null,
            'verification_note' => $profile->verification_note,
            'can_verify' => $this->access->canIn($request->user(), 'members.verify', $profile->orgUnit),
            'roles' => $profile->user->roleAssignments()->active()->with('orgUnit')->get()->map(fn ($r) => [
                'id' => $r->id,
                'role' => $r->role,
                'label' => config("abvp.roles.{$r->role}.label"),
                'org_unit' => $r->orgUnit->label() ?: $r->orgUnit->name,
            ]),
        ]);
    }

    /** Mark a member's identity as checked by the office, or remove the tick. */
    public function verify(Request $request, MemberProfile $profile)
    {
        $data = $request->validate(['verified' => ['required', 'boolean'], 'note' => ['nullable', 'string', 'max:300']]);
        if (! $this->access->canIn($request->user(), 'members.verify', $profile->orgUnit)) {
            throw new \App\Support\ApiException('FORBIDDEN_SCOPE', 'Only state or district admins of this member\'s area can verify.', 403);
        }

        $profile->forceFill($data['verified']
            ? ['verified_at' => now(), 'verified_by' => $request->user()->id, 'verification_note' => $data['note'] ?? null]
            : ['verified_at' => null, 'verified_by' => null, 'verification_note' => $data['note'] ?? null])->save();

        if ($data['verified']) {
            \App\Models\AppNotification::sendMany([$profile->user_id], 'profile_verified', 'Your profile is verified', 'A blue tick now shows next to your name.');
        }

        return $this->ok(['verified' => $profile->isVerified()]);
    }
}
