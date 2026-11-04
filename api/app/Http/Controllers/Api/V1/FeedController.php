<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\MemberProfile;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\User;
use App\Services\AccessControl;
use App\Support\ApiException;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;

/** Community feed for approved members: posts, photos, likes, comments, reposts, follows. */
class FeedController extends Controller
{
    public const REPORT_REASONS = ['abuse' => 'Abusive or hateful', 'false_info' => 'False information', 'spam' => 'Spam', 'private_info' => "Shares someone's private details", 'other' => 'Something else'];

    public function feed(Request $request)
    {
        $data = $request->validate([
            'tab' => ['nullable', 'in:for_you,following'],
            'tag' => ['nullable', 'string', 'max:40'],
            'before' => ['nullable', 'integer'],
        ]);
        $viewer = $this->member($request);

        $q = Post::visibleTo($viewer)->latest('id');
        if (($data['tab'] ?? 'for_you') === 'following') {
            $q->whereIn('user_id', DB::table('follows')->where('follower_id', $viewer->id)->select('followee_id'));
        }
        if (! empty($data['tag'])) {
            $q->whereIn('id', DB::table('post_tags')->where('tag', mb_strtolower(ltrim($data['tag'], '#')))->select('post_id'));
        }
        if (! empty($data['before'])) {
            $q->where('id', '<', $data['before']);
        }

        $posts = $q->limit(20)->get();

        return $this->ok($this->present($posts, $viewer), meta: ['next_before' => $posts->count() === 20 ? $posts->last()->id : null]);
    }

    public function memberPosts(Request $request, string $memberId)
    {
        $viewer = $this->member($request);
        $userId = MemberProfile::where('member_id', $memberId)->value('user_id') ?? abort(404);
        $posts = Post::visibleTo($viewer)->where('user_id', $userId)->latest('id')
            ->when($request->integer('before'), fn ($q, $b) => $q->where('id', '<', $b))->limit(20)->get();

        return $this->ok($this->present($posts, $viewer), meta: ['next_before' => $posts->count() === 20 ? $posts->last()->id : null]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'body' => ['nullable', 'required_without_all:photos,repost_of_id', 'string', 'max:500'],
            'audience' => ['required', 'in:members,area,vibhag'],
            'vibhag_id' => ['nullable', 'required_if:audience,vibhag', 'integer', 'exists:vibhags,id'],
            'repost_of_id' => ['nullable', 'integer', 'exists:posts,id'],
            'photos' => ['nullable', 'array', 'max:4'],
            'photos.*' => ['image', 'mimes:jpeg,png,webp', 'max:3072'],
        ]);
        $viewer = $this->member($request);

        if ($data['audience'] === 'vibhag' && ! $viewer->vibhags()->where('vibhags.id', $data['vibhag_id'])->exists()) {
            throw new ApiException('NOT_IN_VIBHAG', 'You can post to a Vibhag only after joining it.', 403);
        }
        $original = null;
        if (! empty($data['repost_of_id'])) {
            $original = Post::visibleTo($viewer)->findOrFail($data['repost_of_id']);
            $original = $original->original ?? $original; // repost the source, not a repost
            if (Post::where('user_id', $viewer->id)->where('repost_of_id', $original->id)->whereNull('body')->exists() && empty($data['body'])) {
                throw new ApiException('ALREADY_REPOSTED', 'You have already reposted this.', 409);
            }
        }

        $disk = config('abvp.media_disk');
        $photos = collect($request->file('photos', []))->map(fn ($f) => $f->storeAs('posts/'.now()->format('Y/m'), Str::uuid().'.'.$f->extension(), ['disk' => $disk, 'visibility' => 'private']))->all();

        $post = DB::transaction(function () use ($data, $viewer, $photos, $original) {
            $post = Post::create([
                'user_id' => $viewer->id,
                'body' => $data['body'] ?? null,
                'audience' => $data['audience'],
                'org_unit_id' => $data['audience'] === 'area' ? ($viewer->profile->orgUnit?->ancestorOfType('district') ?? $viewer->profile->orgUnit)?->id : null,
                'vibhag_id' => $data['audience'] === 'vibhag' ? $data['vibhag_id'] : null,
                'repost_of_id' => $original?->id,
                'photos' => $photos ?: null,
            ]);
            foreach (Post::extractTags($post->body) as $tag) {
                DB::table('post_tags')->insert(['post_id' => $post->id, 'tag' => $tag, 'created_at' => now()]);
            }
            if ($original) {
                $original->increment('reposts_count');
            }

            return $post;
        });

        if ($original && $original->user_id !== $viewer->id) {
            AppNotification::sendMany([$original->user_id], 'post_repost', $viewer->profile->full_name.' reposted your post', Str::limit((string) $original->body, 80), ['post_id' => $original->id]);
        }

        return $this->ok($this->present(new \Illuminate\Database\Eloquent\Collection([$post->fresh()]), $viewer)[0], 201);
    }

    public function show(Request $request, int $id)
    {
        $viewer = $this->member($request);
        $post = Post::visibleTo($viewer)->findOrFail($id);
        $comments = PostComment::where('post_id', $post->id)->with('author.profile')->orderBy('id')->limit(200)->get();

        return $this->ok($this->present(new \Illuminate\Database\Eloquent\Collection([$post]), $viewer)[0] + [
            'replies' => $comments->map(fn ($c) => [
                'id' => $c->id,
                'body' => $c->body,
                'author' => $this->person($c->author),
                'is_mine' => $c->user_id === $viewer->id,
                'at' => $c->created_at->toIso8601String(),
            ]),
        ]);
    }

    public function destroy(Request $request, Post $post, AccessControl $access)
    {
        $viewer = $request->user();
        if ($post->user_id !== $viewer->id) {
            throw new ApiException('FORBIDDEN', 'You can delete only your own posts. Report it if something is wrong.', 403);
        }
        if ($post->repost_of_id) {
            Post::whereKey($post->repost_of_id)->where('reposts_count', '>', 0)->decrement('reposts_count');
        }
        $post->delete();

        return $this->ok(['deleted' => true]);
    }

    public function like(Request $request, int $id)
    {
        $viewer = $this->member($request);
        $post = Post::visibleTo($viewer)->findOrFail($id);

        $liked = DB::transaction(function () use ($post, $viewer) {
            $deleted = DB::table('post_likes')->where('post_id', $post->id)->where('user_id', $viewer->id)->delete();
            if ($deleted) {
                Post::whereKey($post->id)->where('likes_count', '>', 0)->decrement('likes_count');

                return false;
            }
            try {
                DB::table('post_likes')->insert(['post_id' => $post->id, 'user_id' => $viewer->id, 'created_at' => now()]);
                Post::whereKey($post->id)->increment('likes_count');
            } catch (UniqueConstraintViolationException) {
                // A double tap: already liked.
            }

            return true;
        });

        return $this->ok(['liked' => $liked, 'likes_count' => Post::whereKey($post->id)->value('likes_count')]);
    }

    public function comment(Request $request, int $id)
    {
        $data = $request->validate(['body' => ['required', 'string', 'min:1', 'max:500']]);
        $viewer = $this->member($request);
        $post = Post::visibleTo($viewer)->whereNull('hidden_at')->findOrFail($id);

        $c = DB::transaction(function () use ($post, $viewer, $data) {
            $c = PostComment::create(['post_id' => $post->id, 'user_id' => $viewer->id, 'body' => $data['body']]);
            $post->increment('comments_count');

            return $c;
        });
        if ($post->user_id !== $viewer->id) {
            AppNotification::sendMany([$post->user_id], 'post_comment', $viewer->profile->full_name.' replied to your post', Str::limit($data['body'], 80), ['post_id' => $post->id]);
        }

        return $this->ok(['id' => $c->id, 'body' => $c->body, 'author' => $this->person($viewer), 'is_mine' => true, 'at' => $c->created_at->toIso8601String()], 201);
    }

    public function deleteComment(Request $request, PostComment $comment)
    {
        $viewer = $request->user();
        if ($comment->user_id !== $viewer->id && $comment->post->user_id !== $viewer->id) {
            throw new ApiException('FORBIDDEN', 'Only the person who wrote it, or the post author, can remove this reply.', 403);
        }
        DB::transaction(function () use ($comment) {
            Post::whereKey($comment->post_id)->where('comments_count', '>', 0)->decrement('comments_count');
            $comment->delete();
        });

        return $this->ok(['deleted' => true]);
    }

    public function report(Request $request, int $id)
    {
        $data = $request->validate(['reason' => ['required', 'in:'.implode(',', array_keys(self::REPORT_REASONS))], 'note' => ['nullable', 'string', 'max:300']]);
        $viewer = $this->member($request);
        $post = Post::visibleTo($viewer)->findOrFail($id);
        if ($post->user_id === $viewer->id) {
            throw new ApiException('OWN_POST', 'You cannot report your own post. Delete it instead.');
        }

        try {
            DB::table('post_reports')->insert(['post_id' => $post->id, 'user_id' => $viewer->id, 'reason' => $data['reason'], 'note' => $data['note'] ?? null, 'created_at' => now()]);
            $post->increment('reports_count');
        } catch (UniqueConstraintViolationException) {
            return $this->ok(['reported' => true, 'already' => true]);
        }

        // Enough people objecting hides it until an admin looks.
        if ($post->fresh()->reports_count >= Post::AUTO_HIDE_REPORTS && ! $post->hidden_at && ! $post->reviewed_at) {
            $post->forceFill(['hidden_at' => now(), 'hidden_reason' => 'Hidden after several reports, waiting for review'])->save();
        }

        return $this->ok(['reported' => true]);
    }

    public function follow(Request $request, string $memberId)
    {
        $viewer = $this->member($request);
        $target = MemberProfile::where('member_id', $memberId)->where('membership_status', 'approved')->first()?->user ?? abort(404);
        if ($target->id === $viewer->id) {
            throw new ApiException('SELF_FOLLOW', 'You cannot follow yourself.');
        }

        $deleted = DB::table('follows')->where('follower_id', $viewer->id)->where('followee_id', $target->id)->delete();
        if (! $deleted) {
            DB::table('follows')->insertOrIgnore(['follower_id' => $viewer->id, 'followee_id' => $target->id, 'created_at' => now()]);
            AppNotification::sendMany([$target->id], 'new_follower', $viewer->profile->full_name.' started following you', null, ['member_id' => $viewer->profile->member_id]);
        }

        return $this->ok(['following' => ! $deleted, 'followers' => DB::table('follows')->where('followee_id', $target->id)->count()]);
    }

    public function trending(Request $request)
    {
        $this->member($request);
        $tags = DB::table('post_tags')->join('posts', 'posts.id', '=', 'post_tags.post_id')
            ->whereNull('posts.hidden_at')->where('posts.audience', 'members')->where('post_tags.created_at', '>=', now()->subDays(7))
            ->selectRaw('tag, count(*) n')->groupBy('tag')->orderByDesc('n')->limit(10)->get();

        return $this->ok($tags->map(fn ($t) => ['tag' => $t->tag, 'posts' => (int) $t->n]));
    }

    public static function counts(User $user, ?User $viewer = null): array
    {
        return [
            'posts' => Post::where('user_id', $user->id)->whereNull('hidden_at')->count(),
            'followers' => DB::table('follows')->where('followee_id', $user->id)->count(),
            'following' => DB::table('follows')->where('follower_id', $user->id)->count(),
            'is_following' => $viewer ? DB::table('follows')->where('follower_id', $viewer->id)->where('followee_id', $user->id)->exists() : false,
        ];
    }

    private function member(Request $request): User
    {
        $u = $request->user();
        if (! $u->isApprovedMember()) {
            throw new ApiException('NOT_A_MEMBER', 'The community feed is for approved members.', 403);
        }

        return $u;
    }

    private function person(?User $u): array
    {
        $p = $u?->profile;

        return [
            'name' => $p?->full_name ?? $u?->name,
            'member_id' => $p?->member_id,
            'verified' => (bool) $p?->isVerified(),
            'place' => $p?->orgUnit?->name,
            'photo_url' => $p?->photo_path ? URL::temporarySignedRoute('media.photo', now()->addHour(), ['profile' => $p->id]) : null,
        ];
    }

    /** @param Collection<int, Post> $posts */
    private function present(Collection $posts, User $viewer): array
    {
        $posts->load('author.profile.orgUnit', 'vibhag', 'original.author.profile.orgUnit');
        $ids = $posts->pluck('id')->merge($posts->pluck('repost_of_id')->filter());
        $liked = DB::table('post_likes')->where('user_id', $viewer->id)->whereIn('post_id', $ids)->pluck('post_id')->flip();
        $reposted = Post::where('user_id', $viewer->id)->whereIn('repost_of_id', $ids)->pluck('repost_of_id')->flip();

        $one = function (Post $p) use ($viewer, $liked, $reposted) {
            return [
                'id' => $p->id,
                'author' => $this->person($p->author),
                'body' => $p->body,
                'audience' => $p->audience,
                'audience_label' => match ($p->audience) { 'area' => 'Only my district', 'vibhag' => $p->vibhag?->name ?? 'Vibhag', default => 'All members' },
                'photo_urls' => collect($p->photos ?? [])->keys()->map(fn ($i) => URL::temporarySignedRoute('media.post', now()->addHour(), ['post' => $p->id, 'index' => $i]))->values(),
                'likes' => $p->likes_count,
                'comments' => $p->comments_count,
                'reposts' => $p->reposts_count,
                'liked' => $liked->has($p->id),
                'reposted' => $reposted->has($p->id),
                'is_mine' => $p->user_id === $viewer->id,
                'hidden' => $p->hidden_at !== null,
                'at' => $p->created_at->toIso8601String(),
            ];
        };

        return $posts->map(function (Post $p) use ($one) {
            $row = $one($p);
            $row['repost_of'] = $p->original && ! $p->original->hidden_at ? $one($p->original) : null;

            return $row;
        })->values()->all();
    }
}
