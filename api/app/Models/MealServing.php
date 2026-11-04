<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class MealServing extends Model
{
    public $timestamps = false;

    protected $fillable = ['meal_session_id', 'user_id', 'served_by', 'counter', 'served_at'];

    protected function casts(): array
    {
        return ['served_at' => 'datetime'];
    }
}
