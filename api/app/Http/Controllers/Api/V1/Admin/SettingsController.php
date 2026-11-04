<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Setting;
use App\Services\Audit;
use App\Services\MediaStorage;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/** Photo storage: the server's own disk or DigitalOcean Spaces. Super admins only. */
class SettingsController extends Controller
{
    public function storage()
    {
        $this->authorizeIn('settings.manage');
        $s = Setting::allValues();
        $key = $s['storage.spaces_key'] ?? null;

        return $this->ok([
            'driver' => config('abvp.media_disk') === 'spaces' ? 'spaces' : 'local',
            'saved_driver' => $s['storage.driver'] ?? null,
            'spaces' => [
                'region' => $s['storage.spaces_region'] ?? 'blr1',
                'bucket' => $s['storage.spaces_bucket'] ?? null,
                'key_hint' => $key ? substr($key, 0, 4).'…'.substr($key, -4) : null,
                'has_secret' => ! empty($s['storage.spaces_secret']),
            ],
            'regions' => collect(MediaStorage::REGIONS)->map(fn ($name, $code) => ['code' => $code, 'name' => $name])->values(),
            's3_driver_installed' => class_exists(\League\Flysystem\AwsS3V3\AwsS3V3Adapter::class),
            'local_files' => count(MediaStorage::localFiles()),
        ]);
    }

    public function test(Request $request, MediaStorage $storage)
    {
        $this->authorizeIn('settings.manage');
        [$region, $bucket, $key, $secret] = $this->spacesInput($request);
        $error = $storage->test($region, $bucket, $key, $secret);
        if ($error) {
            throw new ApiException('STORAGE_TEST_FAILED', $error, 422);
        }

        return $this->ok(['ok' => true, 'message' => "Connected to {$bucket} in ".MediaStorage::REGIONS[$region].'. Photos can be saved there.']);
    }

    public function update(Request $request, MediaStorage $storage)
    {
        $this->authorizeIn('settings.manage');
        $request->validate(['driver' => ['required', 'in:local,spaces']]);
        $before = ['driver' => config('abvp.media_disk') === 'spaces' ? 'spaces' : 'local', 'bucket' => Setting::value('storage.spaces_bucket')];

        if ($request->input('driver') === 'local') {
            Setting::putMany(['storage.driver' => 'local'], $request->user()->id);
        } else {
            [$region, $bucket, $key, $secret] = $this->spacesInput($request);
            // Never switch to a Space that does not work: new uploads would fail.
            if ($error = $storage->test($region, $bucket, $key, $secret)) {
                throw new ApiException('STORAGE_TEST_FAILED', $error, 422);
            }
            Setting::putMany([
                'storage.driver' => 'spaces',
                'storage.spaces_region' => $region,
                'storage.spaces_bucket' => $bucket,
                'storage.spaces_key' => $key,
                'storage.spaces_secret' => $secret,
            ], $request->user()->id);
        }
        MediaStorage::apply();
        Audit::record('settings.storage', null, $before, ['driver' => $request->input('driver'), 'bucket' => Setting::value('storage.spaces_bucket')]);

        return $this->storage();
    }

    /** Copy files saved on the server into the Space, a batch at a time so shared hosting never times out. */
    public function copyToSpaces(Request $request)
    {
        $this->authorizeIn('settings.manage');
        $data = $request->validate(['offset' => ['nullable', 'integer', 'min:0']]);
        if (config('abvp.media_disk') !== 'spaces') {
            throw new ApiException('NOT_ON_SPACES', 'Switch photo storage to DigitalOcean Spaces first.', 409);
        }
        $files = MediaStorage::localFiles();
        $offset = $data['offset'] ?? 0;
        $local = Storage::disk('local');
        $spaces = Storage::disk('spaces');
        $copied = $skipped = 0;
        $failed = [];
        foreach (array_slice($files, $offset, 25) as $path) {
            try {
                if ($spaces->exists($path)) {
                    $skipped++;

                    continue;
                }
                $spaces->writeStream($path, $local->readStream($path), ['visibility' => 'private']);
                $copied++;
            } catch (\Throwable) {
                $failed[] = $path;
            }
        }
        $next = min($offset + 25, count($files));
        if ($next >= count($files)) {
            Audit::record('settings.storage_copied', null, null, ['files' => count($files)]);
        }

        return $this->ok(['total' => count($files), 'done' => $next, 'copied' => $copied, 'skipped' => $skipped, 'failed' => $failed, 'finished' => $next >= count($files)]);
    }

    /** @return array{0: string, 1: string, 2: string, 3: string} */
    private function spacesInput(Request $request): array
    {
        $data = $request->validate([
            'region' => ['required', 'in:'.implode(',', array_keys(MediaStorage::REGIONS))],
            'bucket' => ['required', 'string', 'min:3', 'max:63', 'regex:/^[a-z0-9][a-z0-9-]*[a-z0-9]$/'],
            'key' => ['nullable', 'string', 'max:128'],
            'secret' => ['nullable', 'string', 'max:128'],
        ], ['bucket.regex' => 'Space names use lowercase letters, numbers and dashes.']);
        // Blank key or secret means "keep the saved one".
        $key = $data['key'] ?: Setting::value('storage.spaces_key');
        $secret = $data['secret'] ?: Setting::value('storage.spaces_secret');
        if (! $key || ! $secret) {
            throw \Illuminate\Validation\ValidationException::withMessages(['secret' => 'Enter the Spaces access key and secret.']);
        }

        return [$data['region'], $data['bucket'], $key, $secret];
    }
}
