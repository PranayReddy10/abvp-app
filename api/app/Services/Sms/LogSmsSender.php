<?php

namespace App\Services\Sms;

use Illuminate\Support\Facades\Log;

/** Development only: writes the code to storage/logs instead of sending SMS. */
class LogSmsSender implements SmsSender
{
    public function sendOtp(string $mobile, string $code): void
    {
        Log::info("ABVP Connect OTP for {$mobile}: {$code}");
    }
}
