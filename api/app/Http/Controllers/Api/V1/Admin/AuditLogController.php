<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Event;
use App\Models\MemberProfile;
use App\Models\User;
use App\Support\Mobile;
use Illuminate\Http\Request;

class AuditLogController extends Controller
{
    public function index(Request $request)
    {
        $this->authorizeIn('audit.view');
        $request->validate(['action' => ['nullable', 'string', 'max:64']]);

        $page = AuditLog::with('actor.profile')
            ->when($request->input('action'), fn ($q, $a) => $q->where('action', 'like', "$a%"))
            ->latest('id')
            ->paginate(50);

        return $this->ok($page->getCollection()->map(fn (AuditLog $l) => [
            'id' => $l->id,
            'action' => $l->action,
            'actor' => $l->actor?->profile?->full_name ?: $l->actor?->name ?? ($l->subject_type === 'User' && str_starts_with($l->action, 'auth.') ? 'The person themselves' : null),
            'subject' => $this->subject($l),
            'after' => $l->after,
            'ip' => $l->ip,
            'at' => $l->created_at?->toIso8601String(),
        ]), meta: ['page' => $page->currentPage(), 'last_page' => $page->lastPage()]);
    }

    /** A readable name for what was changed: the person's name rather than "User #2". */
    private function subject(AuditLog $l): ?string
    {
        if (! $l->subject_type) {
            return null;
        }
        $label = match ($l->subject_type) {
            'User' => ($u = User::with('profile')->find($l->subject_id))
                ? trim(($u->profile?->full_name ?: $u->name ?: 'New account').' · '.Mobile::mask($u->mobile))
                : null,
            'MemberProfile' => MemberProfile::find($l->subject_id)?->full_name,
            'Event' => Event::find($l->subject_id)?->title,
            default => null,
        };

        return $label ?? "{$l->subject_type} #{$l->subject_id}";
    }
}
