<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Support\Mobile;
use Illuminate\Console\Command;

/** Sets or resets someone's password over SSH, e.g. when an admin forgets it. */
class SetPassword extends Command
{
    protected $signature = 'abvp:set-password {mobile : 10-digit mobile number of the account}';

    protected $description = 'Set or reset the password an account uses to sign in (signs it out everywhere)';

    public function handle(): int
    {
        $user = User::where('mobile', Mobile::normalize($this->argument('mobile')) ?? '')->first();
        if (! $user) {
            $this->error('No account with this mobile number. Create an admin with: php artisan abvp:make-admin 98XXXXXXXX "Name" --password');

            return self::FAILURE;
        }
        $password = self::askNew($this);
        if ($password === null) {
            return self::FAILURE;
        }
        $user->forceFill(['password' => $password, 'password_set_at' => now()])->save();
        $user->tokens()->delete();
        $this->info("Password set for {$user->mobile}. Sign in with this mobile number and the new password.");

        return self::SUCCESS;
    }

    /** Asks twice without echoing. Returns null (after printing why) when it is too short or does not match. */
    public static function askNew(Command $cmd): ?string
    {
        $one = (string) $cmd->secret('New password (at least 8 characters)');
        if (mb_strlen($one) < 8) {
            $cmd->error('The password must be at least 8 characters.');

            return null;
        }
        if ($one !== (string) $cmd->secret('Type it again')) {
            $cmd->error('The two passwords do not match.');

            return null;
        }

        return $one;
    }
}
