<?php

namespace App\Services;

use App\Support\ApiException;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Checks a Google ID token with Google's tokeninfo endpoint (one HTTPS call, works on shared
 * hosting) and that it was issued to one of our OAuth client IDs.
 */
class GoogleIdToken
{
    /** @return array{sub: string, email: string, name: ?string, picture: ?string} */
    public function verify(string $idToken): array
    {
        $clients = array_filter(array_map('trim', explode(',', (string) config('services.google.client_ids'))));
        if (! $clients) {
            throw new ApiException('GOOGLE_NOT_CONFIGURED', 'Google sign-in is not set up on the server yet. Use your mobile number.', 503);
        }
        try {
            $res = Http::timeout(8)->get('https://oauth2.googleapis.com/tokeninfo', ['id_token' => $idToken]);
        } catch (Throwable) {
            throw new ApiException('GOOGLE_UNREACHABLE', 'Could not reach Google. Try again, or use your mobile number.', 503);
        }
        $t = $res->json() ?? [];
        $valid = $res->ok()
            && in_array($t['aud'] ?? null, $clients, true)
            && in_array($t['iss'] ?? null, ['accounts.google.com', 'https://accounts.google.com'], true)
            && (int) ($t['exp'] ?? 0) > time()
            && in_array($t['email_verified'] ?? null, [true, 'true'], true)
            && ! empty($t['sub']);
        if (! $valid) {
            throw new ApiException('GOOGLE_TOKEN_INVALID', 'Google sign-in did not go through. Try again.', 401);
        }

        return ['sub' => (string) $t['sub'], 'email' => (string) ($t['email'] ?? ''), 'name' => $t['name'] ?? null, 'picture' => $t['picture'] ?? null];
    }
}
