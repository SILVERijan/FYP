import re
import os

html_path = os.path.join(os.environ['TEMP'], 'route_page.html')
try:
    with open(html_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
except Exception:
    exit(1)

# Find all var name = [ ... ];
vars = re.finditer(r'var\s+([a-zA-Z0-9_]+)\s*=\s*(\[.*?\]);', content, re.DOTALL)

for m in vars:
    var_name = m.group(1)
    var_val = m.group(2)
    coords = re.findall(r'\[\s*(27\.\d+)\s*,\s*(85\.\d+)\s*\]', var_val)
    if coords:
        print(f"Variable: {var_name}")
        print(f"Count: {len(coords)}")
        c_floats = [[float(c[0]), float(c[1])] for c in coords]
        lats = [c[0] for c in c_floats]
        lngs = [c[1] for c in c_floats]
        print(f"Lat Range: {min(lats)} to {max(lats)}")
        print(f"Lng Range: {min(lngs)} to {max(lngs)}")
        print(f"First: {c_floats[0]}")
        print(f"Last: {c_floats[-1]}")
        print("-" * 20)
