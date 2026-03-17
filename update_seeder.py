import codecs, re, json

# Read extracted coordinates
txt = codecs.open('polyline_raw.txt', 'r', 'utf-8-sig').read()
match = re.search(r'COORDS: (\[.+\])', txt, re.DOTALL)
coords = json.loads(match.group(1))
print(f'Loaded {len(coords)} coordinates')

# Build the new polyline PHP array
php_lines = []
for c in coords:
    php_lines.append(f'            [{c[0]}, {c[1]}]')
php_array = '[\n' + ',\n'.join(php_lines) + '\n        ]'

# Read the current seeder
with open('backend/database/seeders/DatabaseSeeder.php', 'r', encoding='utf-8') as f:
    seeder = f.read()

# Replace the old polyline array using a placeholder approach
start_marker = '$nyPolyline = ['
end_marker = '];'

start_idx = seeder.find(start_marker)
if start_idx == -1:
    print('ERROR: could not find $nyPolyline in seeder')
    exit(1)

# Find the matching closing ];
search_from = start_idx + len(start_marker)
depth = 1
i = search_from
while i < len(seeder) and depth > 0:
    if seeder[i] == '[':
        depth += 1
    elif seeder[i] == ']':
        depth -= 1
    i += 1
end_idx = i  # points just after the closing ]
# Now find the ; after it
semi_idx = seeder.find(';', end_idx)
end_idx = semi_idx + 1

new_seeder = seeder[:start_idx] + '$nyPolyline = ' + php_array + ';' + seeder[end_idx:]

with open('backend/database/seeders/DatabaseSeeder.php', 'w', encoding='utf-8') as f:
    f.write(new_seeder)

print('SUCCESS - seeder updated')

# Preview
idx = new_seeder.find('$nyPolyline')
print('Preview:')
print(new_seeder[idx:idx+300])
