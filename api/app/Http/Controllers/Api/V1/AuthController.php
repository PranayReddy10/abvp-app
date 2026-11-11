<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\MeResource;
use App\Models\User;
use App\Services\GoogleIdToken;
use App\Services\OtpService;
use App\Support\ApiException;
use App\Support\Mobile;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;

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
            'google_link_token' => ['nullable', 'string', 'max:2000'],
        ]);
        $mobile = $this->mobile($request);
        $google = $request->filled('google_link_token') ? $this->readLinkToken($request->string('google_link_token')) : null;

        $this->otp->verify($mobile, $request->string('code'));

        $user = User::firstOrCreate(['mobile' => $mobile]);
        $isNew = $user->wasRecentlyCreated;

        if ($user->status !== 'active') {
            throw new ApiException('ACCOUNT_SUSPENDED', 'This account is suspended. Contact your district office.', 403);
        }

        // Signed in with Google before and verified this mobile now: remember the Google account.
        if ($google) {
            if (User::where('google_id', $google['sub'])->whereKeyNot($user->id)->exists()) {
                throw new ApiException('GOOGLE_ALREADY_LINKED', 'This Google account is already linked to another mobile number.', 409);
            }
            $user->forceFill(['google_id' => $google['sub'], 'google_email' => $google['email']]);
        }

        return $this->issue($request, $user, $isNew, ['google_linked' => (bool) $google]);
    }

    /**
     * Sign in with Google. A Google account linked to a member signs in straight away. The first
     * time, the member verifies their mobile once (identity in ABVP Connect is the mobile number);
     * we return a short-lived link token that verify-otp uses to link the two.
     */
    public function google(Request $request, GoogleIdToken $google)
    {
        $request->validate(['id_token' => ['required', 'string', 'max:4096'], 'device_name' => ['nullable', 'string', 'max:60']]);
        $g = $google->verify($request->string('id_token'));

        $user = User::where('google_id', $g['sub'])->first();
        if ($user) {
            if ($user->status !== 'active') {
                throw new ApiException('ACCOUNT_SUSPENDED', 'This account is suspended. Contact your district office.', 403);
            }

            return $this->issue($request, $user, false, ['linked' => true]);
        }

        return $this->ok([
            'linked' => false,
            'email' => $g['email'],
            'name' => $g['name'],
            'link_token' => Crypt::encryptString(json_encode(['sub' => $g['sub'], 'email' => $g['email'], 'exp' => now()->addMinutes(15)->timestamp])),
            'message' => 'Verify your mobile number once to link this Google account.',
        ]);
    }

    private function issue(Request $request, User $user, bool $isNew, array $extra = [])
    {
        $user->forceFill(['mobile_verified_at' => $user->mobile_verified_at ?? now(), 'last_login_at' => now()])->save();
        $token = $user->createToken($request->input('device_name', 'app'), ['*'], now()->addDays(60));

        return $this->ok([
            'token' => $token->plainTextToken,
            'is_new_user' => $isNew,
            'user' => new MeResource($user->load('profile.orgUnit', 'vibhags', 'responsibilities', 'application.events', 'application.orgUnit')),
        ] + $extra);
    }

    /** @return array{sub: string, email: string} */
    private function readLinkToken(string $token): array
    {
        try {
            $data = json_decode(Crypt::decryptString($token), true, 512, JSON_THROW_ON_ERROR);
        } catch (\Throwable) {
            throw new ApiException('GOOGLE_LINK_INVALID', 'The Google link has expired. Sign in with Google again.', 422);
        }
        if (($data['exp'] ?? 0) < time()) {
            throw new ApiException('GOOGLE_LINK_INVALID', 'The Google link has expired. Sign in with Google again.', 422);
        }

        return ['sub' => (string) $data['sub'], 'email' => (string) ($data['email'] ?? '')];
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
