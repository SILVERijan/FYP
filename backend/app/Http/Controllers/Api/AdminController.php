<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\User;
use App\Models\Vehicle;
use App\Models\Route as TransportRoute;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Support\Facades\DB;
use App\Models\Stop;
use App\Models\FareRule;
use Illuminate\Support\Facades\Log;

class AdminController extends Controller
{
    // === USERS ===
    public function getUsers()
    {
        return response()->json(User::paginate(15));
    }

    public function createUser(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:8',
            'role' => ['required', Rule::in(['user', 'admin', 'driver'])],
            'company_name' => 'nullable|string|max:255',
        ]);

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => Hash::make($validated['password']),
            'role' => $validated['role'],
            'company_name' => $validated['company_name'] ?? null,
            'is_active' => true,
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
            'role' => ['sometimes', Rule::in(['user', 'admin', 'driver'])],
            'company_name' => 'nullable|string|max:255',
            'is_active' => 'sometimes|boolean',
        ]);

        if (isset($validated['name'])) $user->name = $validated['name'];
        if (isset($validated['email'])) $user->email = $validated['email'];
        if (isset($validated['role'])) $user->role = $validated['role'];
        if (array_key_exists('company_name', $validated)) $user->company_name = $validated['company_name'];
        if (array_key_exists('is_active', $validated)) $user->is_active = $validated['is_active'];
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
        return response()->json(TransportRoute::with('stops')->paginate(15));
    }

    public function createRoute(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'type' => 'required|string|max:255',
            'color' => 'sometimes|string|max:10',
            'polyline' => 'sometimes|array',
            'stops' => 'sometimes|array',
            'stops.*.name' => 'required_with:stops|string|max:255',
            'stops.*.latitude' => 'required_with:stops|numeric',
            'stops.*.longitude' => 'required_with:stops|numeric',
        ]);

        return DB::transaction(function () use ($validated) {
            $route = TransportRoute::create([
                'name' => $validated['name'],
                'type' => $validated['type'],
                'color' => $validated['color'] ?? '#FF0000',
                'polyline' => $validated['polyline'] ?? [],
            ]);

            if (isset($validated['stops'])) {
                foreach ($validated['stops'] as $index => $stopData) {
                    $stop = $this->findOrCreateStop($stopData);
                    $route->stops()->attach($stop->id, ['sort_order' => $index]);
                }
            }

            return response()->json(['message' => 'Route created successfully', 'data' => $route->load('stops')], 201);
        });
    }

    public function updateRoute(Request $request, $id)
    {
        $route = TransportRoute::findOrFail($id);
        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'type' => 'sometimes|string|max:255',
            'color' => 'sometimes|string|max:10',
            'polyline' => 'sometimes|array',
            'stops' => 'sometimes|array',
            'stops.*.name' => 'required_with:stops|string|max:255',
            'stops.*.latitude' => 'required_with:stops|numeric',
            'stops.*.longitude' => 'required_with:stops|numeric',
        ]);

        return DB::transaction(function () use ($validated, $route) {
            $route->update($validated);

            if (isset($validated['stops'])) {
                $route->stops()->detach();
                foreach ($validated['stops'] as $index => $stopData) {
                    $stop = $this->findOrCreateStop($stopData);
                    $route->stops()->attach($stop->id, ['sort_order' => $index]);
                }
            }

            return response()->json(['message' => 'Route updated successfully', 'data' => $route->load('stops')]);
        });
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
        // Load relationships and paginate
        return response()->json(Vehicle::with('route')->paginate(15));
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

    // === FARE RULES ===
    public function getFareRules()
    {
        return response()->json([
            'data' => FareRule::with('route')->orderBy('min_km')->get()
        ]);
    }

    public function createFareRule(Request $request)
    {
        $validated = $request->validate([
            'min_km' => 'required|numeric',
            'max_km' => 'nullable|numeric',
            'fare' => 'required|numeric',
            'is_active' => 'boolean',
            'vehicle_type' => 'nullable|string|max:255',
            'route_id' => 'nullable|exists:routes,id',
        ]);

        $rule = FareRule::create($validated);
        $rule->load('route');
        return response()->json(['message' => 'Fare rule created successfully', 'data' => $rule], 201);
    }

    public function updateFareRule(Request $request, $id)
    {
        $rule = FareRule::findOrFail($id);
        $validated = $request->validate([
            'min_km' => 'sometimes|numeric',
            'max_km' => 'nullable|numeric',
            'fare' => 'sometimes|numeric',
            'is_active' => 'sometimes|boolean',
            'vehicle_type' => 'nullable|string|max:255',
            'route_id' => 'nullable|exists:routes,id',
        ]);

        $rule->update($validated);
        $rule->load('route');
        return response()->json(['message' => 'Fare rule updated successfully', 'data' => $rule]);
    }

    public function deleteFareRule($id)
    {
        $rule = FareRule::findOrFail($id);
        $rule->delete();
        return response()->json(['message' => 'Fare rule deleted successfully']);
    }

    private function findOrCreateStop($data)
    {
        // Check for an existing stop within ~20 meters (approx 0.0002 degrees)
        $threshold = 0.0002;
        $existing = Stop::whereBetween('latitude', [$data['latitude'] - $threshold, $data['latitude'] + $threshold])
            ->whereBetween('longitude', [$data['longitude'] - $threshold, $data['longitude'] + $threshold])
            ->first();

        if ($existing) {
            return $existing;
        }

        return Stop::create([
            'name' => $data['name'],
            'latitude' => $data['latitude'],
            'longitude' => $data['longitude'],
        ]);
    }
}
