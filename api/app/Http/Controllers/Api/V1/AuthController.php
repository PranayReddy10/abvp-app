<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\MeResource;
use App\Models\User;
use App\Services\OtpService;
use App\Support\ApiException;
use App\Support\Mobile;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    public function __construct(private OtpService $otp) {}

    public function sendOtp(Request $request)
    {
        $request->validate(['mobile' => ['required', 'string', 'max:20']]);
        $mobile = $this->mobile($request);

        $this->otp->send($mobile);

        return $this->ok([
            'mobile' => Mobile::mask($mobile),
            'expires_in' => config('abvp.otp.ttl_minutes') * 60,
            'resend_after' => 30,
        ]);
    }

    public function verifyOtp(Request $request)
    {
        $request->validate([
            'mobile' => ['required', 'string', 'max:20'],
            'code' => ['required', 'digits:'.config('abvp.otp.length')],
            'device_name' => ['nullable', 'string', 'max:60'],
        ]);
        $mobile = $this->mobile($request);

        $this->otp->verify($mobile, $request->string('code'));

        $user = User::firstOrCreate(['mobile' => $mobile]);
        $isNew = $user->wasRecentlyCreated;

        if ($user->status !== 'active') {
            throw new ApiException('ACCOUNT_SUSPENDED', 'This account is suspended. Contact your district office.', 403);
        }

        $user->forceFill(['mobile_verified_at' => $user->mobile_verified_at ?? now(), 'last_login_at' => now()])->save();

        $token = $user->createToken($request->input('device_name', 'app'), ['*'], now()->addDays(60));

        return $this->ok([
            'token' => $token->plainTextToken,
            'is_new_user' => $isNew,
            'user' => new MeResource($user->load('profile.orgUnit', 'vibhags', 'responsibilities', 'application.events', 'application.orgUnit')),
        ]);
    }

    public function me(Request $request)
    {
        return $this->ok(new MeResource($request->user()->load('profile.orgUnit', 'vibhags', 'responsibilities', 'application.events', 'application.orgUnit')));
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();

        return $this->ok(['signed_out' => true]);
    }

    private function mobile(Request $request): string
    {
        return Mobile::normalize($request->input('mobile'))
            ?? throw new ApiException('INVALID_MOBILE', 'Enter a valid 10-digit Indian mobile number.');
    }
}
