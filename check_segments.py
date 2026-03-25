import re
import os
import json

html_path = os.path.join(os.environ['TEMP'], 'route_page.html')
try:
    with open(html_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
except Exception:
    exit(1)

match = re.search(r'var road_coords\s*=\s*(.*?);', content, re.DOTALL)
coords_str = match.group(1)

# Find all segments: they are inside [ [pt, pt...], [pt, pt...] ]
# We look for matches of inner arrays of points
# A point is [lat, lng]
segments = []
# Find blocks that look like [[lat,lng], [lat,lng] ... ]
matches = re.finditer(r'\[\s*(?:\[\s*27\.\d+\s*,\s*85\.\d+\s*\]\s*,?\s*)+\]', coords_str)

for i, m in enumerate(matches):
    inner = m.group(0)
    points = re.findall(r'\[\s*(27\.\d+)\s*,\s*(85\.\d+)\s*\]', inner)
    p_floats = [[float(p[0]), float(p[1])] for p in points]
    segments.append(p_floats)
    lats = [p[0] for p in p_floats]
    print(f"Segment {i}: {len(p_floats)} points")
    print(f"  Range: {min(lats)} to {max(lats)}")
    print(f"  Start: {p_floats[0]}")
    print(f"  End: {p_floats[-1]}")
