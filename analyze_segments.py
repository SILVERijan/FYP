import re
import os
import json

html_path = os.path.join(os.environ.get('TEMP', ''), 'route_page.html')
if not os.path.exists(html_path):
    print(f"Error: {html_path} not found")
    exit(1)

with open(html_path, 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# Extract road_coords variable
match = re.search(r'var road_coords\s*=\s*(.*?);', content, re.DOTALL)
if not match:
    print("Error: road_coords not found in HTML")
    exit(1)

coords_raw = match.group(1)

# road_coords is likely [[[lat,lng],...], [[lat,lng],...]]
# Let's find each segment (inner list of points)
# We look for [[[...]]] or [[...],[...]]
# A segment is [ [lat,lng], [lat,lng] ... ]

segments = []
# Find matches that are lists of coordinate pairs
# [[27.x, 85.x], [27.x, 85.x] ...]
segment_matches = re.findall(r'(\[(?:\[\s*27\.\d+\s*,\s*85\.\d+\s*\]\s*,?\s*)+\])', coords_raw)

for i, seg_str in enumerate(segment_matches):
    pts = re.findall(r'\[\s*(27\.\d+)\s*,\s*(85\.\d+)\s*\]', seg_str)
    coords = [[float(lat), float(lng)] for lat, lng in pts]
    segments.append(coords)
    print(f"Segment {i}: {len(coords)} points")
    print(f"  Start: {coords[0]}")
    print(f"  End:   {coords[-1]}")
    # Calculate min/max lat/lng
    lats = [c[0] for c in coords]
    lngs = [c[1] for c in coords]
    print(f"  Bounds: Lat({min(lats)} - {max(lats)}), Lng({min(lngs)} - {max(lngs)})")

# Combine them intelligently
# Most routes are ordered North-South or South-North
# Let's see if we can chain them
if segments:
    with open('d:/FYP/all_segments.json', 'w') as f:
        json.dump(segments, f)
    print("\nSaved segments to d:/FYP/all_segments.json")
