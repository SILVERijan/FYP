import json, math, urllib.request, itertools

def dist(p1, p2):
    return math.sqrt((p1[0]-p2[0])**2 + (p1[1]-p2[1])**2)

with open('d:/FYP/all_segments.json', 'r') as f:
    segments = json.load(f)

# Evaluate all permutations and orientations
best_order = None
best_dist = float('inf')
n = len(segments)

# Create indices
perms = itertools.permutations(range(n))
for p in perms:
    # 2^n orientations
    for i in range(1 << n):
        current_dist = 0
        valid = True
        for j in range(n - 1):
            seg1_idx = p[j]
            seg2_idx = p[j+1]
            rev1 = (i & (1 << j)) != 0
            rev2 = (i & (1 << (j+1))) != 0
            
            end1 = segments[seg1_idx][0] if rev1 else segments[seg1_idx][-1]
            start2 = segments[seg2_idx][-1] if rev2 else segments[seg2_idx][0]
            
            d = dist(end1, start2)
            current_dist += d
            if current_dist >= best_dist:
                valid = False
                break
        
        # Also consider closing the loop
        rev_first = (i & 1) != 0
        rev_last = (i & (1 << (n-1))) != 0
        start_first = segments[p[0]][-1] if rev_first else segments[p[0]][0]
        end_last = segments[p[-1]][0] if rev_last else segments[p[-1]][-1]
        
        # Add loop closing distance
        total_dist = current_dist + dist(end_last, start_first)
        
        if valid and total_dist < best_dist:
            best_dist = total_dist
            best_order = (p, i)

print(f"Optimal permutation: {best_order[0]} with flipping mask {best_order[1]}. Total gap (loop): {best_dist:.4f}")

p, i = best_order
ordered_segments = []
for j in range(n):
    seg = segments[p[j]][:]
    rev = (i & (1 << j)) != 0
    if rev:
        seg.reverse()
    ordered_segments.append(seg)

def get_osrm_route(start, end):
    # OSRM expects lon,lat
    url = f"http://router.project-osrm.org/route/v1/driving/{start[1]},{start[0]};{end[1]},{end[0]}?overview=full&geometries=geojson"
    req = urllib.request.Request(url, headers={'User-Agent': 'NepalYatayatCompleter/1.0'})
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
        if data['code'] == 'Ok':
            coords = data['routes'][0]['geometry']['coordinates']
            return [[c[1], c[0]] for c in coords] # back to lat, lon
    except Exception as e:
        print(f"OSRM Error: {e}")
    return []

final_route = []
for j in range(n):
    final_route.extend(ordered_segments[j])
    if j < n - 1 or True: # True to close loop
        next_j = (j + 1) % n
        p1 = ordered_segments[j][-1]
        p2 = ordered_segments[next_j][0]
        d = dist(p1, p2)
        if d > 0.005: # > 500m
            print(f"Gap of {d:.4f} between seg {j} and {next_j}. Fetching OSRM route...")
            fill = get_osrm_route(p1, p2)
            if fill:
                print(f"Filled with {len(fill)} points.")
                final_route.extend(fill)

print(f"Final completely closed route points: {len(final_route)}")

with open('d:/FYP/nepal_yatayat_full_polyline.php', 'w') as f:
    f.write("[\n")
    for pt in final_route:
        f.write(f"            [{pt[0]}, {pt[1]}],\n")
    f.write("        ]")

print("Saved perfectly joined loop to d:/FYP/nepal_yatayat_full_polyline.php")
