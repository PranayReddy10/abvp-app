<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Setting;
use App\Services\Audit;
use App\Services\SignInSettings;
use App\Services\Sms\Msg91SmsSender;
use App\Support\ApiException;
use App\Support\Mobile;
use Illuminate\Http\Request;

/** Settings → Sign-in: mobile-code sign-in on/off and how codes are sent. Super admins only. */
class SignInSettingsController extends Controller
{
    public function show()
    {
        $this->authorizeIn('settings.manage');
        $msg = SignInSettings::msg91();
        $key = $msg['auth_key'];

        return $this->ok([
            'otp_enabled' => SignInSettings::otpEnabled(),
            'sms_driver' => SignInSettings::smsDriver(),
            'msg91' => [
                'template_id' => $msg['template_id'],
                'key_hint' => $key ? substr($key, 0, 4).'…'.substr($key, -4) : null,
                'has_key' => (bool) $key,
            ],
            'google_enabled' => SignInSettings::googleEnabled(),
            'admins_with_password' => \App\Models\User::whereNotNull('password')
                ->whereHas('roleAssignments')->count(),
        ]);
    }

    public function update(Request $request)
    {
        $this->authorizeIn('settings.manage');
        $data = $request->validate([
            'otp_enabled' => ['required', 'boolean'],
            'sms_driver' => ['required', 'in:'.implode(',', SignInSettings::DRIVERS)],
            'msg91_key' => ['nullable', 'string', 'max:120'],
            'msg91_template' => ['nullable', 'string', 'max:60'],
        ]);
        $user = $request->user();

        // Turning codes off must not lock out the person doing it.
        if (! $data['otp_enabled'] && $user->password === null) {
            throw new ApiException('PASSWORD_FIRST', 'Set your own password under My account before switching off sign-in with a code, or you could lock yourself out.', 422);
        }
        if ($data['sms_driver'] === 'msg91') {
            $key = ($data['msg91_key'] ?? null) ?: SignInSettings::msg91()['auth_key'];
            $template = ($data['msg91_template'] ?? null) ?: SignInSettings::msg91()['template_id'];
            if (! $key || ! $template) {
                throw new ApiException('MSG91_INCOMPLETE', 'Enter the MSG91 auth key and the DLT-approved OTP template ID.', 422);
            }
        }

        $before = ['otp_enabled' => SignInSettings::otpEnabled(), 'sms_driver' => SignInSettings::smsDriver()];
        $values = [
            'auth.otp_enabled' => $data['otp_enabled'] ? '1' : '0',
            'sms.driver' => $data['sms_driver'],
        ];
        if (! empty($data['msg91_key'])) {
            $values['sms.msg91_key_secret'] = trim($data['msg91_key']);
        }
        if (! empty($data['msg91_template'])) {
            $values['sms.msg91_template'] = trim($data['msg91_template']);
        }
        Setting::putMany($values, $user->id);
        Audit::record('settings.sign_in', null, $before, ['otp_enabled' => (bool) $data['otp_enabled'], 'sms_driver' => $data['sms_driver']]);

        return $this->show();
    }

    /** Sends a real test code through MSG91 (with the saved or just-typed key) to check delivery. */
    public function testSms(Request $request)
    {
        $this->authorizeIn('settings.manage');
        $request->validate(['mobile' => ['required', 'string', 'max:20'], 'msg91_key' => ['nullable', 'string', 'max:120'], 'msg91_template' => ['nullable', 'string', 'max:60']]);
        $mobile = Mobile::normalize($request->input('mobile')) ?? throw new ApiException('INVALID_MOBILE', 'Enter a valid 10-digit Indian mobile number.');
        $saved = SignInSettings::msg91();
        $key = $request->input('msg91_key') ?: $saved['auth_key'];
        $template = $request->input('msg91_template') ?: $saved['template_id'];
        if (! $key || ! $template) {
            throw new ApiException('MSG91_INCOMPLETE', 'Enter the MSG91 auth key and the DLT-approved OTP template ID.', 422);
        }
        try {
            (new Msg91SmsSender($key, $template))->sendOtp($mobile, (string) random_int(100000, 999999));
        } catch (\Throwable $e) {
            throw new ApiException('SMS_TEST_FAILED', 'MSG91 did not accept the message: '.str($e->getMessage())->limit(160), 422);
        }

        return $this->ok(['message' => 'Test SMS sent to '.Mobile::mask($mobile).'. If it does not arrive in a minute, check the template and DLT approval in MSG91.']);
    }
}
