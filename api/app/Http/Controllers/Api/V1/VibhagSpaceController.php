<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Models\Responsibility;
use App\Models\RoleAssignment;
use App\Models\User;
use App\Models\Vibhag;
use App\Models\VibhagPost;
use App\Services\AccessControl;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\URL;

/** Vibhag spaces: join, leave, updates and people. */
class VibhagSpaceController extends Controller
{
    public function index(Request $request)
    {
        $mine = $request->user()->vibhags()->pluck('vibhags.id')->all();

        $vibhags = Vibhag::where('is_active', true)->withCount('members')->orderBy('sort_order')->orderBy('name')->get();

        return $this->ok($vibhags->map(fn (Vibhag $v) => [
            'id' => $v->id,
            'name' => $v->name,
            'code' => $v->code,
            'description' => $v->description,
            'members_count' => $v->members_count,
            'is_member' => in_array($v->id, $mine, true),
        ]));
    }

    public function show(Request $request, Vibhag $vibhag)
    {
        $user = $request->user();
        $coordinators = Responsibility::where('vibhag_id', $vibhag->id)
            ->whereNull('ends_on')
            ->with('orgUnit', 'vibhag')
            ->get()
            ->map(fn (Responsibility $r) => [
                'name' => User::find($r->user_id)?->profile?->full_name,
                'member_id' => User::find($r->user_id)?->profile?->member_id,
                'title' => $r->title,
                'place' => $r->orgUnit?->name,
            ]);

        return $this->ok([
            'id' => $vibhag->id,
            'name' => $vibhag->name,
            'code' => $vibhag->code,
            'description' => $vibhag->description,
            'members_count' => $vibhag->members()->count(),
            'is_member' => $user->vibhags()->where('vibhags.id', $vibhag->id)->exists(),
            'can_post' => app(AccessControl::class)->grants($user, 'vibhag.post')
                ->contains(fn (RoleAssignment $r) => $r->vibhag_id === null || $r->vibhag_id === $vibhag->id),
            'coordinators' => $coordinators,
        ]);
    }

    public function join(Request $request, Vibhag $vibhag)
    {
        $this->requireMember($request->user());
        $request->user()->vibhags()->syncWithoutDetaching([$vibhag->id => ['joined_at' => now()]]);

        return $this->ok(['joined' => true]);
    }

    public function leave(Request $request, Vibhag $vibhag)
    {
        $request->user()->vibhags()->detach($vibhag->id);

        return $this->ok(['left' => true]);
    }

    /** Updates for this Vibhag posted at the member's unit or any level above it. */
    public function posts(Request $request, Vibhag $vibhag)
    {
        $user = $request->user();
        $access = app(AccessControl::class);

        $query = VibhagPost::where('vibhag_id', $vibhag->id)->with('author.profile', 'orgUnit')->latest('id');

        $unitIds = collect(explode('/', (string) $user->profile?->orgUnit?->path))->filter()->values();
        // Admins also see posts anywhere inside their own area.
        $scoped = $access->scopeQuery(VibhagPost::query(), $user, 'vibhag.post')->pluck('id');

        $query->where(fn ($q) => $q->whereIn('org_unit_id', $unitIds)->orWhereIn('id', $scoped));

        $page = $query->paginate(20);

        return $this->ok($page->getCollection()->map(fn (VibhagPost $p) => [
            'id' => $p->id,
            'body' => $p->body,
            'author' => $p->author?->profile?->full_name ?? $p->author?->name,
            'place' => $p->orgUnit?->name,
            'at' => $p->created_at?->toIso8601String(),
        ]), meta: ['page' => $page->currentPage(), 'last_page' => $page->lastPage()]);
    }

    public function storePost(Request $request, Vibhag $vibhag, AccessControl $access)
    {
        $data = $request->validate([
            'body' => ['required', 'string', 'min:3', 'max:2000'],
            'org_unit_id' => ['nullable', 'integer', 'exists:org_units,id'],
        ]);

        $unit = isset($data['org_unit_id']) ? OrgUnit::find($data['org_unit_id']) : $access->primaryScope($request->user());

        if (! $access->canInFor($request->user(), 'vibhag.post', $unit, $vibhag->id)) {
            throw new ApiException('FORBIDDEN_SCOPE', 'Only coordinators of this Vibhag can post here.', 403);
        }

        $post = VibhagPost::create(['vibhag_id' => $vibhag->id, 'org_unit_id' => $unit->id, 'author_id' => $request->user()->id, 'body' => $data['body']]);

        return $this->ok(['id' => $post->id], 201);
    }

    /** Members of the Vibhag in the viewer's district (or state for state-level viewers). */
    public function members(Request $request, Vibhag $vibhag)
    {
        $this->requireMember($request->user());
        $home = $request->user()->profile->orgUnit;
        $area = $home?->ancestorOfType('district') ?? $home;

        $page = MemberProfile::where('membership_status', MemberProfile::STATUS_APPROVED)
            ->whereIn('user_id', fn ($s) => $s->select('user_id')->from('member_vibhag')->where('vibhag_id', $vibhag->id))
            ->when($area, fn ($q) => $q->whereIn('org_unit_id', OrgUnit::within($area)->select('id')))
            ->with('orgUnit')
            ->orderBy('full_name')
            ->paginate(30);

        return $this->ok($page->getCollection()->map(fn (MemberProfile $p) => [
            'member_id' => $p->member_id,
            'full_name' => $p->full_name,
            'place' => $p->orgUnit?->name,
            'photo_url' => $p->photo_path ? URL::temporarySignedRoute('media.photo', now()->addMinutes(30), ['profile' => $p->id]) : null,
        ]), meta: ['page' => $page->currentPage(), 'last_page' => $page->lastPage(), 'area' => $area?->name]);
    }

    private function requireMember(User $user): void
    {
        if (! $user->isApprovedMember()) {
            throw new ApiException('NOT_A_MEMBER', 'This is available after your membership is approved.', 403);
        }
    }
}
