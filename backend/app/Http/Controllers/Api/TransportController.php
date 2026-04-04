<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Route;
use App\Models\Vehicle;
use Illuminate\Http\Request;

class TransportController extends Controller
{
    public function getRoutes()
    {
        // Exclude polyline from list — only needed when viewing a specific route on map
        $routes = Route::select(['id', 'name', 'type', 'created_at', 'updated_at'])->get();
        return response()->json($routes);
    }

    public function getRouteDetails($id)
    {
        // Full details including polyline and stops for map display
        $route = Route::with('stops')->find($id);
        if (!$route) {
            return response()->json(['message' => 'Route not found'], 404);
        }
        return response()->json($route);
    }

    public function getVehicles()
    {
        // Vehicles with minimal route info — polyline excluded from query to save memory/bandwidth
        $vehicles = Vehicle::with(['route' => function($query) {
            $query->select(['id', 'name', 'type', 'created_at', 'updated_at']);
        }])
            ->where('status', 'active')
            ->get();
        return response()->json($vehicles);
    }
}
