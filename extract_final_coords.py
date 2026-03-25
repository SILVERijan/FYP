import re
import json
import os

temp_dir = os.environ.get('TEMP')
html_path = os.path.join(temp_dir, 'route_page.html')

with open(html_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Look for var road_coords = [[[...]]]
match = re.search(r'var road_coords\s*=\s*((\[\[\[.*?\]\]\]|\[\[.*?\]\]))', content, re.DOTALL)

if match:
    coords_json = match.group(1)
    # The JSON might have extra commas or be slightly malformed for standard json.loads
    # But let's try standard first.
    try:
        data = json.loads(coords_json)
        # Flatten if it's nested [[[...]]]
        if isinstance(data[0][0], list):
            flat_coords = [point for segment in data for point in segment]
        else:
            flat_coords = data
            
        print(f"FOUND {len(flat_coords)} COORDINATES in road_coords")
        
        output_path = os.path.join(temp_dir, 'final_polyline.json')
        with open(output_path, 'w') as f:
            json.dump(flat_coords, f)
        print(f"SAVED TO {output_path}")
        
        if flat_coords:
            print(f"START: {flat_coords[0]}")
            print(f"END: {flat_coords[-1]}")
            
    except Exception as e:
        print(f"JSON LOAD FAILED: {e}")
        # Fallback to regex extraction from this block
        matches = re.findall(r'\[\s*(27\.\d+)\s*,\s*(85\.\d+)\s*\]', coords_json)
        coords = [[float(lat), float(lng)] for lat, lng in matches]
        print(f"REGEX FOUND {len(coords)} COORDINATES in road_coords block")
        
        output_path = os.path.join(temp_dir, 'final_polyline.json')
        with open(output_path, 'w') as f:
            json.dump(coords, f)
        print(f"SAVED TO {output_path}")
else:
    print("road_coords NOT FOUND")
