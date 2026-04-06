<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Vehicle extends Model
{
    use HasFactory;

    protected $fillable = ['vehicle_name', 'type', 'capacity', 'plate_number', 'current_lat', 'current_lng', 'status', 'route_id'];

    public function route()
    {
        return $this->belongsTo(Route::class);
    }
}
