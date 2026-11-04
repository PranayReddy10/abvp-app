<?php

namespace App\Services;

use App\Models\Setting;
use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Throwable;

/**
 * Where photos and attachments live: on the server's own disk (Hostinger) or in
 * DigitalOcean Spaces. Chosen in the admin panel; .env MEDIA_DISK is the fallback.
 */
class MediaStorage
{
    public const REGIONS = ['blr1' => 'Bangalore', 'sgp1' => 'Singapore', 'fra1' => 'Frankfurt', 'ams3' => 'Amsterdam', 'lon1' => 'London', 'nyc3' => 'New York', 'sfo3' => 'San Francisco', 'syd1' => 'Sydney', 'tor1' => 'Toronto', 'atl1' => 'Atlanta'];

    /** Folders that hold member photos, post photos, covers, report photos and circular PDFs. */
    public const FOLDERS = ['photos', 'posts', 'events', 'reports', 'activity-reports', 'circulars'];

    /** Point the 'spaces' disk and abvp.media_disk at what the admin saved. Runs on every request. */
    public static function apply(): void
    {
        try {
            $s = Setting::allValues(); // cached; one query after each change
        } catch (Throwable) {
            return; // no database yet (fresh install, artisan before migrate)
        }
        if (($s['storage.driver'] ?? null) !== 'spaces' || empty($s['storage.spaces_bucket']) || empty($s['storage.spaces_secret'])) {
            if (($s['storage.driver'] ?? null) === 'local') {
                config(['abvp.media_disk' => 'local']);
            }

            return;
        }
        config([
            'filesystems.disks.spaces' => self::diskConfig($s['storage.spaces_region'] ?? 'blr1', $s['storage.spaces_bucket'], $s['storage.spaces_key'] ?? '', $s['storage.spaces_secret']),
            'abvp.media_disk' => 'spaces',
        ]);
        Storage::forgetDisk('spaces');
    }

    public static function diskConfig(string $region, string $bucket, string $key, string $secret): array
    {
        return [
            'driver' => 's3',
            'key' => $key,
            'secret' => $secret,
            'region' => $region,
            'bucket' => $bucket,
            'endpoint' => "https://{$region}.digitaloceanspaces.com",
            'use_path_style_endpoint' => false,
            'visibility' => 'private',
            'throw' => true,
        ];
    }

    /** Write, read back and delete a small file. Returns null when it works, or a message to show. */
    public function test(string $region, string $bucket, string $key, string $secret): ?string
    {
        if (! class_exists(\League\Flysystem\AwsS3V3\AwsS3V3Adapter::class)) {
            return 'The S3 driver is not installed on the server. Run: composer require league/flysystem-aws-s3-v3';
        }
        try {
            $disk = Storage::build(self::diskConfig($region, $bucket, $key, $secret));
            $path = '.abvp-connect-check/'.Str::random(12).'.txt';
            $disk->put($path, 'ok');
            $ok = $disk->get($path) === 'ok';
            $disk->delete($path);

            return $ok ? null : 'The Space accepted the file but returned something else when read back.';
        } catch (Throwable $e) {
            $msg = $e->getMessage();

            return match (true) {
                str_contains($msg, 'NoSuchBucket') => "No Space named \"{$bucket}\" in {$region}. Check the name and region.",
                str_contains($msg, 'InvalidAccessKeyId'), str_contains($msg, 'SignatureDoesNotMatch'), str_contains($msg, 'AccessDenied') => 'DigitalOcean refused the access key or secret. Create a new Spaces key with read and write access and try again.',
                str_contains($msg, 'Could not resolve host'), str_contains($msg, 'cURL error') => 'Could not reach DigitalOcean from the server. Check the region, or try again in a minute.',
                default => 'Could not connect to the Space: '.Str::limit($msg, 160),
            };
        }
    }

    /** The disk files are read from, falling back to the server disk for files saved before a switch. */
    public static function read(string $path): ?Filesystem
    {
        $disk = Storage::disk(config('abvp.media_disk'));
        if ($disk->exists($path)) {
            return $disk;
        }
        if (config('abvp.media_disk') !== 'local' && Storage::disk('local')->exists($path)) {
            return Storage::disk('local');
        }

        return null;
    }

    /** @return list<string> files on the server disk that belong to the app, in a stable order */
    public static function localFiles(): array
    {
        $local = Storage::disk('local');

        return collect(self::FOLDERS)->filter(fn ($f) => $local->exists($f))
            ->flatMap(fn ($f) => $local->allFiles($f))->sort()->values()->all();
    }
}
