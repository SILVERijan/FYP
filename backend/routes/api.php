<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\TransportController;
use App\Http\Controllers\Api\AuthController;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
});

Route::get('/health', function () {
    return response()->json(['status' => 'OK', 'message' => 'Backend is connected!']);
});

Route::prefix('transport')->group(function () {
    Route::get('/routes', [TransportController::class, 'getRoutes']);
    Route::get('/routes/{id}', [TransportController::class, 'getRouteDetails']);
    Route::get('/vehicles', [TransportController::class, 'getVehicles']);
});

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');
