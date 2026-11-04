<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ActivityReport;
use App\Models\Circular;
use App\Models\MemberProfile;
use Illuminate\Support\Facades\Storage;

/** Streams private photos through short-lived signed URLs. */
class MediaController extends Controller
{
    public function photo(MemberProfile $profile)
    {
        abort_unless($profile->photo_path, 404);

        $disk = Storage::disk(config('abvp.media_disk'));
        abort_unless($disk->exists($profile->photo_path), 404);

        return $disk->response($profile->photo_path, null, ['Cache-Control' => 'private, max-age=1800']);
    }

    public function circular(Circular $circular)
    {
        return $this->stream($circular->attachment_path);
    }

    public function post(\App\Models\Post $post, int $index)
    {
        return $this->stream($post->photos[$index] ?? null);
    }

    public function eventCover(\App\Models\Event $event)
    {
        return $this->stream($event->cover_path);
    }

    public function report(ActivityReport $report, int $index)
    {
        return $this->stream($report->photos[$index] ?? null);
    }

    private function stream(?string $path)
    {
        $disk = Storage::disk(config('abvp.media_disk'));
        abort_unless($path && $disk->exists($path), 404);

        return $disk->response($path, null, ['Cache-Control' => 'private, max-age=1800']);
    }
}
