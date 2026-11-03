<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\ResponsibilityResource;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\Responsibility;
use App\Services\Audit;
use Illuminate\Http\Request;

/** Dayitva: organisational posts shown on a member's profile. */
class ResponsibilityController extends Controller
{
    public function store(Request $request)
    {
        $data = $request->validate([
            'member_id' => ['required', 'string', 'exists:member_profiles,member_id'],
            'title' => ['required', 'string', 'max:120'],
            'org_unit_id' => ['required', 'integer', 'exists:org_units,id'],
            'vibhag_id' => ['nullable', 'integer', 'exists:vibhags,id'],
            'starts_on' => ['required', 'date'],
            'ends_on' => ['nullable', 'date', 'after_or_equal:starts_on'],
        ]);

        $this->authorizeIn('responsibilities.manage', OrgUnit::find($data['org_unit_id']));
        $profile = MemberProfile::where('member_id', $data['member_id'])->firstOrFail();

        $row = Responsibility::create(collect($data)->except('member_id')->all() + [
            'user_id' => $profile->user_id,
            'added_by' => $request->user()->id,
        ]);
        Audit::record('responsibility.added', $row, null, $data);

        return $this->ok(new ResponsibilityResource($row->load('orgUnit', 'vibhag')), 201);
    }

    public function update(Request $request, Responsibility $responsibility)
    {
        $this->authorizeIn('responsibilities.manage', $responsibility->orgUnit);
        $data = $request->validate([
            'title' => ['sometimes', 'string', 'max:120'],
            'ends_on' => ['nullable', 'date', 'after_or_equal:'.$responsibility->starts_on->toDateString()],
        ]);

        $before = $responsibility->only(array_keys($data));
        $responsibility->update($data);
        Audit::record('responsibility.updated', $responsibility, $before, $data);

        return $this->ok(new ResponsibilityResource($responsibility->load('orgUnit', 'vibhag')));
    }
}
