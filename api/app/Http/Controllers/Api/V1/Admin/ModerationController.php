<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\FeedController;
use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\MemberProfile;
use App\Models\Post;
use App\Services\AccessControl;
use App\Services\Audit;
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
        $request->validate(['status' => ['nullable', 'in:all,reported,hidden'], 'q' => ['nullable', 'string', 'max:60'], 'before' => ['nullable', 'integer']]);
        $this->authorizeIn('feed.moderate');
        $status = $request->input('status', 'reported');

        $posts = Post::query()
            ->when(! $this->national($request), fn ($q) => $q->whereIn('user_id', $this->access->scopeQuery(MemberProfile::query(), $request->user(), 'feed.moderate')->select('user_id')))
            ->when($status === 'hidden', fn ($q) => $q->whereNotNull('hidden_at'))
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
            'hidden_reason' => $p->hidden_reason,
            'at' => $p->created_at->toIso8601String(),
        ]));
    }

    public function act(Request $request, Post $post)
    {
        $data = $request->validate(['action' => ['required', 'in:hide,restore,dismiss'], 'reason' => ['nullable', 'required_if:action,hide', 'string', 'max:200']]);
        $unit = $post->author->profile?->orgUnit;
        if (! $this->national($request) && ! $this->access->canIn($request->user(), 'feed.moderate', $unit)) {
            throw new ApiException('FORBIDDEN_SCOPE', "This member is outside your area.", 403);
        }

        match ($data['action']) {
            'hide' => $post->forceFill(['hidden_at' => now(), 'hidden_by' => $request->user()->id, 'hidden_reason' => $data['reason'], 'reviewed_at' => now()])->save(),
            'restore' => $post->forceFill(['hidden_at' => null, 'hidden_by' => null, 'hidden_reason' => null, 'reviewed_at' => now()])->save(),
            'dismiss' => $post->forceFill(['reviewed_at' => now()])->save(),
        };
        if ($data['action'] === 'hide') {
            AppNotification::sendMany([$post->user_id], 'post_hidden', 'One of your posts was hidden', $data['reason'], ['post_id' => $post->id]);
        }
        Audit::record('post.'.$data['action'], $post, null, ['reason' => $data['reason'] ?? null]);

        return $this->ok(['hidden' => $post->hidden_at !== null]);
    }

    /** National and super admins look after posts from everyone, including people with no district yet. */
    private function national(Request $request): bool
    {
        return $this->access->grants($request->user(), 'feed.moderate')
            ->contains(fn ($r) => $r->orgUnit && ($r->orgUnit->type === 'national' || $r->orgUnit->parent_id === null));
    }
}
