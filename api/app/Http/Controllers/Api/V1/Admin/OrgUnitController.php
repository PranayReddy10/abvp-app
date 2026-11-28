<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrgUnitResource;
use App\Models\OrgUnit;
use App\Support\ApiException;
use Illuminate\Http\Request;

class OrgUnitController extends Controller
{
    private const CHILD_TYPE = ['national' => 'state', 'state' => 'district', 'district' => 'unit'];

    /**
     * Areas for the Areas page: the units the admin may manage (or the children of parent_id),
     * inactive ones included, with how many sub-areas and members each has.
     */
    public function index(Request $request, \App\Services\AccessControl $access)
    {
        $request->validate(['parent_id' => ['nullable', 'integer']]);
        $this->authorizeIn('org.manage');

        if ($request->filled('parent_id')) {
            $parent = OrgUnit::findOrFail($request->integer('parent_id'));
            $this->authorizeIn('org.manage', $parent);
            $units = OrgUnit::where('parent_id', $parent->id)->orderBy('name')->get();
        } else {
            $units = $access->grants($request->user(), 'org.manage')->map->orgUnit->filter()->unique('id')->values();
        }
        $children = OrgUnit::whereIn('parent_id', $units->pluck('id'))->selectRaw('parent_id, count(*) as n')->groupBy('parent_id')->pluck('n', 'parent_id');

        return $this->ok($units->map(fn (OrgUnit $u) => [
            'id' => $u->id,
            'parent_id' => $u->parent_id,
            'type' => $u->type,
            'name' => $u->name,
            'name_local' => $u->name_local,
            'code' => $u->code,
            'is_active' => (bool) $u->is_active,
            'label' => $u->label(),
            'children' => (int) ($children[$u->id] ?? 0),
            'can_have_children' => isset(self::CHILD_TYPE[$u->type]),
            'members' => \App\Models\MemberProfile::where('membership_status', 'approved')
                ->whereIn('org_unit_id', OrgUnit::where('path', 'like', $u->path.'%')->select('id'))->count(),
        ]));
    }

    /** Adds every ABVP prant from the standard list that is not there yet, as a state under the national unit. */
    public function importPrants()
    {
        $national = OrgUnit::where('type', 'national')->firstOrFail();
        $this->authorizeIn('org.manage', $national);
        $have = OrgUnit::where('parent_id', $national->id)->pluck('name')->map(fn ($n) => mb_strtolower($n))->all();
        $added = [];
        foreach (config('abvp.prants') as $name) {
            if (! in_array(mb_strtolower($name), $have, true)) {
                $added[] = OrgUnit::create(['parent_id' => $national->id, 'type' => 'state', 'name' => $name])->name;
            }
        }
        if ($added) {
        }

        return $this->ok(['added' => $added]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'parent_id' => ['required', 'integer', 'exists:org_units,id'],
            'name' => ['required', 'string', 'max:120'],
            'name_local' => ['nullable', 'string', 'max:120'],
            'code' => ['nullable', 'alpha_num', 'max:12'],
        ]);

        $parent = OrgUnit::findOrFail($data['parent_id']);
        $this->authorizeIn('org.manage', $parent);

        $type = self::CHILD_TYPE[$parent->type] ?? throw new ApiException('NO_CHILD_LEVEL', 'Units cannot have sub-units.');

        if (OrgUnit::where('parent_id', $parent->id)->where('name', $data['name'])->exists()) {
            throw new ApiException('DUPLICATE_UNIT', "{$data['name']} already exists under {$parent->name}.");
        }

        $unit = OrgUnit::create($data + ['type' => $type]);

        return $this->ok(new OrgUnitResource($unit->fresh()), 201);
    }

    public function update(Request $request, OrgUnit $orgUnit)
    {
        $this->authorizeIn('org.manage', $orgUnit);
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:120'],
            'name_local' => ['nullable', 'string', 'max:120'],
            'code' => ['nullable', 'alpha_num', 'max:12'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $orgUnit->update($data);

        return $this->ok(new OrgUnitResource($orgUnit));
    }
}
