<?php

namespace App\Services\Sms;

use Illuminate\Support\Facades\Http;
use RuntimeException;

/** Sends OTPs through MSG91's Flow API using a DLT-approved template. */
class Msg91SmsSender implements SmsSender
{
    public function sendOtp(string $mobile, string $code): void
    {
        $key = config('abvp.sms.msg91.auth_key');
        $template = config('abvp.sms.msg91.otp_template_id');

        if (! $key || ! $template) {
            throw new RuntimeException('MSG91 is not configured.');
        }

        Http::withHeaders(['authkey' => $key])
            ->timeout(10)
            ->post('https://control.msg91.com/api/v5/flow', [
                'template_id' => $template,
                'short_url' => '0',
                'recipients' => [[
                    'mobiles' => ltrim($mobile, '+'),
                    'otp' => $code,
                ]],
            ])
            ->throw();
    }
}
