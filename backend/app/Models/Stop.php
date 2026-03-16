<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Stop extends Model
{
    use HasFactory;

    protected $fillable = ['name', 'latitude', 'longitude'];

    public function routes()
    {
        return $this->belongsToMany(Route::class, 'route_stops');
    }
}
