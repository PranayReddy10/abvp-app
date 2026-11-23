<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\MeResource;
use App\Models\User;
use App\Services\GoogleIdToken;
use App\Services\OtpService;
use App\Services\SignInSettings;
use App\Support\ApiException;
use App\Services\Audit;
use App\Support\Mobile;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function __construct(private OtpService $otp) {}

    /** Which sign-in methods are switched on, so the apps show only those. Public. */
    public function options()
    {
        return $this->ok([
            'otp' => SignInSettings::otpEnabled(),
            'password' => true,
            'google' => SignInSettings::googleEnabled(),
        ]);
    }

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
     * Sign up from the website or app: basic details plus the SMS code. Works for anyone –
     * conference guests included. Becoming a member is a separate application.
     */
    public function register(Request $request)
    {
        $otpOn = SignInSettings::otpEnabled();
        $data = $request->validate([
            'mobile' => ['required', 'string', 'max:20'],
            // With codes switched off (Settings → Sign-in) the account is protected by a password instead.
            'code' => [$otpOn ? 'required' : 'nullable', 'digits:'.config('abvp.otp.length')],
            'password' => [$otpOn ? 'nullable' : 'required', 'string', 'min:8', 'max:200', 'confirmed'],
            'name' => ['required', 'string', 'min:2', 'max:100'],
            'email' => ['nullable', 'email', 'max:190'],
            'gender' => ['nullable', 'in:male,female,other'],
            'prant' => ['nullable', 'string', 'max:80'],
            'institution' => ['nullable', 'string', 'max:150'],
            'occupation' => ['nullable', 'string', 'max:80'],
            'device_name' => ['nullable', 'string', 'max:60'],
            'google_link_token' => ['nullable', 'string', 'max:2000'],
        ]);
        $mobile = $this->mobile($request);
        $google = $request->filled('google_link_token') ? $this->readLinkToken($request->string('google_link_token')) : null;

        if ($otpOn) {
            $this->otp->verify($mobile, $request->string('code'));
            $user = User::firstOrCreate(['mobile' => $mobile]);
        } else {
            // Without a code nobody has proved they own this number, so never touch an existing account.
            if (User::where('mobile', $mobile)->exists()) {
                throw new ApiException('ACCOUNT_EXISTS', 'This mobile number already has an account. Sign in with your password.', 409);
            }
            $user = User::create(['mobile' => $mobile]);
        }
        $isNew = $user->wasRecentlyCreated;
        if (! empty($data['password']) && ($isNew || $user->password === null)) {
            $user->forceFill(['password' => $data['password'], 'password_set_at' => now()]);
        }
        if ($user->status !== 'active') {
            throw new ApiException('ACCOUNT_SUSPENDED', 'This account is suspended. Contact your district office.', 403);
        }
        // Someone who already had an account keeps their details; only empty fields are filled.
        foreach (['name', 'email', 'gender', 'prant', 'institution', 'occupation'] as $field) {
            if (! empty($data[$field]) && ($isNew || empty($user->{$field}))) {
                $user->{$field} = $data[$field];
            }
        }
        if ($google) {
            if (User::where('google_id', $google['sub'])->whereKeyNot($user->id)->exists()) {
                throw new ApiException('GOOGLE_ALREADY_LINKED', 'This Google account is already linked to another mobile number.', 409);
            }
            $user->forceFill(['google_id' => $google['sub'], 'google_email' => $google['email']]);
        }

        $response = $this->issue($request, $user, $isNew, ['google_linked' => (bool) $google], verified: $otpOn);
        if ($isNew) {
            Audit::record('auth.signed_up', $user, after: ['name' => $user->name, 'prant' => $user->prant, 'with' => $otpOn ? 'sms code' : 'password']);
        }

        return $response;
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

    private function issue(Request $request, User $user, bool $isNew, array $extra = [], bool $verified = true)
    {
        $user->forceFill([
            'mobile_verified_at' => $user->mobile_verified_at ?? ($verified ? now() : null),
            'last_login_at' => now(),
        ])->save();
        app(\App\Services\AccountIds::class)->ensure($user);
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

    /** Mobile (or email) and password. Only accounts that have set a password; mainly admins in the admin panel. */
    public function passwordLogin(Request $request)
    {
        $request->validate([
            'login' => ['required', 'string', 'max:120'],
            'password' => ['required', 'string', 'max:200'],
            'device_name' => ['nullable', 'string', 'max:60'],
        ]);
        $login = trim((string) $request->input('login'));
        $mobile = Mobile::normalize($login);
        $user = $mobile
            ? User::where('mobile', $mobile)->first()
            : User::whereNotNull('password')->where('email', strtolower($login))->first();

        if (! $user || $user->password === null || ! Hash::check($request->string('password'), $user->password)) {
            throw new ApiException('WRONG_PASSWORD', 'Mobile number or password is wrong. You can also sign in with a code on your mobile.', 422);
        }
        if ($user->status !== 'active') {
            throw new ApiException('ACCOUNT_SUSPENDED', 'This account is suspended. Contact your district office.', 403);
        }
        Audit::record('auth.password_login', $user);

        return $this->issue($request, $user, false, verified: false);
    }

    /** Set or change your password. Changing needs the current one; other signed-in devices are signed out. */
    public function setPassword(Request $request)
    {
        $user = $request->user();
        $request->validate([
            'current_password' => [$user->password ? 'required' : 'nullable', 'string', 'max:200'],
            'password' => ['required', 'string', 'min:8', 'max:200', 'confirmed'],
        ]);
        if ($user->password && ! Hash::check($request->string('current_password'), $user->password)) {
            throw ValidationException::withMessages(['current_password' => 'Your current password is wrong.']);
        }
        $user->forceFill(['password' => $request->string('password')->toString(), 'password_set_at' => now()])->save();
        $current = $user->currentAccessToken();
        $user->tokens()->when($current?->id, fn ($q, $id) => $q->whereKeyNot($id))->delete();
        Audit::record('auth.password_set', $user);

        return $this->ok(['has_password' => true]);
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
