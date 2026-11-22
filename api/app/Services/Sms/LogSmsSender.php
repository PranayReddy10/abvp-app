<?php

namespace App\Services\Sms;

use Illuminate\Support\Facades\Log;

/** Testing only: writes the code to storage/logs/laravel.log instead of sending an SMS. */
class LogSmsSender implements SmsSender
{
    public function sendOtp(string $mobile, string $code): void
    {
        Log::info("ABVP Connect OTP for {$mobile}: {$code}");
    }
}
