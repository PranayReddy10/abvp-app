<?php

namespace App\Console\Commands;

use App\Models\LocationPoint;
use App\Models\LocationSession;
use Illuminate\Console\Command;

/** Live location is kept only briefly: points are deleted a day after sharing ends. */
class PruneLocations extends Command
{
    protected $signature = 'abvp:prune-locations';

    protected $description = 'Delete location points from sharing sessions that ended more than a day ago';

    public function handle(): int
    {
        $ended = LocationSession::where(fn ($q) => $q->where('stopped_at', '<', now()->subDay())->orWhere('expires_at', '<', now()->subDay()))->pluck('id');
        $n = LocationPoint::whereIn('location_session_id', $ended)->delete();
        $this->info("Deleted $n location points.");

        return self::SUCCESS;
    }
}
