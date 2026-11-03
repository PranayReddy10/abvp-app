<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrgUnitResource;
use App\Models\OrgUnit;
use App\Services\Audit;
use App\Support\ApiException;
use Illuminate\Http\Request;

class OrgUnitController extends Controller
{
    private const CHILD_TYPE = ['national' => 'state', 'state' => 'district', 'district' => 'unit'];

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
        Audit::record('org_unit.created', $unit, null, $data);

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

        $before = $orgUnit->only(array_keys($data));
        $orgUnit->update($data);
        Audit::record('org_unit.updated', $orgUnit, $before, $data);

        return $this->ok(new OrgUnitResource($orgUnit));
    }
}
