import re
import json
import os

temp_dir = os.environ.get('TEMP')
html_path = os.path.join(temp_dir, 'route_page.html')

with open(html_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Aggressive match for [lat, lng] or [lat,lng]
matches = re.findall(r'\[\s*(\d+\.\d+),\s*(\d+\.\d+)\s*\]', content)

if matches:
    coords = [[float(lat), float(lng)] for lat, lng in matches]
    print(f"FOUND {len(coords)} COORDINATES")
    
    # Filter to only include coordinates in the Kathmandu/Lalitpur region to avoid noise
    # Lat: 27.6 to 27.8, Lng: 85.2 to 85.5
    filtered = [c for c in coords if 27.6 < c[0] < 27.8 and 85.2 < c[1] < 85.5]
    print(f"FILTERED TO {len(filtered)} RELEVANT COORDINATES")
    
    if filtered:
        # Sort by latitude descending (North to South)
        # However, the route might double back or be ordered differently in the source.
        # Let's see the first and last to check if it's the full route.
        print(f"FIRST: {filtered[0]}")
        print(f"LAST: {filtered[-1]}")
        
        output_path = os.path.join(temp_dir, 'extracted_polyline_full.json')
        with open(output_path, 'w') as f:
            json.dump(filtered, f)
        print(f"SAVED TO {output_path}")
    else:
        print("NO RELEVANT COORDINATES FOUND")
else:
    print("NO COORDINATES FOUND AT ALL")
