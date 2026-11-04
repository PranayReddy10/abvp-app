<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Crypt;

/** Key/value settings managed from the admin panel. Secret values are encrypted with APP_KEY. */
class Setting extends Model
{
    public const CACHE_KEY = 'abvp.settings';

    protected $primaryKey = 'key';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = ['key', 'value', 'updated_by'];

    /** @return array<string, string|null> all settings, decrypted, cached until the next change */
    public static function allValues(): array
    {
        return Cache::rememberForever(self::CACHE_KEY, fn () => static::query()->pluck('value', 'key')
            ->map(fn ($v, $k) => $v !== null && str_ends_with($k, '_secret') ? rescue(fn () => Crypt::decryptString($v), null, false) : $v)
            ->all());
    }

    public static function value(string $key, ?string $default = null): ?string
    {
        return static::allValues()[$key] ?? $default;
    }

    /** @param array<string, string|null> $values */
    public static function putMany(array $values, ?int $by = null): void
    {
        foreach ($values as $key => $value) {
            if ($value !== null && str_ends_with($key, '_secret')) {
                $value = Crypt::encryptString($value);
            }
            static::updateOrCreate(['key' => $key], ['value' => $value, 'updated_by' => $by]);
        }
        Cache::forget(self::CACHE_KEY);
    }
}
