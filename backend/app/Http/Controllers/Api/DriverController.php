<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Vehicle;

class DriverController extends Controller
{
    public function updateLocation(Request $request)
    {
        $validated = $request->validate([
            'vehicle_id' => 'required|exists:vehicles,id',
            'latitude' => 'required|numeric',
            'longitude' => 'required|numeric',
            'status' => 'sometimes|string|in:active,inactive',
        ]);

        $vehicle = Vehicle::findOrFail($validated['vehicle_id']);
        
        $vehicle->update([
            'current_lat' => $validated['latitude'],
            'current_lng' => $validated['longitude'],
            'status' => $validated['status'] ?? $vehicle->status,
        ]);

        return response()->json([
            'message' => 'Location updated successfully',
            'vehicle' => $vehicle
        ]);
    }

    public function getMyVehicles()
    {
        // For now, return all vehicles. In the future, this could be filtered by company.
        return response()->json([
            'data' => Vehicle::all()
        ]);
    }
}
