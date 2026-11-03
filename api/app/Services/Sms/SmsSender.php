<?php

namespace App\Services\Sms;

interface SmsSender
{
    public function sendOtp(string $mobile, string $code): void;
}
