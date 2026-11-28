<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\FeedController;
use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\MemberProfile;
use App\Models\Post;
use App\Services\AccessControl;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\URL;

/** Community posts inside the admin's area: all of them, the reported ones, and the hidden ones. */
class ModerationController extends Controller
{
    public function __construct(private AccessControl $access) {}

    public function index(Request $request)
    {
        $request->validate(['status' => ['nullable', 'in:all,reported,hidden,pending'], 'q' => ['nullable', 'string', 'max:60'], 'before' => ['nullable', 'integer']]);
        $this->authorizeIn('feed.moderate');
        $status = $request->input('status', 'reported');

        $posts = Post::query()
            ->when(! $this->national($request), fn ($q) => $q->whereIn('user_id', $this->access->scopeQuery(MemberProfile::query(), $request->user(), 'feed.moderate')->select('user_id')))
            ->when($status === 'hidden', fn ($q) => Post::canHoldForApproval() ? $q->whereNotNull('hidden_at')->whereNull('pending_at') : $q->whereNotNull('hidden_at'))
            ->when($status === 'pending', fn ($q) => Post::canHoldForApproval() ? $q->whereNotNull('pending_at')->whereNotNull('hidden_at') : $q->whereRaw('1 = 0'))
            ->when($status === 'reported', fn ($q) => $q->where('reports_count', '>', 0)->whereNull('reviewed_at')->orderByDesc('reports_count'))
            ->when($request->input('q'), fn ($q, $t) => $q->where('body', 'like', "%$t%"))
            ->when($request->integer('before'), fn ($q, $b) => $q->where('id', '<', $b))
            ->with('author.profile.orgUnit')->latest('id')->limit(50)->get();

        $reports = DB::table('post_reports')->whereIn('post_id', $posts->pluck('id'))->get()->groupBy('post_id');

        return $this->ok($posts->map(fn (Post $p) => [
            'id' => $p->id,
            'body' => $p->body,
            'photo_urls' => collect($p->photos ?? [])->keys()->map(fn ($i) => URL::temporarySignedRoute('media.post', now()->addHour(), ['post' => $p->id, 'index' => $i]))->values(),
            'author' => ['name' => $p->author->profile?->full_name ?: $p->author->name, 'member_id' => $p->author->profile?->member_id, 'place' => $p->author->profile?->orgUnit?->name ?? $p->author->prant, 'verified' => (bool) $p->author->profile?->isVerified(), 'mobile' => \App\Support\Mobile::mask($p->author->mobile)],
            'is_repost' => $p->repost_of_id !== null && ! $p->body,
            'reposts' => $p->reposts_count,
            'audience' => $p->audience,
            'likes' => $p->likes_count, 'comments' => $p->comments_count,
            'reports_count' => $p->reports_count,
            'reasons' => collect($reports[$p->id] ?? [])->groupBy('reason')->map(fn ($g, $r) => ['reason' => FeedController::REPORT_REASONS[$r] ?? $r, 'count' => $g->count()])->values(),
            'notes' => collect($reports[$p->id] ?? [])->pluck('note')->filter()->values(),
            'hidden' => $p->hidden_at !== null,
            'pending' => $p->pending_at !== null && $p->hidden_at !== null,
            'hidden_reason' => $p->hidden_reason,
            'at' => $p->created_at->toIso8601String(),
        ]));
    }

    public function act(Request $request, Post $post)
    {
        $data = $request->validate(['action' => ['required', 'in:hide,restore,dismiss,approve'], 'reason' => ['nullable', 'required_if:action,hide', 'string', 'max:200']]);
        $unit = $post->author->profile?->orgUnit;
        if (! $this->national($request) && ! $this->access->canIn($request->user(), 'feed.moderate', $unit)) {
            throw new ApiException('FORBIDDEN_SCOPE', "This member is outside your area.", 403);
        }

        $wasPending = Post::canHoldForApproval() && $post->pending_at !== null;
        match ($data['action']) {
            'hide' => $post->forceFill(['hidden_at' => now(), 'hidden_by' => $request->user()->id, 'hidden_reason' => $data['reason'], 'reviewed_at' => now()] + ($wasPending ? ['pending_at' => null] : []))->save(),
            'restore', 'approve' => $post->forceFill(['hidden_at' => null, 'hidden_by' => null, 'hidden_reason' => null, 'reviewed_at' => now()] + ($wasPending ? ['pending_at' => null] : []))->save(),
            'dismiss' => $post->forceFill(['reviewed_at' => now()])->save(),
        };
        if ($data['action'] === 'hide') {
            AppNotification::sendMany([$post->user_id], 'post_hidden', $wasPending ? 'Your post was not approved' : 'One of your posts was hidden', $data['reason'], ['post_id' => $post->id]);
        }
        if ($wasPending && in_array($data['action'], ['approve', 'restore'], true)) {
            AppNotification::sendMany([$post->user_id], 'post_approved', 'Your post is live', \Illuminate\Support\Str::limit((string) $post->body, 80), ['post_id' => $post->id]);
        }

        return $this->ok(['hidden' => $post->hidden_at !== null]);
    }

    /** Community settings: whether new posts wait for approval, and how many are waiting. */
    public function settings(Request $request)
    {
        $this->authorizeIn('feed.moderate');

        $ready = Post::canHoldForApproval();

        return $this->ok([
            'approval_required' => Post::approvalRequired(),
            'pending' => $ready ? Post::whereNotNull('pending_at')->whereNotNull('hidden_at')->count() : 0,
            // False until `php artisan migrate --force` has added posts.pending_at on the server.
            'ready' => $ready,
        ]);
    }

    public function saveSettings(Request $request)
    {
        $this->authorizeIn('feed.moderate');
        $data = $request->validate(['approval_required' => ['required', 'boolean']]);
        if ($data['approval_required'] && ! Post::canHoldForApproval()) {
            throw new ApiException('SETUP_NEEDED', 'The server needs its database update first. On the server run: cd api && php artisan migrate --force && php artisan optimize', 503);
        }
        \App\Models\Setting::putMany(['community.approval_required' => $data['approval_required'] ? '1' : '0'], $request->user()->id);

        return $this->settings($request);
    }

    /** National and super admins look after posts from everyone, including people with no district yet. */
    private function national(Request $request): bool
    {
        return $this->access->grants($request->user(), 'feed.moderate')
            ->contains(fn ($r) => $r->orgUnit && ($r->orgUnit->type === 'national' || $r->orgUnit->parent_id === null));
    }
}
