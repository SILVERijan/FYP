<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\User;
use App\Models\Vehicle;
use App\Models\Route as TransportRoute;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class AdminController extends Controller
{
    // === USERS ===
    public function getUsers()
    {
        return response()->json(['data' => User::all()]);
    }

    public function createUser(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:8',
            'role' => ['required', Rule::in(['user', 'admin'])],
        ]);

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => Hash::make($validated['password']),
            'role' => $validated['role'],
        ]);

        return response()->json(['message' => 'User created successfully', 'data' => $user], 201);
    }

    public function updateUser(Request $request, $id)
    {
        $user = User::findOrFail($id);
        
        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'email' => ['sometimes', 'email', Rule::unique('users')->ignore($user->id)],
            'password' => 'nullable|string|min:8',
            'role' => ['sometimes', Rule::in(['user', 'admin'])],
        ]);

        if (isset($validated['name'])) $user->name = $validated['name'];
        if (isset($validated['email'])) $user->email = $validated['email'];
        if (isset($validated['role'])) $user->role = $validated['role'];
        if (!empty($validated['password'])) $user->password = Hash::make($validated['password']);

        $user->save();

        return response()->json(['message' => 'User updated successfully', 'data' => $user]);
    }

    public function deleteUser($id)
    {
        $user = User::findOrFail($id);
        if ($user->id === auth()->id()) {
            return response()->json(['message' => 'Cannot delete yourself'], 400);
        }
        $user->delete();
        return response()->json(['message' => 'User deleted successfully']);
    }

    // === ROUTES ===
    public function getRoutes()
    {
        return response()->json(['data' => TransportRoute::all()]);
    }

    public function createRoute(Request $request)
    {
        $validated = $request->validate([
            'route_name' => 'required|string|max:255',
            'origin' => 'required|string|max:255',
            'destination' => 'required|string|max:255',
            'distance_km' => 'nullable|numeric',
            'estimated_duration' => 'nullable|string',
            'encoded_polyline' => 'nullable|string'
        ]);

        $route = TransportRoute::create($validated);
        return response()->json(['message' => 'Route created successfully', 'data' => $route], 201);
    }

    public function updateRoute(Request $request, $id)
    {
        $route = TransportRoute::findOrFail($id);
        $route->update($request->all());
        return response()->json(['message' => 'Route updated successfully', 'data' => $route]);
    }

    public function deleteRoute($id)
    {
        $route = TransportRoute::findOrFail($id);
        $route->delete();
        return response()->json(['message' => 'Route deleted successfully']);
    }

    // === VEHICLES ===
    public function getVehicles()
    {
        // Load relationships if needed, e.g., route
        return response()->json(['data' => Vehicle::with('route')->get()]);
    }

    public function createVehicle(Request $request)
    {
        $validated = $request->validate([
            'vehicle_name' => 'required|string|max:255',
            'plate_number' => 'required|string|max:255|unique:vehicles',
            'route_id' => 'required|exists:routes,id',
            'type' => 'required|string|max:255',
            'capacity' => 'nullable|integer',
            'status' => 'nullable|string'
        ]);

        $vehicle = Vehicle::create($validated);
        // Load route relation so frontend has it immediately
        $vehicle->load('route');
        return response()->json(['message' => 'Vehicle created successfully', 'data' => $vehicle], 201);
    }

    public function updateVehicle(Request $request, $id)
    {
        $vehicle = Vehicle::findOrFail($id);
        
        $validated = $request->validate([
            'vehicle_name' => 'sometimes|string|max:255',
            'plate_number' => ['sometimes', 'string', 'max:255', Rule::unique('vehicles')->ignore($vehicle->id)],
            'route_id' => 'sometimes|exists:routes,id',
            'type' => 'sometimes|string|max:255',
            'capacity' => 'nullable|integer',
            'status' => 'nullable|string'
        ]);

        $vehicle->update($validated);
        $vehicle->load('route');
        return response()->json(['message' => 'Vehicle updated successfully', 'data' => $vehicle]);
    }

    public function deleteVehicle($id)
    {
        $vehicle = Vehicle::findOrFail($id);
        $vehicle->delete();
        return response()->json(['message' => 'Vehicle deleted successfully']);
    }
}
