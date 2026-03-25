import re
import json
import os

html_path = os.path.join(os.environ['TEMP'], 'route_page.html')
try:
    with open(html_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
except Exception:
    exit(1)

# Find var road_coords = [ ... ];
start_str = 'var road_coords ='
start_idx = content.find(start_str)
end_idx = content.find(';', start_idx)
coords_str = content[start_idx + len(start_str):end_idx].strip()

# Better segment extraction: look for [[[...],[...]],[[...],[...]]]
# This looks like GeoJSON-ish MultiLineString style
segments = []
# Match each inner list of points [[lat,lng],...]
segment_matches = re.finditer(r'\[\s*(\[.*?\])\s*\]', coords_str, re.DOTALL)

for i, m in enumerate(segment_matches):
    inner_str = m.group(1)
    points = re.findall(r'\[\s*(27\.\d+)\s*,\s*(85\.\d+)\s*\]', inner_str)
    if points:
        p_list = [[float(p[0]), float(p[1])] for p in points]
        segments.append(p_list)
        print(f"Segment {i}: {len(p_list)} points")
        print(f"  Start: {p_list[0]}")
        print(f"  End: {p_list[-1]}")

if segments:
    # Let's try to join them if they connect
    # Or just print their endpoints so I can decide the order
    # Most likely one starts where another ends
    pass
