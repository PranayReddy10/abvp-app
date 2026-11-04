<?php

namespace App\Providers;

use App\Services\AccessControl;
use App\Services\Sms\LogSmsSender;
use App\Services\Sms\Msg91SmsSender;
use App\Services\Sms\SmsSender;
use App\Support\Mobile;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->scoped(AccessControl::class);

        $this->app->bind(SmsSender::class, fn () => match (config('abvp.sms.driver')) {
            'msg91' => new Msg91SmsSender,
            default => new LogSmsSender,
        });
    }

    public function boot(): void
    {
        // Photo storage chosen in the admin panel (server disk or DigitalOcean Spaces).
        \App\Services\MediaStorage::apply();

        // OTP: 3 per mobile per 10 minutes, 30 per IP per hour.
        RateLimiter::for('otp', function (Request $request) {
            $mobile = Mobile::normalize($request->input('mobile')) ?? 'invalid';

            return [
                Limit::perMinutes(10, $request->is('*/send-otp') ? 3 : 10)->by('otp:'.$mobile.':'.$request->path()),
                Limit::perHour(30)->by('otp-ip:'.$request->ip()),
            ];
        });

        // Posting and replying: 10 every 10 minutes per member.
        RateLimiter::for('posts', fn (Request $request) => Limit::perMinutes(10, 10)->by('posts:'.$request->user()?->id));

        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(120)->by($request->user()?->id ?: $request->ip()));
    }
}
