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

    public function getVehicles(Request $request)
    {
        // Vehicles with minimal route info — polyline excluded from query to save memory/bandwidth
        $query = Vehicle::with(['route' => function($q) {
            $q->select(['id', 'name', 'type', 'created_at', 'updated_at']);
        }])->where('status', 'active');

        if ($request->has('route_ids')) {
            $routeIds = array_filter(explode(',', $request->input('route_ids')));
            if (!empty($routeIds)) {
                $query->whereIn('route_id', $routeIds);
            }
        }

        $vehicles = $query->get();
        return response()->json($vehicles);
    }
}
