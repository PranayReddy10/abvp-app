<?php

namespace App\Support;

class Mobile
{
    /** Normalise an Indian mobile number to +91XXXXXXXXXX, or null when invalid. */
    public static function normalize(?string $input): ?string
    {
        $digits = preg_replace('/\D+/', '', (string) $input);

        if (strlen($digits) === 12 && str_starts_with($digits, '91')) {
            $digits = substr($digits, 2);
        } elseif (strlen($digits) === 11 && str_starts_with($digits, '0')) {
            $digits = substr($digits, 1);
        }

        return preg_match('/^[6-9]\d{9}$/', $digits) ? '+91'.$digits : null;
    }

    /** +91 98xxx xx345 */
    public static function mask(string $mobile): string
    {
        $d = substr($mobile, -10);

        return '+91 '.substr($d, 0, 2).'xxx xx'.substr($d, -3);
    }
}
