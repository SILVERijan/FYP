<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Route;
use App\Models\Stop;
use App\Models\Vehicle;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            AdminUserSeeder::class,
        ]);
        
        // 1. Create a Route
        $route = Route::create([
            'name' => 'Ratnapark - Kalanki',
            'type' => 'Bus',
        ]);

        // 2. Create Stops
        $stop1 = Stop::create(['name' => 'Ratnapark', 'latitude' => 27.7061, 'longitude' => 85.3148]);
        $stop2 = Stop::create(['name' => 'Tripureshwor', 'latitude' => 27.6937, 'longitude' => 85.3117]);
        $stop3 = Stop::create(['name' => 'Kalimati', 'latitude' => 27.6980, 'longitude' => 85.2974]);
        $stop4 = Stop::create(['name' => 'Kalanki', 'latitude' => 27.6938, 'longitude' => 85.2817]);

        // 3. Attach Stops to Route
        $route->stops()->attach([
            $stop1->id => ['sort_order' => 1],
            $stop2->id => ['sort_order' => 2],
            $stop3->id => ['sort_order' => 3],
            $stop4->id => ['sort_order' => 4],
        ]);

        // 4. Create a Vehicle
        Vehicle::create([
            'plate_number' => 'BA 2 KHA 1234',
            'current_lat' => 27.7000,
            'current_lng' => 85.3050,
            'status' => 'active',
            'route_id' => $route->id,
        ]);
        
        Vehicle::create([
            'plate_number' => 'BA 1 KHA 5678',
            'current_lat' => 27.6950,
            'current_lng' => 85.2900,
            'status' => 'active',
            'route_id' => $route->id,
        ]);
    }
}
