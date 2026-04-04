<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Route extends Model
{
    use HasFactory;

    protected $fillable = ['name', 'type', 'polyline'];

    protected $casts = [
        'polyline' => 'array',
    ];

    public function vehicles()
    {
        return $this->hasMany(Vehicle::class);
    }

    public function stops()
    {
        return $this->belongsToMany(Stop::class, 'route_stops')
                    ->withPivot('sort_order')
                    ->withTimestamps()
                    ->orderBy('pivot_sort_order');
    }
}
