import re
import json
import os

html_path = os.path.join(os.environ['TEMP'], 'route_page.html')
try:
    with open(html_path, 'r', encoding='utf-8') as f:
        content = f.read()
except UnicodeDecodeError:
    with open(html_path, 'r', encoding='utf-16') as f:
        content = f.read()

# Find var road_coords = [ ... ];
start_str = 'var road_coords ='
start_idx = content.find(start_str)
if start_idx == -1:
    print("road_coords NOT FOUND")
    exit(1)

# Find the next semicolon after start_idx
end_idx = content.find(';', start_idx)
if end_idx == -1:
    print("Semicolon NOT FOUND")
    exit(1)

coords_str = content[start_idx + len(start_str):end_idx].strip()

# coords_str might have multiple arrays like [[[...]],[[...]]]
# Let's try to extract all [lat, lng] pairs regardless of nesting
matches = re.findall(r'\[\s*(27\.\d+)\s*,\s*(85\.\d+)\s*\]', coords_str)
all_coords = [[float(lat), float(lng)] for lat, lng in matches]

print(f"TOTAL COORDINATES EXTRACTED: {len(all_coords)}")
if all_coords:
    print(f"FIRST: {all_coords[0]}")
    print(f"LAST: {all_coords[-1]}")
    
    with open('d:\\FYP\\full_extracted_route.json', 'w') as f:
        json.dump(all_coords, f)
    print("SAVED TO d:\\FYP\\full_extracted_route.json")
