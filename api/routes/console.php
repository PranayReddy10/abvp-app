<?php

use App\Models\OtpCode;
use Illuminate\Support\Facades\Schedule;

// Hostinger cron runs `php artisan schedule:run` every minute.
Schedule::call(fn () => OtpCode::where('created_at', '<', now()->subDay())->delete())->daily();
Schedule::command('sanctum:prune-expired --hours=24')->daily();
