<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
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
            'actor' => $l->actor?->profile?->full_name ?? $l->actor?->name,
            'subject' => $l->subject_type ? "{$l->subject_type} #{$l->subject_id}" : null,
            'after' => $l->after,
            'ip' => $l->ip,
            'at' => $l->created_at?->toIso8601String(),
        ]), meta: ['page' => $page->currentPage(), 'last_page' => $page->lastPage()]);
    }
}
