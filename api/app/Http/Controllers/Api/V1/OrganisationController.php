<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrgUnitResource;
use App\Http\Resources\VibhagResource;
use App\Models\OrgUnit;
use App\Models\Vibhag;
use Illuminate\Http\Request;

/** Public lookups used by the application form: state > district > unit, and Vibhags. */
class OrganisationController extends Controller
{
    public function units(Request $request)
    {
        $request->validate([
            'parent_id' => ['nullable', 'integer'],
            'type' => ['nullable', 'in:'.implode(',', config('abvp.unit_types'))],
        ]);

        $query = OrgUnit::where('is_active', true)->withCount('children')->orderBy('name');

        if ($request->filled('parent_id')) {
            $query->where('parent_id', $request->integer('parent_id'));
        } elseif (! $request->filled('type')) {
            $query->where('type', 'state');
        }

        if ($request->filled('type')) {
            $query->where('type', $request->input('type'));
        }

        return $this->ok(OrgUnitResource::collection($query->get()));
    }

    public function vibhags()
    {
        return $this->ok(VibhagResource::collection(
            Vibhag::where('is_active', true)->orderBy('sort_order')->orderBy('name')->get()
        ));
    }
}
