<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FareRule extends Model
{
    use HasFactory;

    protected $fillable = [
        'min_km',
        'max_km',
        'fare',
        'is_active'
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'min_km' => 'double',
        'max_km' => 'double',
        'fare' => 'double',
    ];
}
