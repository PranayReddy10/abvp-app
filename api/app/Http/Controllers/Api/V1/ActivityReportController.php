<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ActivityReport;
use App\Models\OrgUnit;
use App\Services\AccessControl;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class ActivityReportController extends Controller
{
    public function types()
    {
        return $this->ok(collect(ActivityReport::TYPES)->map(fn ($label, $key) => ['key' => $key, 'label' => $label])->values());
    }

    /** Members report for their own unit; admins can report for any unit in their area. */
    public function store(Request $request, AccessControl $access)
    {
        $user = $request->user();
        if (! $user->isApprovedMember()) {
            throw new ApiException('NOT_A_MEMBER', 'Reporting is available after your membership is approved.', 403);
        }

        $data = $request->validate([
            'title' => ['required', 'string', 'max:160'],
            'programme_type' => ['required', Rule::in(array_keys(ActivityReport::TYPES))],
            'held_on' => ['required', 'date', 'before_or_equal:today', 'after:-1 year'],
            'place' => ['nullable', 'string', 'max:200'],
            'participants' => ['required', 'integer', 'min:0', 'max:1000000'],
            'institutions' => ['nullable', 'integer', 'min:0', 'max:10000'],
            'description' => ['nullable', 'string', 'max:3000'],
            'org_unit_id' => ['nullable', 'integer', 'exists:org_units,id'],
            'vibhag_id' => ['nullable', 'integer', 'exists:vibhags,id'],
            'photos' => ['nullable', 'array', 'max:6'],
            'photos.*' => ['image', 'mimes:jpeg,png,webp', 'max:3072'],
        ]);

        $home = $user->profile->orgUnit;
        $unit = isset($data['org_unit_id']) ? OrgUnit::find($data['org_unit_id']) : $home;
        if ($unit->id !== $home?->id && ! $access->canIn($user, 'reports.view', $unit)) {
            throw new ApiException('FORBIDDEN_SCOPE', 'You can report for your own unit only.', 403);
        }

        $disk = config('abvp.media_disk');
        $paths = collect($request->file('photos', []))->map(fn ($f) => $f->storeAs(
            'reports/'.now()->format('Y/m'), Str::uuid().'.'.$f->extension(), ['disk' => $disk, 'visibility' => 'private'],
        ))->all();

        $report = ActivityReport::create(collect($data)->except('photos')->all() + [
            'org_unit_id' => $unit->id,
            'submitted_by' => $user->id,
            'institutions' => $data['institutions'] ?? 0,
            'photos' => $paths,
        ]);

        return $this->ok(self::present($report->load('orgUnit', 'vibhag', 'submitter.profile')), 201);
    }

    public function mine(Request $request)
    {
        $reports = ActivityReport::where('submitted_by', $request->user()->id)->with('orgUnit', 'vibhag', 'submitter.profile')->latest('held_on')->limit(50)->get();

        return $this->ok($reports->map(fn ($r) => self::present($r)));
    }

    public static function present(ActivityReport $r): array
    {
        return [
            'id' => $r->id,
            'title' => $r->title,
            'programme_type' => $r->programme_type,
            'programme_label' => ActivityReport::TYPES[$r->programme_type] ?? $r->programme_type,
            'held_on' => $r->held_on->toDateString(),
            'place' => $r->place,
            'participants' => $r->participants,
            'institutions' => $r->institutions,
            'description' => $r->description,
            'unit' => $r->orgUnit?->name,
            'unit_label' => $r->orgUnit?->label(),
            'vibhag' => $r->vibhag?->name,
            'submitted_by' => $r->submitter?->profile?->full_name,
            'photo_urls' => collect($r->photos ?? [])->keys()->map(fn ($i) => URL::temporarySignedRoute('media.report', now()->addMinutes(30), ['report' => $r->id, 'index' => $i]))->values(),
        ];
    }
}
