<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Circular;
use App\Models\CircularRead;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\URL;

class CircularController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $read = CircularRead::where('user_id', $user->id)->pluck('circular_id')->flip();

        $page = Circular::for($user)->with('orgUnit', 'vibhag')->latest('published_at')->paginate(20);

        return $this->ok($page->getCollection()->map(fn (Circular $c) => [
            'id' => $c->id,
            'title' => $c->title,
            'from' => $c->orgUnit->name,
            'level' => $c->orgUnit->type,
            'vibhag' => $c->vibhag?->name,
            'published_at' => $c->published_at->toIso8601String(),
            'has_attachment' => (bool) $c->attachment_path,
            'is_read' => $read->has($c->id),
        ]), meta: [
            'page' => $page->currentPage(),
            'last_page' => $page->lastPage(),
            'unread' => Circular::for($user)->whereNotIn('id', $read->keys())->count(),
        ]);
    }

    /** Opening a circular records that it was read. */
    public function show(Request $request, int $id)
    {
        $user = $request->user();
        $c = Circular::for($user)->with('orgUnit', 'vibhag', 'issuer.profile')->findOrFail($id);

        CircularRead::firstOrCreate(['circular_id' => $c->id, 'user_id' => $user->id], ['read_at' => now()]);

        return $this->ok([
            'id' => $c->id,
            'title' => $c->title,
            'body' => $c->body,
            'from' => $c->orgUnit->name,
            'vibhag' => $c->vibhag?->name,
            'issued_by' => $c->issuer?->profile?->full_name,
            'published_at' => $c->published_at->toIso8601String(),
            'attachment_url' => $c->attachment_path
                ? URL::temporarySignedRoute('media.circular', now()->addMinutes(30), ['circular' => $c->id])
                : null,
        ]);
    }
}
