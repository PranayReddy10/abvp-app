<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Meeting;
use App\Services\AccessControl;
use Illuminate\Http\Request;

/** Meetings called for areas inside the admin's scope (one-to-one calls stay private). */
class MeetingController extends Controller
{
    public function index(Request $request, AccessControl $access)
    {
        $this->authorizeIn('meetings.schedule');
        $request->validate(['when' => ['nullable', 'in:upcoming,past']]);
        $upcoming = $request->input('when', 'upcoming') === 'upcoming';

        $page = $access->scopeQuery(Meeting::query(), $request->user(), 'meetings.schedule')
            ->where('kind', 'meeting')
            ->when($upcoming, fn ($q) => $q->where('ends_at', '>=', now())->orderBy('starts_at'),
                fn ($q) => $q->where('ends_at', '<', now())->orderByDesc('starts_at'))
            ->with('orgUnit', 'vibhag', 'organiser.profile')
            ->withCount([
                'invitees',
                'invitees as going_count' => fn ($q) => $q->where('rsvp', 'going'),
                'invitees as attended_count' => fn ($q) => $q->whereNotNull('joined_at'),
                'actionItems as open_items_count' => fn ($q) => $q->whereNull('done_at'),
            ])
            ->paginate(25);

        return $this->ok($page->getCollection()->map(fn (Meeting $m) => [
            'id' => $m->id,
            'title' => $m->title,
            'starts_at' => $m->starts_at->toIso8601String(),
            'ends_at' => $m->ends_at->toIso8601String(),
            'mode' => $m->mode,
            'provider' => $m->provider,
            'venue' => $m->venue,
            'status' => $m->status,
            'audience' => trim(($m->vibhag ? $m->vibhag->name.' · ' : '').$m->orgUnit?->name),
            'organiser' => $m->organiser?->profile?->full_name,
            'invited' => $m->invitees_count,
            'going' => $m->going_count,
            'attended' => $m->attended_count,
            'open_action_items' => $m->open_items_count,
            'has_minutes' => (bool) $m->minutes,
        ]), meta: ['page' => $page->currentPage(), 'last_page' => $page->lastPage()]);
    }
}
