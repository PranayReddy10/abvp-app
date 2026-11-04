<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

class AppNotification extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = ['user_id', 'type', 'title', 'body', 'data', 'read_at'];

    protected function casts(): array
    {
        return ['data' => 'array', 'read_at' => 'datetime'];
    }

    /** Insert the same notification for many users in small batches (shared-hosting friendly). */
    public static function sendMany(iterable $userIds, string $type, string $title, ?string $body = null, array $data = []): void
    {
        $now = now();
        collect($userIds)->unique()->chunk(500)->each(function ($chunk) use ($type, $title, $body, $data, $now) {
            DB::table('app_notifications')->insert($chunk->map(fn ($id) => [
                'user_id' => $id,
                'type' => $type,
                'title' => $title,
                'body' => $body,
                'data' => json_encode($data),
                'created_at' => $now,
            ])->values()->all());
        });
    }
}
