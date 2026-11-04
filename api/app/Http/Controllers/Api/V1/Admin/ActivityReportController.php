<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\ActivityReportController as Present;
use App\Http\Controllers\Controller;
use App\Models\ActivityReport;
use App\Models\OrgUnit;
use App\Services\AccessControl;
use Illuminate\Http\Request;

class ActivityReportController extends Controller
{
    public function index(Request $request, AccessControl $access)
    {
        $this->authorizeIn('reports.view');
        $request->validate([
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
            'programme_type' => ['nullable', 'string'],
            'vibhag_id' => ['nullable', 'integer'],
            'org_unit_id' => ['nullable', 'integer'],
        ]);

        $query = $access->scopeQuery(ActivityReport::query(), $request->user(), 'reports.view')
            ->with('orgUnit', 'vibhag', 'submitter.profile')
            ->when($request->input('from'), fn ($q, $d) => $q->whereDate('held_on', '>=', $d))
            ->when($request->input('to'), fn ($q, $d) => $q->whereDate('held_on', '<=', $d))
            ->when($request->input('programme_type'), fn ($q, $t) => $q->where('programme_type', $t))
            ->when($request->input('vibhag_id'), fn ($q, $v) => $q->where('vibhag_id', $v))
            ->when($request->filled('org_unit_id') ? OrgUnit::find($request->integer('org_unit_id')) : null,
                fn ($q, $u) => $q->whereIn('org_unit_id', OrgUnit::within($u)->select('id')))
            ->latest('held_on')->latest('id');

        $totals = (clone $query)->reorder()->selectRaw('count(*) as reports, coalesce(sum(participants),0) as participants')->first();
        $page = $query->paginate(25);

        return $this->ok($page->getCollection()->map(fn ($r) => Present::present($r)), meta: [
            'page' => $page->currentPage(),
            'last_page' => $page->lastPage(),
            'total_reports' => (int) $totals->reports,
            'total_participants' => (int) $totals->participants,
        ]);
    }
}
