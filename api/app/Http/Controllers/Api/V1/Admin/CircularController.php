<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Circular;
use App\Models\CircularRead;
use App\Models\OrgUnit;
use App\Services\AccessControl;
use App\Services\Audit;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class CircularController extends Controller
{
    public function __construct(private AccessControl $access) {}

    public function index(Request $request)
    {
        $this->authorizeIn('circulars.issue');

        $page = $this->access->scopeQuery(Circular::query(), $request->user(), 'circulars.issue')
            ->with('orgUnit', 'vibhag', 'issuer.profile')
            ->withCount('reads')
            ->latest('published_at')
            ->paginate(25);

        return $this->ok($page->getCollection()->map(fn (Circular $c) => [
            'id' => $c->id,
            'title' => $c->title,
            'body' => $c->body,
            'audience' => trim(($c->vibhag ? $c->vibhag->name.' · ' : '').$c->orgUnit->name),
            'issued_by' => $c->issuer?->profile?->full_name,
            'published_at' => $c->published_at->toIso8601String(),
            'audience_size' => $c->audience_size,
            'reads' => $c->reads_count,
            'read_rate' => $c->audience_size ? round($c->reads_count / $c->audience_size * 100) : null,
            'has_attachment' => (bool) $c->attachment_path,
        ]), meta: ['page' => $page->currentPage(), 'last_page' => $page->lastPage()]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'body' => ['required', 'string', 'max:20000'],
            'org_unit_id' => ['required', 'integer', 'exists:org_units,id'],
            'vibhag_id' => ['nullable', 'integer', 'exists:vibhags,id'],
            'attachment' => ['nullable', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:5120'],
        ]);

        $unit = OrgUnit::findOrFail($data['org_unit_id']);
        if (! $this->access->canInFor($request->user(), 'circulars.issue', $unit, $data['vibhag_id'] ?? null)) {
            throw new ApiException('FORBIDDEN_SCOPE', 'You can only issue circulars for your own area and Vibhag.', 403);
        }

        $path = $request->file('attachment')?->storeAs('circulars', Str::uuid().'.'.$request->file('attachment')->extension(),
            ['disk' => config('abvp.media_disk'), 'visibility' => 'private']);

        $circular = new Circular(collect($data)->except('attachment')->all() + [
            'issued_by' => $request->user()->id,
            'attachment_path' => $path,
            'published_at' => now(),
        ]);
        $circular->setRelation('orgUnit', $unit);
        $circular->audience_size = $circular->audienceQuery()->count();
        $circular->save();

        Audit::record('circular.issued', $circular, null, ['title' => $circular->title, 'audience' => $circular->audience_size]);

        return $this->ok(['id' => $circular->id, 'audience_size' => $circular->audience_size], 201);
    }

    /** Nudge everyone in the audience who has not opened it yet. */
    public function remind(Request $request, Circular $circular)
    {
        if (! $this->access->canInFor($request->user(), 'circulars.issue', $circular->orgUnit, $circular->vibhag_id)) {
            throw new ApiException('FORBIDDEN_SCOPE', 'You are not authorised for this circular.', 403);
        }

        $read = CircularRead::where('circular_id', $circular->id)->pluck('user_id');
        $unread = $circular->audienceQuery()->whereNotIn('user_id', $read)->pluck('user_id');

        AppNotification::sendMany($unread, 'circular_reminder', 'Please read: '.$circular->title, 'From '.$circular->orgUnit->name, ['circular_id' => $circular->id]);

        return $this->ok(['reminded' => $unread->count()]);
    }
}
