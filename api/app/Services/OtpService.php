<?php

namespace App\Services;

use App\Models\OtpCode;
use App\Services\Sms\SmsSender;
use App\Support\ApiException;
use Illuminate\Support\Facades\Hash;

class OtpService
{
    public function __construct(private SmsSender $sms) {}

    public function send(string $mobile): void
    {
        $code = $this->generate();

        OtpCode::where('mobile', $mobile)->whereNull('consumed_at')->update(['consumed_at' => now()]);

        OtpCode::create([
            'mobile' => $mobile,
            'code_hash' => Hash::make($code),
            'expires_at' => now()->addMinutes(config('abvp.otp.ttl_minutes')),
        ]);

        $this->sms->sendOtp($mobile, $code);
    }

    /** Consumes the code on success; throws with a clear reason otherwise. */
    public function verify(string $mobile, string $code): void
    {
        $otp = OtpCode::where('mobile', $mobile)
            ->whereNull('consumed_at')
            ->latest('id')
            ->first();

        if (! $otp || $otp->expires_at->isPast()) {
            throw new ApiException('OTP_EXPIRED', 'This code has expired. Request a new one.');
        }

        if ($otp->attempts >= config('abvp.otp.max_attempts')) {
            throw new ApiException('OTP_TOO_MANY_ATTEMPTS', 'Too many wrong attempts. Request a new code.', 429);
        }

        if (! Hash::check($code, $otp->code_hash)) {
            $otp->increment('attempts');
            throw new ApiException('OTP_INVALID', 'That code is not correct. Check the SMS and try again.');
        }

        $otp->update(['consumed_at' => now()]);
    }

    private function generate(): string
    {
        $fixed = config('abvp.otp.fixed_code');

        if ($fixed && app()->environment(['local', 'testing'])) {
            return (string) $fixed;
        }

        $length = config('abvp.otp.length');

        return str_pad((string) random_int(0, 10 ** $length - 1), $length, '0', STR_PAD_LEFT);
    }
}
