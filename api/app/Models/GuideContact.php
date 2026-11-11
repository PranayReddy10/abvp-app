<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class GuideContact extends Model
{
    protected $fillable = ['guide_item_id', 'user_id', 'name', 'role', 'phone', 'is_lead', 'sort'];

    protected function casts(): array
    {
        return ['is_lead' => 'boolean'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
