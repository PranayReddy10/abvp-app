<?php

namespace App\Console\Commands;

use App\Models\AppNotification;
use App\Models\Meeting;
use App\Models\MeetingInvitee;
use Illuminate\Console\Command;

/** Reminds people who have not said no: a day before, and 15 minutes before. */
class SendMeetingReminders extends Command
{
    protected $signature = 'abvp:meeting-reminders';

    protected $description = 'Send day-before and starting-soon meeting reminders';

    public function handle(): int
    {
        $sent = 0;

        $windows = [
            ['reminded_day_at', now()->addHours(23), now()->addHours(25), 'Tomorrow'],
            ['reminded_soon_at', now(), now()->addMinutes(16), 'Starting soon'],
        ];

        foreach ($windows as [$column, $start, $end, $prefix]) {
            Meeting::where('status', 'scheduled')->whereNull($column)->whereBetween('starts_at', [$start, $end])
                ->each(function (Meeting $m) use ($column, $prefix, &$sent) {
                    $ids = MeetingInvitee::where('meeting_id', $m->id)->where('rsvp', '!=', 'no')->pluck('user_id')->push($m->organiser_id);
                    AppNotification::sendMany($ids, 'meeting_reminder', "$prefix: {$m->title}",
                        $m->starts_at->timezone('Asia/Kolkata')->format('D j M, g:i A'), ['meeting_id' => $m->id]);
                    $m->forceFill([$column => now()])->save();
                    $sent += $ids->unique()->count();
                });
        }

        $this->info("Sent $sent reminders.");

        return self::SUCCESS;
    }
}
