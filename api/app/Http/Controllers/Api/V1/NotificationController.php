<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $items = AppNotification::where('user_id', $request->user()->id)->latest('id')->limit(50)->get();

        return $this->ok($items->map(fn (AppNotification $n) => [
            'id' => $n->id,
            'type' => $n->type,
            'title' => $n->title,
            'body' => $n->body,
            'data' => $n->data,
            'is_read' => $n->read_at !== null,
            'at' => $n->created_at?->toIso8601String(),
        ]), meta: ['unread' => AppNotification::where('user_id', $request->user()->id)->whereNull('read_at')->count()]);
    }

    public function readAll(Request $request)
    {
        AppNotification::where('user_id', $request->user()->id)->whereNull('read_at')->update(['read_at' => now()]);

        return $this->ok(['unread' => 0]);
    }
}
