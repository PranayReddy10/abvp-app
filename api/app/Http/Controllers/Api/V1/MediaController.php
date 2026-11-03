<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
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
}
