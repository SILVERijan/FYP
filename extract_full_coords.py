import re
import json
import os

temp_dir = os.environ.get('TEMP')
html_path = os.path.join(temp_dir, 'route_page.html')

with open(html_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Aggressive search for [lat, lng]
# We look for something like [27.XXXX, 85.XXXX]
matches = re.findall(r'\[\s*(27\.\d+)\s*,\s*(85\.\d+)\s*\]', content)

if not matches:
    # Try another pattern without brackets just in case
    matches = re.findall(r'(27\.\d+)\s*,\s*(85\.\d+)', content)

coords = [[float(lat), float(lng)] for lat, lng in matches]

# Save to a file for analysis
output_path = os.path.join(temp_dir, 'full_extracted_coords.json')
with open(output_path, 'w') as f:
    json.dump(coords, f)

print(f"Extracted {len(coords)} coordinate pairs.")
if coords:
    print(f"Start: {coords[0]}")
    print(f"End: {coords[-1]}")
