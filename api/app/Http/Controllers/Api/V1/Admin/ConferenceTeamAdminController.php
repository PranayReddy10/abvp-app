<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\ConferenceTeamController;
use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\EventTeam;
use App\Models\EventTeamMember;
use App\Services\Audit;
use App\Services\ConferenceTeams;
use App\Support\ApiException;
use App\Support\Mobile;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;

/** Admin panel: build the conference tree (ghats and departments), import and export it. */
class ConferenceTeamAdminController extends Controller
{
    public function index(Request $request, Event $event)
    {
        $this->authorizeIn('events.manage', $event->orgUnit);
        ConferenceTeams::ensureReady();
        $ghats = ConferenceTeamController::present($event, true);
        $people = collect($ghats)->flatMap(fn ($g) => collect($g['heads'])->merge(collect($g['departments'])->flatMap(fn ($d) => $d['people'])));

        return $this->ok([
            'event' => ['id' => $event->id, 'title' => $event->title, 'starts_at' => $event->starts_at->toIso8601String(), 'ends_at' => $event->ends_at->toIso8601String()],
            'ghats' => $ghats,
            'roles' => EventTeamMember::ROLES,
            'totals' => [
                'ghats' => count($ghats),
                'departments' => collect($ghats)->sum(fn ($g) => count($g['departments'])),
                'people' => $people->count(),
                'linked' => $people->where('linked', true)->count(),
                'no_phone' => $people->where('has_mobile', false)->count(),
            ],
        ]);
    }

    /** Load the ghats, departments and names from the organising sheets (safe to repeat). */
    public function loadSheet(Request $request, Event $event)
    {
        $this->authorizeIn('events.manage', $event->orgUnit);
        ConferenceTeams::ensureReady();
        Artisan::call('abvp:load-conference-teams', ['--event' => $event->id, '--keep-details' => ! $request->boolean('set_details')]);
        Audit::record('conference_team.load_sheet', $event);

        return $this->index($request, $event->fresh());
    }

    /** Put ghats (no parent_id) or one ghat's departments in the order given. */
    public function reorder(Request $request, Event $event)
    {
        $this->authorizeIn('events.manage', $event->orgUnit);
        $data = $request->validate([
            'parent_id' => ['nullable', 'integer'],
            'ids' => ['required', 'array', 'max:200'],
            'ids.*' => ['integer'],
        ]);
        DB::transaction(function () use ($data, $event) {
            foreach (array_values($data['ids']) as $i => $id) {
                EventTeam::where('event_id', $event->id)->where('parent_id', $data['parent_id'] ?? null)->whereKey($id)->update(['sort' => $i + 1]);
            }
        });

        return $this->index($request, $event);
    }

    /** Put the people of one ghat or department in the order given. */
    public function reorderMembers(Request $request, EventTeam $team)
    {
        $this->authorizeIn('events.manage', $team->event->orgUnit);
        $data = $request->validate(['ids' => ['required', 'array', 'max:300'], 'ids.*' => ['integer']]);
        DB::transaction(function () use ($data, $team) {
            foreach (array_values($data['ids']) as $i => $id) {
                EventTeamMember::where('team_id', $team->id)->whereKey($id)->update(['sort' => $i + 1]);
            }
        });

        return $this->index($request, $team->event);
    }

    /** Add a ghat (no parent) or a department (parent = a ghat). */
    public function store(Request $request, Event $event)
    {
        $this->authorizeIn('events.manage', $event->orgUnit);
        $data = $request->validate([
            'parent_id' => ['nullable', 'integer'],
            'name' => ['required', 'string', 'max:120'],
            'name_local' => ['nullable', 'string', 'max:120'],
            'color' => ['nullable', 'regex:/^#[0-9A-Fa-f]{6}$/'],
        ]);
        $parent = isset($data['parent_id']) ? EventTeam::where('event_id', $event->id)->whereNull('parent_id')->findOrFail($data['parent_id']) : null;
        if (EventTeam::where('event_id', $event->id)->where('parent_id', $parent?->id)->where('name', $data['name'])->exists()) {
            throw new ApiException('DUPLICATE_TEAM', "{$data['name']} already exists here.");
        }
        $team = EventTeam::create($data + [
            'event_id' => $event->id,
            'kind' => $parent ? 'department' : 'ghat',
            'sort' => (int) EventTeam::where('event_id', $event->id)->where('parent_id', $parent?->id)->max('sort') + 1,
        ]);
        Audit::record('team.created', $team, null, ['name' => $team->name, 'kind' => $team->kind]);

        return $this->ok(['id' => $team->id], 201);
    }

    public function update(Request $request, EventTeam $team)
    {
        $this->authorizeIn('events.manage', $team->event->orgUnit);
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:120'],
            'name_local' => ['nullable', 'string', 'max:120'],
            'color' => ['nullable', 'regex:/^#[0-9A-Fa-f]{6}$/'],
            'sort' => ['sometimes', 'integer', 'min:0', 'max:999'],
        ]);
        $team->update($data);

        return $this->ok(['id' => $team->id]);
    }

    public function destroy(Request $request, EventTeam $team)
    {
        $this->authorizeIn('events.manage', $team->event->orgUnit);
        Audit::record('team.deleted', $team, ['name' => $team->name, 'kind' => $team->kind]);
        $team->delete();

        return $this->ok(['deleted' => true]);
    }

    /**
     * Paste rows: ghat, department, role, name, mobile. Empty department = a ghat role.
     * Existing people (same team + name) get their mobile filled when it was empty.
     */
    public function import(Request $request, Event $event)
    {
        $this->authorizeIn('events.manage', $event->orgUnit);
        $request->validate(['csv' => ['required', 'string', 'max:200000']]);
        $roleByLabel = collect(EventTeamMember::ROLES)->mapWithKeys(fn ($l, $k) => [mb_strtolower($l) => $k, $k => $k]);
        $stats = ['ghats' => 0, 'departments' => 0, 'people' => 0, 'updated' => 0, 'skipped' => []];

        DB::transaction(function () use ($request, $event, $roleByLabel, &$stats) {
            foreach (preg_split('/\r\n|\r|\n/', trim($request->input('csv'))) as $i => $line) {
                $cols = array_map('trim', str_getcsv($line));
                if (count($cols) < 4 || mb_strtolower($cols[0]) === 'ghat') {
                    continue; // header or blank
                }
                [$ghatName, $deptName, $roleText, $name] = $cols;
                $mobile = $cols[4] ?? '';
                $role = $roleByLabel[mb_strtolower($roleText)] ?? null;
                if (! $ghatName || ! $name || ! $role) {
                    $stats['skipped'][] = 'Line '.($i + 1).': '.mb_substr($line, 0, 80);

                    continue;
                }
                $ghat = EventTeam::firstOrCreate(['event_id' => $event->id, 'parent_id' => null, 'name' => $ghatName], ['kind' => 'ghat', 'sort' => 999]);
                $stats['ghats'] += (int) $ghat->wasRecentlyCreated;
                $team = $ghat;
                if ($deptName !== '') {
                    $team = EventTeam::firstOrCreate(['event_id' => $event->id, 'parent_id' => $ghat->id, 'name' => $deptName], ['kind' => 'department', 'sort' => 999]);
                    $stats['departments'] += (int) $team->wasRecentlyCreated;
                }
                $member = EventTeamMember::firstOrNew(['team_id' => $team->id, 'name' => $name]);
                $isNew = ! $member->exists;
                $member->role = $role;
                if ($mobile !== '' && Mobile::normalize($mobile) && ! $member->mobile) {
                    $member->mobile = $mobile;
                    $stats['updated'] += (int) ! $isNew;
                }
                $member->linkByMobile();
                $member->save();
                $stats['people'] += (int) $isNew;
            }
        });
        Audit::record('team.imported', $event, null, collect($stats)->except('skipped')->all());

        return $this->ok($stats);
    }

    public function export(Request $request, Event $event)
    {
        $this->authorizeIn('events.manage', $event->orgUnit);
        $rows = [['ghat', 'department', 'role', 'name', 'mobile', 'signed_in']];
        foreach (ConferenceTeamController::present($event, true) as $g) {
            foreach ($g['heads'] as $p) {
                $rows[] = [$g['name'], '', $p['role_label'], $p['name'], $p['mobile'], $p['linked'] ? 'yes' : 'no'];
            }
            foreach ($g['departments'] as $d) {
                if (! $d['people']) {
                    $rows[] = [$g['name'], $d['name'], '', '', '', ''];
                }
                foreach ($d['people'] as $p) {
                    $rows[] = [$g['name'], $d['name'], $p['role_label'], $p['name'], $p['mobile'], $p['linked'] ? 'yes' : 'no'];
                }
            }
        }
        $out = fopen('php://temp', 'r+');
        fwrite($out, "\xEF\xBB\xBF"); // so Excel opens Hindi/Telugu names correctly
        foreach ($rows as $r) {
            fputcsv($out, $r);
        }
        rewind($out);

        return response(stream_get_contents($out), 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="conference-team.csv"',
        ]);
    }
}
