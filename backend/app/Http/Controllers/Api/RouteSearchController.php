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

        $allPaths = [];
        $seenPathKeys = []; // To avoid duplicate paths

        // Limit combinations to prevent performance issues
        $topStartStops = $startStops->take(5);
        $topDestStops = $destStops->take(5);

        foreach ($topStartStops as $sStop) {
            foreach ($topDestStops as $dStop) {
                // a. Direct Routes
                $direct = $this->findDirectRoutes($sStop->id, $dStop->id);
                foreach ($direct as $d) {
                    $path = $this->formatPath([$d], $startLat, $startLng, $destLat, $destLng, $sStop, $dStop);
                    $key = $this->getPathKey($path);
                    if (!isset($seenPathKeys[$key])) {
                        $allPaths[] = $path;
                        $seenPathKeys[$key] = true;
                    }
                }

                // b. Transfer Routes (up to 3 buses total)
                $transfers = $this->findTransferRoutesRecursive($sStop->id, $dStop->id);
                foreach ($transfers as $t) {
                    $path = $this->formatPath($t, $startLat, $startLng, $destLat, $destLng, $sStop, $dStop);
                    $key = $this->getPathKey($path);
                    if (!isset($seenPathKeys[$key])) {
                        $allPaths[] = $path;
                        $seenPathKeys[$key] = true;
                    }
                }
            }
        }

        // Sort by total distance
        usort($allPaths, fn($a, $b) => $a['total_distance_km'] <=> $b['total_distance_km']);

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

    private function findDirectRoutes($sId, $dId)
    {
        return DB::table('route_stops as rs1')
            ->join('route_stops as rs2', 'rs1.route_id', '=', 'rs2.route_id')
            ->where('rs1.stop_id', $sId)
            ->where('rs2.stop_id', $dId)
            ->where('rs1.sort_order', '<', 'rs2.sort_order')
            ->select('rs1.route_id', 'rs1.sort_order as start_order', 'rs2.sort_order as end_order', 'rs1.stop_id as s_id', 'rs2.stop_id as d_id')
            ->get();
    }

    /**
     * Finds paths with up to 2 transfers (3 buses).
     */
    private function findTransferRoutesRecursive($sId, $dId)
    {
        $results = [];

        // --- ONE TRANSFER (2 Buses) ---
        $oneTransfer = DB::table('route_stops as rs1_end')
            ->join('route_stops as rs2_start', 'rs1_end.stop_id', '=', 'rs2_start.stop_id')
            ->join('route_stops as r1_start', 'rs1_end.route_id', '=', 'r1_start.route_id')
            ->join('route_stops as r2_end', 'rs2_start.route_id', '=', 'r2_end.route_id')
            ->where('r1_start.stop_id', $sId)
            ->where('r2_end.stop_id', $dId)
            ->where('r1_start.sort_order', '<', 'rs1_end.sort_order')
            ->where('rs2_start.sort_order', '<', 'r2_end.sort_order')
            ->where('rs1_end.route_id', '!=', 'rs2_start.route_id')
            ->select(
                'rs1_end.route_id as r1_id', 'r1_start.sort_order as r1_s', 'rs1_end.sort_order as r1_e',
                'rs2_start.route_id as r2_id', 'rs2_start.sort_order as r2_s', 'r2_end.sort_order as r2_e',
                'rs1_end.stop_id as t1_id'
            )
            ->limit(10)
            ->get();

        foreach ($oneTransfer as $ot) {
            $results[] = [
                (object)['route_id' => $ot->r1_id, 'start_order' => $ot->r1_s, 'end_order' => $ot->r1_e, 's_id' => $sId, 'd_id' => $ot->t1_id],
                (object)['route_id' => $ot->r2_id, 'start_order' => $ot->r2_s, 'end_order' => $ot->r2_e, 's_id' => $ot->t1_id, 'd_id' => $dId],
            ];
        }

        // --- TWO TRANSFERS (3 Buses) ---
        // Find routes passing through start
        $startRoutes = DB::table('route_stops')->where('stop_id', $sId)->pluck('route_id')->toArray();
        // Find routes passing through dest
        $destRoutes = DB::table('route_stops')->where('stop_id', $dId)->pluck('route_id')->toArray();

        // Find all routes that intersect with start routes
        $midRoutes = DB::table('route_stops as rs1')
            ->join('route_stops as rs2', 'rs1.stop_id', '=', 'rs2.stop_id')
            ->whereIn('rs1.route_id', $startRoutes)
            ->whereNotIn('rs2.route_id', $startRoutes)
            ->select('rs1.route_id as start_r', 'rs1.sort_order as start_r_e', 'rs2.route_id as mid_r', 'rs2.sort_order as mid_r_s', 'rs2.stop_id as t1')
            ->limit(50)
            ->get();

        foreach ($midRoutes as $mr) {
            // Check if this midRoute intersects with any destRoute
            $finalLegs = DB::table('route_stops as rsA')
                ->join('route_stops as rsB', 'rsA.stop_id', '=', 'rsB.stop_id')
                ->join('route_stops as rsStart', 'rsA.route_id', '=', 'rsStart.route_id')
                ->join('route_stops as rsEnd', 'rsB.route_id', '=', 'rsEnd.route_id')
                ->where('rsA.route_id', $mr->mid_r)
                ->whereIn('rsB.route_id', $destRoutes)
                ->where('rsStart.stop_id', $mr->t1)
                ->where('rsEnd.stop_id', $dId)
                ->where('rsStart.sort_order', '<', 'rsA.sort_order')
                ->where('rsB.sort_order', '<', 'rsEnd.sort_order')
                ->select('rsA.route_id', 'rsStart.sort_order as s1', 'rsA.sort_order as e1', 'rsB.route_id as r_final', 'rsB.sort_order as s2', 'rsEnd.sort_order as e2', 'rsA.stop_id as t2')
                ->first();

            if ($finalLegs) {
                // Find start leg sort order for $sId
                $startLeg = DB::table('route_stops')
                    ->where('route_id', $mr->start_r)
                    ->where('stop_id', $sId)
                    ->first();
                
                if ($startLeg && $startLeg->sort_order < $mr->start_r_e) {
                    $results[] = [
                        (object)['route_id' => $mr->start_r, 'start_order' => $startLeg->sort_order, 'end_order' => $mr->start_r_e, 's_id' => $sId, 'd_id' => $mr->t1],
                        (object)['route_id' => $mr->mid_r, 'start_order' => $finalLegs->s1, 'end_order' => $finalLegs->e1, 's_id' => $mr->t1, 'd_id' => $finalLegs->t2],
                        (object)['route_id' => $finalLegs->r_final, 'start_order' => $finalLegs->s2, 'end_order' => $finalLegs->e2, 's_id' => $finalLegs->t2, 'd_id' => $dId],
                    ];
                }
            }
            if (count($results) >= 20) break;
        }

        return $results;
    }

    private function formatPath($legs, $startLat, $startLng, $destLat, $destLng, $firstStop, $lastStop)
    {
        $formattedLegs = [];
        $totalDistance = 0;
        $totalFare = 0;

        foreach ($legs as $l) {
            $route = Route::find($l->route_id);
            $dist = $this->calculateRouteDistance($route, $l->start_order, $l->end_order);
            $fare = $this->calculateFare($dist);
            
            $totalDistance += $dist;
            $totalFare += $fare;

            $fromStop = Stop::find($l->s_id);
            $toStop = Stop::find($l->d_id);

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
                'polyline' => $route->polyline
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
        $stops = $route->stops()
            ->wherePivot('sort_order', '>=', $startOrder)
            ->wherePivot('sort_order', '<=', $endOrder)
            ->get();

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
