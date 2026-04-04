<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AdminMiddleware
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        // First check if the user is authenticated at all
        if (!$request->user()) {
            return response()->json([
                'status' => 'Error',
                'message' => 'Unauthenticated.'
            ], 401);
        }

        // Then verify their role
        if ($request->user()->role !== 'admin') {
            return response()->json([
                'status' => 'Error',
                'message' => 'Forbidden. Admin access required.'
            ], 403);
        }

        return $next($request);
    }
}
