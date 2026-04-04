<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\TransportController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\AdminController;
use App\Models\User;
use App\Models\Vehicle;
use App\Models\Route as TransportRouteModel;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/user/update', [AuthController::class, 'updateProfile']);
});

Route::get('/health', function () {
    return response()->json(['status' => 'OK', 'message' => 'Backend is connected!']);
});

Route::prefix('transport')->group(function () {
    Route::get('/routes', [TransportController::class, 'getRoutes']);
    Route::get('/routes/{id}', [TransportController::class, 'getRouteDetails']);
    Route::get('/vehicles', [TransportController::class, 'getVehicles']);
});

// Protected Admin Routes
Route::middleware(['auth:sanctum', 'admin'])->prefix('admin')->group(function () {
    Route::get('/dashboard', function () {
        return response()->json([
            'status' => 'Success',
            'data' => [
                'total_users' => User::count(),
                'total_routes' => TransportRouteModel::count(),
                'total_vehicles' => Vehicle::count(),
            ]
        ]);
    });

    // Admin Users Management
    Route::get('/users', [AdminController::class, 'getUsers']);
    Route::post('/users', [AdminController::class, 'createUser']);
    Route::put('/users/{id}', [AdminController::class, 'updateUser']);
    Route::delete('/users/{id}', [AdminController::class, 'deleteUser']);

    // Admin Vehicles Management
    Route::get('/vehicles', [AdminController::class, 'getVehicles']);
    Route::post('/vehicles', [AdminController::class, 'createVehicle']);
    Route::put('/vehicles/{id}', [AdminController::class, 'updateVehicle']);
    Route::delete('/vehicles/{id}', [AdminController::class, 'deleteVehicle']);

    // Admin Routes Management
    Route::get('/routes', [AdminController::class, 'getRoutes']);
    Route::post('/routes', [AdminController::class, 'createRoute']);
    Route::put('/routes/{id}', [AdminController::class, 'updateRoute']);
    Route::delete('/routes/{id}', [AdminController::class, 'deleteRoute']);
});

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');
