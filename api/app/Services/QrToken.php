<?php

namespace App\Services;

use App\Models\MemberProfile;

/**
 * Opaque, signed QR payload. Carries no personal data: only the profile id and
 * the issue date. Valid for the day it was issued, so screenshots go stale.
 */
class QrToken
{
    public function issue(MemberProfile $profile): string
    {
        $payload = $profile->id.'.'.now()->format('Ymd');

        return 'AC1.'.$this->b64($payload).'.'.$this->sign($payload);
    }

    public function resolve(string $token): ?MemberProfile
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3 || $parts[0] !== 'AC1') {
            return null;
        }

        $payload = base64_decode(strtr($parts[1], '-_', '+/'), true);
        if (! $payload || ! hash_equals($this->sign($payload), $parts[2])) {
            return null;
        }

        [$id, $date] = explode('.', $payload) + [null, null];
        if ($date !== now()->format('Ymd')) {
            return null;
        }

        return MemberProfile::find($id);
    }

    private function sign(string $payload): string
    {
        $secret = config('abvp.qr_secret') ?: config('app.key');

        return substr($this->b64(hash_hmac('sha256', $payload, $secret, true)), 0, 22);
    }

    private function b64(string $raw): string
    {
        return rtrim(strtr(base64_encode($raw), '+/', '-_'), '=');
    }
}
