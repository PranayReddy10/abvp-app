<?php

namespace App\Services\Sms;

use App\Services\SignInSettings;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/** Sends OTPs through MSG91's Flow API using a DLT-approved template. Key and template come from Settings → Sign-in (or .env). */
class Msg91SmsSender implements SmsSender
{
    public function __construct(private ?string $key = null, private ?string $template = null) {}

    public function sendOtp(string $mobile, string $code): void
    {
        $saved = SignInSettings::msg91();
        $key = $this->key ?? $saved['auth_key'];
        $template = $this->template ?? $saved['template_id'];

        if (! $key || ! $template) {
            throw new RuntimeException('MSG91 is not configured.');
        }

        $response = Http::withHeaders(['authkey' => $key])
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

        if ($response->json('type') === 'error') {
            throw new RuntimeException((string) $response->json('message', 'MSG91 refused the message.'));
        }
    }
}
