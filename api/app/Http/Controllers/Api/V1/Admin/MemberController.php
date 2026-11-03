<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProfileResource;
use App\Models\MemberProfile;
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
                'mobile' => Mobile::mask($p->user->mobile),
                'org_unit' => $p->orgUnit?->name,
                'institution' => $p->institution,
                'vibhags' => $p->user->vibhags->pluck('name'),
                'approved_at' => $p->approved_at?->toIso8601String(),
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
            'roles' => $profile->user->roleAssignments()->active()->with('orgUnit')->get()->map(fn ($r) => [
                'id' => $r->id,
                'role' => $r->role,
                'label' => config("abvp.roles.{$r->role}.label"),
                'org_unit' => $r->orgUnit->label() ?: $r->orgUnit->name,
            ]),
        ]);
    }
}
