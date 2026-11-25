<?php

namespace App\Services;

use App\Models\Setting;

/**
 * How people sign in, as set by a super admin in the admin panel (Settings → Sign-in).
 * Values saved there win over .env (SMS_DRIVER, MSG91_*), which stays the fallback.
 */
class SignInSettings
{
    public const DRIVERS = ['msg91', 'log'];

    public static function otpEnabled(): bool
    {
        return rescue(fn () => Setting::value('auth.otp_enabled', '1') !== '0', true, false);
    }

    public static function smsDriver(): string
    {
        $saved = rescue(fn () => Setting::value('sms.driver'), null, false);

        return in_array($saved, self::DRIVERS, true) ? $saved : (config('abvp.sms.driver') === 'msg91' ? 'msg91' : 'log');
    }

    /** @return array{auth_key: ?string, template_id: ?string} */
    public static function msg91(): array
    {
        $s = rescue(fn () => Setting::allValues(), [], false);

        return [
            'auth_key' => ($s['sms.msg91_key_secret'] ?? null) ?: config('abvp.sms.msg91.auth_key'),
            'template_id' => ($s['sms.msg91_template'] ?? null) ?: config('abvp.sms.msg91.otp_template_id'),
        ];
    }

    /** Settings → Membership: when off (the default), an application is approved as soon as it is sent. */
    public static function membershipNeedsApproval(): bool
    {
        return rescue(fn () => Setting::value('membership.needs_approval', '0') === '1', false, false);
    }

    public static function googleEnabled(): bool
    {
        return trim((string) config('services.google.client_ids')) !== '';
    }
}
