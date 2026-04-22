<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Route;
use App\Models\Stop;
use App\Models\FareRule;
use Illuminate\Support\Facades\DB;

class RouteSearchController extends Controller
{
    // Constants for routing
    const WALK_SPEED_MPS = 1.2; // approx 4.3 km/h
    const BUS_SPEED_MPS = 4.16; // approx 15 km/h
    const TRANSFER_PENALTY_SEC = 300; // 5 minutes penalty for changing routes
    const MAX_WALK_TRANSFER_M = 500; // Max walking distance between stops for a transfer
    const MAX_WALK_START_M = 1000; // Max walking distance from origin
    const MAX_WALK_END_M = 1000; // Max walking distance to destination

    public function suggestStops(Request $request)
    {
        $query = $request->query('query');
        if (!$query) return response()->json([]);

        $stops = Stop::where('name', 'like', "%{$query}%")
            ->take(10)
            ->get(['id', 'name', 'latitude', 'longitude']);
            
        return response()->json($stops);
    }

    public function findRoutes(Request $request)
    {
        $startLat = $request->query('start_lat');
        $startLng = $request->query('start_lng');
        $destLat = $request->query('dest_lat');
        $destLng = $request->query('dest_lng');

        if (!$startLat || !$startLng || !$destLat || !$destLng) {
            return response()->json(['error' => 'Missing coordinates'], 400);
        }

        // 1. Load Data
        $stops = Stop::all()->keyBy('id');
        $routes = Route::all()->keyBy('id');
        $routeStopsRaw = DB::table('route_stops')->orderBy('route_id')->orderBy('sort_order')->get();

        $routesPerStop = [];
        $stopsPerRoute = [];
        foreach ($routeStopsRaw as $rs) {
            $routesPerStop[$rs->stop_id][] = $rs->route_id;
            $stopsPerRoute[$rs->route_id][] = $rs;
        }

        // 2. Build Graph
        $graph = [];
        
        // Add Transit Edges (staying on the same bus)
        foreach ($stopsPerRoute as $rId => $rsList) {
            if (!isset($routes[$rId])) continue; // Skip inactive routes
            
            for ($i = 0; $i < count($rsList) - 1; $i++) {
                $curr = $rsList[$i];
                $next = $rsList[$i+1];
                
                $nodeA = "S_{$curr->stop_id}_R_{$rId}";
                $nodeB = "S_{$next->stop_id}_R_{$rId}";
                
                $sA = $stops[$curr->stop_id];
                $sB = $stops[$next->stop_id];
                $dist = $this->haversine($sA->latitude, $sA->longitude, $sB->latitude, $sB->longitude) * 1000;
                $time = $dist / self::BUS_SPEED_MPS;
                
                if (!isset($graph[$nodeA])) $graph[$nodeA] = [];
                $graph[$nodeA][] = [
                    'target' => $nodeB, 
                    'weight' => $time, 
                    'type' => 'transit', 
                    'route_id' => $rId,
                    'source_stop_id' => $curr->stop_id,
                    'target_stop_id' => $next->stop_id,
                    'source_stop_index' => $i,
                    'target_stop_index' => $i + 1,
                    'dist' => $dist
                ];

                // Add reverse edge for bidirectional travel
                if (!isset($graph[$nodeB])) $graph[$nodeB] = [];
                $graph[$nodeB][] = [
                    'target' => $nodeA, 
                    'weight' => $time, 
                    'type' => 'transit', 
                    'route_id' => $rId,
                    'source_stop_id' => $next->stop_id,
                    'target_stop_id' => $curr->stop_id,
                    'source_stop_index' => $i + 1,
                    'target_stop_index' => $i,
                    'dist' => $dist
                ];
            }
        }

        // Add Transfer Edges
        foreach ($stops as $id1 => $s1) {
            if (!isset($routesPerStop[$id1])) continue;
            $rList1 = array_intersect($routesPerStop[$id1], $routes->keys()->toArray());

            // Transfers at exactly the SAME stop
            foreach ($rList1 as $r1) {
                foreach ($rList1 as $r2) {
                    if ($r1 != $r2) {
                        $n1 = "S_{$id1}_R_{$r1}";
                        $n2 = "S_{$id1}_R_{$r2}";
                        if (!isset($graph[$n1])) $graph[$n1] = [];
                        $graph[$n1][] = [
                            'target' => $n2, 
                            'weight' => self::TRANSFER_PENALTY_SEC, 
                            'type' => 'transfer', 
                            'dist' => 0,
                            'route_id' => $r2,
                            'stop_id' => $id1
                        ];
                    }
                }
            }

            // Walking transfers to nearby stops
            foreach ($stops as $id2 => $s2) {
                if ($id1 >= $id2) continue;
                if (!isset($routesPerStop[$id2])) continue;
                
                $rList2 = array_intersect($routesPerStop[$id2], $routes->keys()->toArray());

                $dist = $this->haversine($s1->latitude, $s1->longitude, $s2->latitude, $s2->longitude) * 1000;
                if ($dist <= self::MAX_WALK_TRANSFER_M) {
                    $time = ($dist / self::WALK_SPEED_MPS) + self::TRANSFER_PENALTY_SEC;
                    foreach ($rList1 as $r1) {
                        foreach ($rList2 as $r2) {
                            if ($r1 == $r2) continue; // Walk to another stop for same route is pointless
                            
                            $n1 = "S_{$id1}_R_{$r1}";
                            $n2 = "S_{$id2}_R_{$r2}";
                            
                            if (!isset($graph[$n1])) $graph[$n1] = [];
                            $graph[$n1][] = [
                                'target' => $n2, 'weight' => $time, 'type' => 'walk', 'dist' => $dist, 
                                'target_route_id' => $r2, 'target_stop_id' => $id2
                            ];
                            
                            if (!isset($graph[$n2])) $graph[$n2] = [];
                            $graph[$n2][] = [
                                'target' => $n1, 'weight' => $time, 'type' => 'walk', 'dist' => $dist, 
                                'target_route_id' => $r1, 'target_stop_id' => $id1
                            ];
                        }
                    }
                }
            }
        }

        // Add Origin Edges
        $graph['START'] = [];
        $directDist = $this->haversine($startLat, $startLng, $destLat, $destLng) * 1000;
        $graph['START'][] = [
            'target' => 'END', 'weight' => $directDist / self::WALK_SPEED_MPS, 'type' => 'walk', 'dist' => $directDist, 'target_stop_id' => null
        ];

        foreach ($stops as $id => $s) {
            if (!isset($routesPerStop[$id])) continue;
            $rList = array_intersect($routesPerStop[$id], $routes->keys()->toArray());

            $distFromStart = $this->haversine($startLat, $startLng, $s->latitude, $s->longitude) * 1000;
            if ($distFromStart <= self::MAX_WALK_START_M) {
                $time = $distFromStart / self::WALK_SPEED_MPS;
                foreach ($rList as $r) {
                    $n = "S_{$id}_R_{$r}";
                    $graph['START'][] = [
                        'target' => $n, 'weight' => $time, 'type' => 'walk', 'dist' => $distFromStart, 'target_stop_id' => $id
                    ];
                }
            }

            $distToEnd = $this->haversine($s->latitude, $s->longitude, $destLat, $destLng) * 1000;
            if ($distToEnd <= self::MAX_WALK_END_M) {
                $time = $distToEnd / self::WALK_SPEED_MPS;
                foreach ($rList as $r) {
                    $n = "S_{$id}_R_{$r}";
                    if (!isset($graph[$n])) $graph[$n] = [];
                    $graph[$n][] = [
                        'target' => 'END', 'weight' => $time, 'type' => 'walk', 'dist' => $distToEnd, 'target_stop_id' => null
                    ];
                }
            }
        }

        // 3. Dijkstra Search
        $distances = [];
        $previous = [];
        $pq = new \SplPriorityQueue();
        
        $distances['START'] = 0;
        $pq->insert('START', 0);
        $visited = [];

        while (!$pq->isEmpty()) {
            $curr = $pq->extract();
            
            if (isset($visited[$curr])) continue;
            $visited[$curr] = true;

            if ($curr === 'END') break;
            
            if (!isset($graph[$curr])) continue;

            foreach ($graph[$curr] as $edge) {
                $target = $edge['target'];
                $weight = $edge['weight'];
                
                $newDist = $distances[$curr] + $weight;
                
                if (!isset($distances[$target]) || $newDist < $distances[$target]) {
                    $distances[$target] = $newDist;
                    $previous[$target] = [
                        'node' => $curr,
                        'edge' => $edge
                    ];
                    $pq->insert($target, -$newDist);
                }
            }
        }

        if (!isset($previous['END'])) {
            return response()->json([]); // No route found
        }

        // 4. Reconstruct Path
        $path = [];
        $curr = 'END';
        while (isset($previous[$curr])) {
            $path[] = $previous[$curr]['edge'];
            $curr = $previous[$curr]['node'];
        }
        $path = array_reverse($path);

        $legs = [];
        $currentTransitLeg = null;

        foreach ($path as $step) {
            $type = $step['type'];
            
            if ($type === 'walk' || $type === 'transfer') {
                if ($currentTransitLeg !== null) {
                    $legs[] = $currentTransitLeg;
                    $currentTransitLeg = null;
                }
                
                if ($step['dist'] > 0) {
                    $destName = isset($step['target_stop_id']) && isset($stops[$step['target_stop_id']]) 
                        ? " to " . $stops[$step['target_stop_id']]->name 
                        : " to destination";
                    $legs[] = [
                        'type' => 'walk',
                        'distance_m' => round($step['dist']),
                        'time_min' => max(1, ceil($step['dist'] / self::WALK_SPEED_MPS / 60)),
                        'instruction' => 'Walk ' . round($step['dist']) . 'm' . $destName,
                    ];
                }
            } else if ($type === 'transit') {
                $rId = $step['route_id'];
                $route = $routes[$rId];
                
                $sourceStop = $stops[$step['source_stop_id']];
                $targetStop = $stops[$step['target_stop_id']];
                
                if ($currentTransitLeg === null) {
                    $currentTransitLeg = [
                        'type' => 'transit',
                        'route_id' => $rId,
                        'route_name' => $route->name,
                        'color' => $route->color,
                        'transport_type' => $route->type ?? 'bus',
                        'distance_km' => 0,
                        'stops' => [
                            [
                                'name' => $sourceStop->name,
                                'latitude' => $sourceStop->latitude,
                                'longitude' => $sourceStop->longitude
                            ]
                        ],
                        'from_stop' => $sourceStop->name,
                        'to_stop' => '', 
                        'polyline' => [],
                        'start_order' => $step['source_stop_index'],
                        'end_order' => $step['target_stop_index'],
                        'from_lat' => $sourceStop->latitude,
                        'from_lng' => $sourceStop->longitude,
                        'to_lat' => $targetStop->latitude,
                        'to_lng' => $targetStop->longitude,
                        'from_stop_id' => $step['source_stop_id'],
                        'to_stop_id' => $step['target_stop_id'],
                    ];
                }
                
                $currentTransitLeg['stops'][] = [
                    'name' => $targetStop->name,
                    'latitude' => $targetStop->latitude,
                    'longitude' => $targetStop->longitude
                ];
                $currentTransitLeg['to_stop'] = $targetStop->name;
                $currentTransitLeg['end_order'] = $step['target_stop_index'];
                $currentTransitLeg['to_stop_id'] = $step['target_stop_id'];
                $currentTransitLeg['distance_km'] += ($step['dist'] / 1000);
                $currentTransitLeg['to_lat'] = $targetStop->latitude;
                $currentTransitLeg['to_lng'] = $targetStop->longitude;
            }
        }
        
        if ($currentTransitLeg !== null) {
            $legs[] = $currentTransitLeg;
        }

        // Post-process legs to calculate fare and slice polylines
        $totalFare = 0;
        $totalDistance = 0;

        foreach ($legs as &$leg) {
            if ($leg['type'] === 'transit') {
                $leg['distance_km'] = round($leg['distance_km'], 2);
                $totalDistance += $leg['distance_km'];
                
                $route = $routes[$leg['route_id']];
                $fare = $this->calculateFare($leg['distance_km'], $route);
                $leg['fare'] = $fare;
                $totalFare += $fare;
                
                // Slice polyline using nearest-point coordinate search for accuracy
                $polyPoints = is_string($route->polyline) ? json_decode($route->polyline, true) : $route->polyline;
                if ($polyPoints && is_array($polyPoints) && count($polyPoints) >= 2) {
                    $fromStop = $stops[$leg['from_stop_id']] ?? null;
                    $toStop   = $stops[$leg['to_stop_id']] ?? null;

                    if ($fromStop && $toStop) {
                        $idxStart = $this->nearestPolylineIndex($polyPoints, $fromStop->latitude, $fromStop->longitude);
                        $idxEnd   = $this->nearestPolylineIndex($polyPoints, $toStop->latitude, $toStop->longitude);

                        if ($idxStart <= $idxEnd) {
                            $leg['polyline'] = array_slice($polyPoints, $idxStart, $idxEnd - $idxStart + 1);
                        } else {
                            // Reverse-direction travel — slice and flip
                            $sliced = array_slice($polyPoints, $idxEnd, $idxStart - $idxEnd + 1);
                            $leg['polyline'] = array_reverse($sliced);
                        }
                    } else {
                        $leg['polyline'] = $polyPoints; // fallback: full polyline
                    }
                }
            }
        }

        // Strip internal routing keys before returning
        foreach ($legs as &$leg) {
            unset($leg['start_order'], $leg['end_order'], $leg['from_stop_id'], $leg['to_stop_id']);
        }
        unset($leg);

        return response()->json([[
            'legs' => $legs,
            'total_distance_km' => round($totalDistance, 2),
            'total_fare' => $totalFare,
            'estimated_time_min' => max(1, ceil($distances['END'] / 60))
        ]]);
    }

    private function calculateFare($distance, $route = null)
    {
        $rules = FareRule::where('is_active', true)
            ->where('min_km', '<=', $distance)
            ->where(function($q) use ($distance) {
                $q->where('max_km', '>=', $distance)->orWhereNull('max_km');
            })
            ->get();

        if ($rules->isEmpty()) return 37; // Default

        if ($route) {
            $routeRule = $rules->firstWhere('route_id', $route->id);
            if ($routeRule) return $routeRule->fare;

            $typeRule = $rules->firstWhere('vehicle_type', $route->type);
            if ($typeRule) return $typeRule->fare;
        }

        $generalRule = $rules->whereNull('route_id')->whereNull('vehicle_type')->first();
        return $generalRule ? $generalRule->fare : $rules->first()->fare;
    }

    /**
     * Find the index of the polyline point closest to the given coordinates.
     */
    private function nearestPolylineIndex(array $polyPoints, float $lat, float $lng): int
    {
        $best = 0;
        $bestDist = PHP_FLOAT_MAX;
        foreach ($polyPoints as $i => $p) {
            // Polyline points can be [lat, lng] arrays or {lat, lng} objects
            $pLat = is_array($p) ? (float)$p[0] : (float)($p['lat'] ?? $p['latitude'] ?? 0);
            $pLng = is_array($p) ? (float)$p[1] : (float)($p['lng'] ?? $p['longitude'] ?? 0);
            $d = ($pLat - $lat) ** 2 + ($pLng - $lng) ** 2; // squared distance is fine for comparison
            if ($d < $bestDist) {
                $bestDist = $d;
                $best = $i;
            }
        }
        return $best;
    }

    private function haversine($lat1, $lon1, $lat2, $lon2)
    {
        $r = 6371; // km
        $p = pi() / 180;

        $a = 0.5 - cos(($lat2 - $lat1) * $p)/2 +
             cos($lat1 * $p) * cos($lat2 * $p) *
             (1 - cos(($lon2 - $lon1) * $p))/2;

        return 2 * $r * asin(sqrt($a));
    }
}
