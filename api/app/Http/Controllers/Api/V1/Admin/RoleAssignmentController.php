<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\RoleAssignment;
use App\Services\AccessControl;
use App\Services\Audit;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class RoleAssignmentController extends Controller
{
    public function __construct(private AccessControl $access) {}

    public function index(Request $request)
    {
        $this->authorizeIn('roles.assign');

        $rows = $this->access->scopeQuery(RoleAssignment::query(), $request->user(), 'roles.assign')
            ->active()->with('orgUnit', 'vibhag', 'user.profile')->latest()->get();

        return $this->ok($rows->map(fn (RoleAssignment $r) => [
            'id' => $r->id,
            'role' => $r->role,
            'label' => config("abvp.roles.{$r->role}.label"),
            'member' => ['name' => $r->user->profile?->full_name ?? $r->user->name, 'member_id' => $r->user->profile?->member_id],
            'org_unit' => $r->orgUnit->label() ?: $r->orgUnit->name,
            'vibhag' => $r->vibhag?->name,
            'ends_on' => $r->ends_on?->toDateString(),
        ]));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'member_id' => ['required', 'string', 'exists:member_profiles,member_id'],
            'role' => ['required', Rule::in(array_keys(config('abvp.roles')))],
            'org_unit_id' => ['required', 'integer', 'exists:org_units,id'],
            'vibhag_id' => ['nullable', 'integer', 'exists:vibhags,id'],
            'ends_on' => ['nullable', 'date', 'after:today'],
        ]);

        $unit = OrgUnit::findOrFail($data['org_unit_id']);
        $this->guard($request, $data['role'], $unit);

        $profile = MemberProfile::where('member_id', $data['member_id'])->firstOrFail();
        if ($profile->membership_status !== MemberProfile::STATUS_APPROVED) {
            throw new ApiException('NOT_A_MEMBER', 'Roles can only be given to approved members.');
        }

        $assignment = RoleAssignment::create([
            'user_id' => $profile->user_id,
            'role' => $data['role'],
            'org_unit_id' => $unit->id,
            'vibhag_id' => $data['vibhag_id'] ?? null,
            'assigned_by' => $request->user()->id,
            'starts_on' => now()->toDateString(),
            'ends_on' => $data['ends_on'] ?? null,
        ]);
        Audit::record('role.assigned', $assignment, null, $data);

        return $this->ok(['id' => $assignment->id], 201);
    }

    public function destroy(Request $request, RoleAssignment $roleAssignment)
    {
        $this->guard($request, $roleAssignment->role, $roleAssignment->orgUnit);

        $roleAssignment->update(['ends_on' => now()->subDay()->toDateString()]);
        Audit::record('role.ended', $roleAssignment, ['role' => $roleAssignment->role], null);

        return $this->ok(['ended' => true]);
    }

    /** Must hold roles.assign over the unit and outrank the role being given. */
    private function guard(Request $request, string $role, OrgUnit $unit): void
    {
        $this->authorizeIn('roles.assign', $unit);

        if ($this->access->rankIn($request->user(), $unit) <= config("abvp.roles.$role.rank")) {
            throw new ApiException('ROLE_TOO_HIGH', 'You can only assign roles below your own.', 403);
        }
    }
}
