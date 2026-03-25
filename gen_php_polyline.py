import re
import os

html_path = os.path.join(os.environ['TEMP'], 'route_page.html')
try:
    with open(html_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
except Exception:
    exit(1)

# Extract all [lat, lng] pairs from road_coords area
# We know they start after 'var road_coords ='
match = re.search(r'var road_coords\s*=\s*(.*?);', content, re.DOTALL)
if not match:
    exit(1)

coords_str = match.group(1)
matches = re.findall(r'\[\s*(27\.\d+)\s*,\s*(85\.\d+)\s*\]', coords_str)
coords = [[float(m[0]), float(m[1])] for m in matches]

print(f"Total: {len(coords)}")

# Generate PHP array
php_lines = []
for c in coords:
    php_lines.append(f"            [{c[0]}, {c[1]}]")

with open('d:\\FYP\\nepal_yatayat_full.txt', 'w') as f:
    f.write(",\n".join(php_lines))

print("Saved to d:\\FYP\\nepal_yatayat_full.txt")
