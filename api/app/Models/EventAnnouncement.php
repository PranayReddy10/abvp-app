<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EventAnnouncement extends Model
{
    protected $fillable = ['event_id', 'sent_by', 'audience', 'title', 'body', 'recipients'];

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sent_by');
    }
}
