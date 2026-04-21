<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Route;
use App\Models\Stop;
use App\Models\FareRule;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RouteSearchController extends Controller
{
    /**
     * Suggest stops based on name for autocomplete.
     */
    public function suggestStops(Request $request)
    {
        $query = $request->input('query');
        if (!$query) {
            return response()->json([]);
        }

        $stops = Stop::where('name', 'LIKE', "%{$query}%")
            ->limit(10)
            ->get(['id', 'name', 'latitude', 'longitude']);

        return response()->json($stops);
    }

    public function findRoutes(Request $request)
    {
        $request->validate([
            'start_lat' => 'required|numeric',
            'start_lng' => 'required|numeric',
            'dest_lat' => 'required|numeric',
            'dest_lng' => 'required|numeric',
        ]);

        $startLat = $request->input('start_lat');
        $startLng = $request->input('start_lng');
        $destLat = $request->input('dest_lat');
        $destLng = $request->input('dest_lng');

        // 1. Find ALL stops within range for start and dest
        $startStops = $this->findStopsInRange($startLat, $startLng, 5.0);
        $destStops = $this->findStopsInRange($destLat, $destLng, 5.0);

        if ($startStops->isEmpty() || $destStops->isEmpty()) {
            return response()->json(['message' => 'No nearby stops found.'], 404);
        }

        $allPathsData = $this->findRoutesGraph($startStops, $destStops);
        $allPaths = [];
        $seenPathKeys = [];

        foreach ($allPathsData as $pData) {
            $path = $this->formatPath($pData['legs'], $startLat, $startLng, $destLat, $destLng, $startStops->first(), $destStops->first());
            $key = $this->getPathKey($path);
            if (!isset($seenPathKeys[$key])) {
                $allPaths[] = $path;
                $seenPathKeys[$key] = true;
            }
        }

        // Prioritize: 1. Fewer Legs (Transfers) | 2. Shorter Distance
        usort($allPaths, function($a, $b) {
            $legsA = count($a['legs']);
            $legsB = count($b['legs']);
            if ($legsA != $legsB) return $legsA <=> $legsB;
            return $a['total_distance_km'] <=> $b['total_distance_km'];
        });

        return response()->json(array_slice($allPaths, 0, 15));
    }

    private function getPathKey($path) 
    {
        // Simple key based on route IDs in sequence
        return implode('-', array_map(fn($l) => $l['route_id'], $path['legs']));
    }

    private function findStopsInRange($lat, $lng, $radiusKm = 5.0)
    {
        return Stop::select('*')
            ->selectRaw('(6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))) AS distance', [$lat, $lng, $lat])
            ->having('distance', '<=', $radiusKm)
            ->orderBy('distance')
            ->get();
    }

    private function findRoutesGraph($startStops, $destStops)
    {
        $allPaths = [];
        $destStopIds = $destStops->pluck('id')->toArray();
        
        // 1. Load data into memory for extreme speed
        $stopToRoutes = DB::table('route_stops')
            ->select('stop_id', 'route_id', 'sort_order')
            ->get()
            ->groupBy('stop_id')
            ->toArray();

        $routeToStops = DB::table('route_stops')
            ->join('stops', 'route_stops.stop_id', '=', 'stops.id')
            ->select('route_stops.*', 'stops.latitude', 'stops.longitude')
            ->orderBy('route_id')
            ->orderBy('sort_order')
            ->get()
            ->groupBy('route_id')
            ->toArray();

        $allStopsCache = Stop::all()->keyBy('id');

        // 2. Track best way to reach each stop
        // [stop_id => ['transfers' => int, 'legs' => [...]]]
        $reachedStops = [];
        $currentRoundStops = [];

        foreach ($startStops as $s) {
            $currentRoundStops[$s->id] = ['legs' => [], 'dist_from_start_m' => 0];
            $reachedStops[$s->id] = 0; // reached with 0 transfers
        }

        for ($round = 1; $round <= 3; $round++) {
            $nextRoundStops = [];
            $routesToScan = [];

            // Find all routes serving stops reached in the previous round
            foreach ($currentRoundStops as $stopId => $data) {
                if (!isset($stopToRoutes[$stopId])) continue;
                foreach ($stopToRoutes[$stopId] as $rs) {
                    if (!isset($routesToScan[$rs->route_id]) || $rs->sort_order < $routesToScan[$rs->route_id]) {
                        $routesToScan[$rs->route_id] = $rs->sort_order;
                    }
                }
            }

            // For each route, scan stops after the boarding stop
            foreach ($routesToScan as $routeId => $boardOrder) {
                $stops = $routeToStops[$routeId];
                $boarding = false;
                foreach ($stops as $s) {
                    if (!$boarding && $s->sort_order == $boardOrder) {
                        $boarding = true;
                        continue;
                    }
                    if (!$boarding) continue;

                    // This stop 's' is reached via this route
                    $newLeg = (object)[
                        'route_id' => $routeId,
                        'start_order' => $boardOrder,
                        'end_order' => $s->sort_order,
                        's_id' => $stops[array_search($boardOrder, array_column($stops, 'sort_order'))]->stop_id,
                        'd_id' => $s->stop_id,
                        'walk_after_m' => 0
                    ];

                    $prevPath = $currentRoundStops[$newLeg->s_id]['legs'];
                    $fullPath = array_merge($prevPath, [$newLeg]);

                    // Check if we hit destination
                    if (in_array($s->stop_id, $destStopIds)) {
                        $allPaths[] = ['legs' => $fullPath];
                    }

                    // Update reached stops for next round
                    if (!isset($reachedStops[$s->stop_id]) || $reachedStops[$s->stop_id] > $round) {
                        $reachedStops[$s->stop_id] = $round;
                        $nextRoundStops[$s->stop_id] = ['legs' => $fullPath];
                    }
                }
            }

            // Walking Transfers between rounds
            $walkingExtensions = [];
            foreach ($nextRoundStops as $sId => $data) {
                $stop = $allStopsCache[$sId] ?? null;
                if (!$stop) continue;

                $nearby = $this->findStopsInRange($stop->latitude, $stop->longitude, 0.3);
                foreach ($nearby as $ns) {
                    if ($ns->id == $sId) continue;
                    if (!isset($reachedStops[$ns->id])) {
                        $walkPath = $data['legs'];
                        $lastLeg = end($walkPath);
                        // Update last leg to include walking distance
                        $lastLeg->walk_after_m = round($ns->distance * 1000);
                        
                        $walkingExtensions[$ns->id] = ['legs' => $walkPath];
                        // We don't mark as reached with a transfer yet, it's a walking extension of the same transfer count
                    }
                }
            }
            
            $currentRoundStops = array_merge($nextRoundStops, $walkingExtensions);
            if (empty($currentRoundStops) || count($allPaths) > 15) break;
        }

        return $allPaths;
    }

    private function formatPath($legs, $startLat, $startLng, $destLat, $destLng, $firstStop, $lastStop)
    {
        $formattedLegs = [];
        $totalDistance = 0;
        $totalFare = 0;

        foreach ($legs as $l) {
            $route = Route::find($l->route_id);
            
            // Get intermediate stops for this leg
            $minOrder = min((int)$l->start_order, (int)$l->end_order);
            $maxOrder = max((int)$l->start_order, (int)$l->end_order);
            $stops = $route->stops()
                ->wherePivot('sort_order', '>=', $minOrder)
                ->wherePivot('sort_order', '<=', $maxOrder)
                ->get()
                ->map(fn($s) => [
                    'id' => $s->id,
                    'name' => $s->name,
                    'latitude' => $s->latitude,
                    'longitude' => $s->longitude,
                    'sort_order' => $s->pivot->sort_order
                ]);

            if ($l->start_order > $l->end_order) {
                $stops = $stops->reverse()->values();
            }

            $dist = $this->calculateRouteDistance($route, $l->start_order, $l->end_order);
            $fare = $this->calculateFare($dist);
            
            $totalDistance += $dist;
            $totalFare += $fare;

            $fromStop = Stop::find($l->s_id);
            $toStop = Stop::find($l->d_id);

            // Slice polyline for this specific leg
            $slicedPolyline = $this->slicePolyline($route->polyline, $fromStop->latitude, $fromStop->longitude, $toStop->latitude, $toStop->longitude);

            $formattedLegs[] = [
                'route_id' => $route->id,
                'route_name' => $route->name,
                'type' => $route->type,
                'color' => $route->color,
                'distance_km' => round($dist, 2),
                'fare' => $fare,
                'from_stop' => $fromStop->name,
                'to_stop' => $toStop->name,
                'from_stop_id' => $l->s_id,
                'to_stop_id' => $l->d_id,
                'from_lat' => $fromStop->latitude,
                'from_lng' => $fromStop->longitude,
                'to_lat' => $toStop->latitude,
                'to_lng' => $toStop->longitude,
                'start_order' => $l->start_order,
                'end_order' => $l->end_order,
                'stops' => $stops,
                'polyline' => $slicedPolyline,
                'walk_after_m' => $l->walk_after_m ?? 0
            ];
        }

        $walkToStart = $this->haversine($startLat, $startLng, $firstStop->latitude, $firstStop->longitude);
        $walkFromEnd = $this->haversine($lastStop->latitude, $lastStop->longitude, $destLat, $destLng);

        return [
            'legs' => $formattedLegs,
            'total_distance_km' => round($totalDistance, 2),
            'total_fare' => $totalFare,
            'walking_to_start_m' => round($walkToStart * 1000),
            'walking_from_end_m' => round($walkFromEnd * 1000),
            'start_stop' => $firstStop->name,
            'dest_stop' => $lastStop->name
        ];
    }

    private function slicePolyline($polyline, $startLat, $startLng, $endLat, $endLng)
    {
        if (empty($polyline) || !is_array($polyline)) return [];
        
        $startIndex = 0;
        $endIndex = count($polyline) - 1;
        $minDistStart = PHP_INT_MAX;
        $minDistEnd = PHP_INT_MAX;

        foreach ($polyline as $index => $point) {
            $pLat = is_array($point) ? ($point['lat'] ?? $point[0] ?? $point['latitude'] ?? null) : ($point->lat ?? $point->latitude ?? null);
            $pLng = is_array($point) ? ($point['lng'] ?? $point[1] ?? $point['longitude'] ?? null) : ($point->lng ?? $point->longitude ?? null);

            if ($pLat === null || $pLng === null) continue;

            $dStart = $this->haversine($startLat, $startLng, $pLat, $pLng);
            $dEnd = $this->haversine($endLat, $endLng, $pLat, $pLng);

            if ($dStart < $minDistStart) {
                $minDistStart = $dStart;
                $startIndex = $index;
            }
            if ($dEnd < $minDistEnd) {
                $minDistEnd = $dEnd;
                $endIndex = $index;
            }
        }

        if ($startIndex <= $endIndex) {
            return array_slice($polyline, $startIndex, $endIndex - $startIndex + 1);
        } else {
            return array_reverse(array_slice($polyline, $endIndex, $startIndex - $endIndex + 1));
        }
    }

    private function findNearestStop($lat, $lng, $radiusKm = 5.0)
    {
        return Stop::select('*')
            ->selectRaw('(6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))) AS distance', [$lat, $lng, $lat])
            ->having('distance', '<=', $radiusKm)
            ->orderBy('distance')
            ->first();
    }

    private function calculateRouteDistance($route, $startOrder, $endOrder)
    {
        $minOrder = min($startOrder, $endOrder);
        $maxOrder = max($startOrder, $endOrder);

        $stops = $route->stops()
            ->wherePivot('sort_order', '>=', $minOrder)
            ->wherePivot('sort_order', '<=', $maxOrder)
            ->get();

        if ($startOrder > $endOrder) {
            $stops = $stops->reverse()->values();
        }

        $totalDistance = 0;
        for ($i = 0; $i < count($stops) - 1; $i++) {
            $totalDistance += $this->haversine(
                $stops[$i]->latitude, $stops[$i]->longitude,
                $stops[$i+1]->latitude, $stops[$i+1]->longitude
            );
        }
        return $totalDistance;
    }

    private function calculateFare($distance)
    {
        $rule = FareRule::where('is_active', true)
            ->where('min_km', '<=', $distance)
            ->where(function($q) use ($distance) {
                $q->where('max_km', '>=', $distance)->orWhereNull('max_km');
            })
            ->first();

        return $rule ? $rule->fare : 37;
    }

    private function haversine($lat1, $lon1, $lat2, $lon2)
    {
        $earthRadius = 6371;
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);
        $a = sin($dLat / 2) * sin($dLat / 2) + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon / 2) * sin($dLon / 2);
        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
        return $earthRadius * $c;
    }
}
