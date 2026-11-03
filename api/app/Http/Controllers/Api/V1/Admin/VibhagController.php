<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\VibhagResource;
use App\Models\Vibhag;
use App\Services\Audit;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class VibhagController extends Controller
{
    public function index()
    {
        $this->authorizeIn('admin.access');

        return $this->ok(VibhagResource::collection(Vibhag::withCount('members')->orderBy('sort_order')->orderBy('name')->get()));
    }

    public function store(Request $request)
    {
        $this->authorizeIn('vibhags.manage');
        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'code' => ['required', 'alpha_dash', 'max:24', 'unique:vibhags,code'],
            'description' => ['nullable', 'string', 'max:1000'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
        ]);

        $vibhag = Vibhag::create($data);
        Audit::record('vibhag.created', $vibhag, null, $data);

        return $this->ok(new VibhagResource($vibhag), 201);
    }

    public function update(Request $request, Vibhag $vibhag)
    {
        $this->authorizeIn('vibhags.manage');
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:120'],
            'code' => ['sometimes', 'alpha_dash', 'max:24', Rule::unique('vibhags', 'code')->ignore($vibhag->id)],
            'description' => ['nullable', 'string', 'max:1000'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $before = $vibhag->only(array_keys($data));
        $vibhag->update($data);
        Audit::record('vibhag.updated', $vibhag, $before, $data);

        return $this->ok(new VibhagResource($vibhag));
    }
}
