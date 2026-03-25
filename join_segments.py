import re
import os
import json

html_path = os.path.join(os.environ['TEMP'], 'route_page.html')
try:
    with open(html_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
except Exception:
    exit(1)

# Extract road_coords array string
match = re.search(r'var road_coords\s*=\s*(.*?);', content, re.DOTALL)
if not match:
    exit(1)
coords_str = match.group(1)

# Extract segments (inner arrays of points)
# We look for something like [[lat,lng],[lat,lng],...]
# The structure is usually [[[p1,p2...],[p1,p2...]]] (MultiLineString)
# So we look for [ [ [lat,lng] , [lat,lng] ] ]
segments = []
# Find each segment block: [[lat,lng], [lat,lng], ...]
# This regex is a bit tricky, let's just find [lat,lng] pairs and detect breaks
# A better way is to parse the JSON structure directly if possible, 
# but it might be malformed or non-standard.
# Let's try simple regex for the inner lists.
raw_segments = re.findall(r'\[\s*(?:\[\s*27\.\d+\s*,\s*85\.\d+\s*\]\s*,?\s*)+\]', coords_str)

for rs in raw_segments:
    points = re.findall(r'\[\s*(27\.\d+)\s*,\s*(85\.\d+)\s*\]', rs)
    if points:
        segments.append([[float(lat), float(lng)] for lat, lng in points])

print(f"Number of segments found: {len(segments)}")

if not segments:
    # If the above fails, just grab all points and sort by proximity? No, let's try a different regex.
    # Often road_coords = [[[lat,lng],[lat,lng]],[[lat,lng],[lat,lng]]]
    # Let's just find all points and then try to see where they jump.
    all_points = re.findall(r'\[\s*(27\.\d+)\s*,\s*(85\.\d+)\s*\]', coords_str)
    coords = [[float(lat), float(lng)] for lat, lng in all_points]
    
    # Simple segmenting: if distance > 0.01 degrees, it's a new segment
    curr_segment = []
    if coords:
        curr_segment.append(coords[0])
        for i in range(1, len(coords)):
            dist = ((coords[i][0]-coords[i-1][0])**2 + (coords[i][1]-coords[i-1][1])**2)**0.5
            if dist > 0.005: 
                segments.append(curr_segment)
                curr_segment = []
            curr_segment.append(coords[i])
        segments.append(curr_segment)

print(f"Refined Number of segments: {len(segments)}")

# Now join segments. Start with Gopi Krishna (highest latitude)
northmost_idx = -1
max_lat = -999
for i, seg in enumerate(segments):
    if seg[0][0] > max_lat:
        max_lat = seg[0][0]
        northmost_idx = i

ordered_points = segments.pop(northmost_idx)

while segments:
    last_pt = ordered_points[-1]
    best_match_idx = -1
    best_dist = 999
    reverse_seg = False
    
    for i, seg in enumerate(segments):
        # Dist to start of segment
        d_start = ((seg[0][0]-last_pt[0])**2 + (seg[0][1]-last_pt[1])**2)**0.5
        # Dist to end of segment
        d_end = ((seg[-1][0]-last_pt[0])**2 + (seg[-1][1]-last_pt[1])**2)**0.5
        
        if d_start < best_dist:
            best_dist = d_start
            best_match_idx = i
            reverse_seg = False
        if d_end < best_dist:
            best_dist = d_end
            best_match_idx = i
            reverse_seg = True
            
    if best_match_idx != -1:
        seg = segments.pop(best_match_idx)
        if reverse_seg:
            seg.reverse()
        ordered_points.extend(seg)
    else:
        break

print(f"Total ordered points: {len(ordered_points)}")
print(f"ORDERED START: {ordered_points[0]}")
print(f"ORDERED END: {ordered_points[-1]}")

# Save the ordered points
# Generate PHP lines
php_lines = [f"            [{p[0]}, {p[1]}]" for p in ordered_points]
with open('d:\\FYP\\nepal_yatayat_ordered.txt', 'w') as f:
    f.write(",\n".join(php_lines))

print("Saved to d:\\FYP\\nepal_yatayat_ordered.txt")
