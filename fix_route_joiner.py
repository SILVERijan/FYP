import json
import math

def dist(p1, p2):
    return math.sqrt((p1[0] - p2[0])**2 + (p1[1] - p2[1])**2)

with open('d:/FYP/all_segments.json', 'r') as f:
    segments = json.load(f)

print(f"Total segments: {len(segments)}")

# Identify the Northmost segment (highest latitude)
northmost_idx = -1
max_lat = -90
for i, seg in enumerate(segments):
    highest_lat = max(p[0] for p in seg)
    if highest_lat > max_lat:
        max_lat = highest_lat
        northmost_idx = i

print(f"Starting with Segment {northmost_idx} (Max Lat: {max_lat})")

ordered_route = []
available = segments[:]
current = available.pop(northmost_idx)

# Ensure 'current' starts at its Northmost point
if current[-1][0] > current[0][0]:
    current.reverse()

ordered_route.extend(current)

while available:
    last_pt = ordered_route[-1]
    best_idx = -1
    best_dist = 1e9
    should_reverse = False
    
    for i, seg in enumerate(available):
        d_start = dist(last_pt, seg[0])
        d_end = dist(last_pt, seg[-1])
        
        if d_start < best_dist:
            best_dist = d_start
            best_idx = i
            should_reverse = False
        if d_end < best_dist:
            best_dist = d_end
            best_idx = i
            should_reverse = True
            
    if best_idx != -1 and best_dist < 0.1: # Connect if reasonably close
        next_seg = available.pop(best_idx)
        if should_reverse:
            next_seg.reverse()
        ordered_route.extend(next_seg)
        print(f"Joined segment {best_idx} (dist: {best_dist:.5f})")
    else:
        print(f"Stopped joining (best dist: {best_dist:.5f})")
        break

print(f"Final route has {len(ordered_route)} points")
print(f"Start: {ordered_route[0]}")
print(f"End:   {ordered_route[-1]}")

# Save to a format easy for PHP
with open('d:/FYP/nepal_yatayat_full_polyline.php', 'w') as f:
    f.write("[\n")
    for p in ordered_route:
        f.write(f"            [{p[0]}, {p[1]}],\n")
    f.write("        ]")

print("Saved to d:/FYP/nepal_yatayat_full_polyline.php")
