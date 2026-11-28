<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Setting;
use App\Services\Audit;
use Illuminate\Http\Request;

/** Settings → Website: Google Analytics ID and search-engine verification codes. Super admins only. */
class SiteSettingsController extends Controller
{
    private const KEYS = ['ga_id' => 'analytics.ga_id', 'google_verification' => 'seo.google_verification', 'bing_verification' => 'seo.bing_verification'];

    public function show()
    {
        $this->authorizeIn('settings.manage');
        $s = Setting::allValues();

        return $this->ok(collect(self::KEYS)->map(fn ($k) => $s[$k] ?? null)->all());
    }

    public function update(Request $request)
    {
        $this->authorizeIn('settings.manage');
        $data = $request->validate([
            'ga_id' => ['nullable', 'string', 'regex:/^G-[A-Z0-9]{4,20}$/'],
            // People often paste the whole <meta> tag: keep just the code.
            'google_verification' => ['nullable', 'string', 'max:300'],
            'bing_verification' => ['nullable', 'string', 'max:300'],
        ], ['ga_id.regex' => 'The Measurement ID looks like G-ABC123XYZ (from Google Analytics → Admin → Data streams).']);

        $clean = fn (?string $v) => $v === null || trim($v) === '' ? null
            : (preg_match('/content=["\']([^"\']+)["\']/', $v, $m) ? $m[1] : trim($v));
        $values = [];
        foreach (self::KEYS as $field => $key) {
            $values[$key] = $field === 'ga_id' ? ($data[$field] ?? null ?: null) : $clean($data[$field] ?? null);
        }
        $before = collect(self::KEYS)->map(fn ($k) => Setting::value($k))->all();
        Setting::putMany($values, $request->user()->id);
        Audit::record('settings.website', null, $before, $values);

        return $this->show();
    }
}
