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
        return response()->json(Route::all());
    }

    public function getRouteDetails($id)
    {
        $route = Route::with('stops')->find($id);
        if (!$route) {
            return response()->json(['message' => 'Route not found'], 404);
        }
        return response()->json($route);
    }

    public function getVehicles()
    {
        // Get all active vehicles with their assigned route information
        $vehicles = Vehicle::with('route')->where('status', 'active')->get();
        return response()->json($vehicles);
    }
}
