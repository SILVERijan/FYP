import json, re, urllib.request, time

def load_json(js_file):
    txt = open(js_file, 'r', encoding='utf-8').read()
    start = txt.find("JSON.parse('") + 12
    if start < 12:
        return []
    end = txt.rfind("')")
    data = txt[start:end]
    data = data.replace("\\'", "'").replace("\\\\", "\\")
    return json.loads(data)

routes_raw = load_json('route_data.js')
stops_raw  = load_json('stops_data.js')

print(f"Loaded {len(routes_raw)} routes and {len(stops_raw)} stops.")

stop_map = { s['id']: s for s in stops_raw }

seeder_lines = [
    "<?php",
    "namespace Database\\Seeders;",
    "use Illuminate\\Database\\Seeder;",
    "use App\\Models\\Route;",
    "use App\\Models\\Stop;",
    "use App\\Models\\Vehicle;",
    "class GaadiGuideSeeder extends Seeder {",
    "    public function run(): void {",
]

print("Processing routes and hitting OSRM...")
max_routes = len(routes_raw)

for idx, r in enumerate(routes_raw):
    # Safe string conversion since sometimes operator or name could be a list or None
    raw_name = r.get('name')
    if isinstance(raw_name, list): raw_name = raw_name[0] if raw_name else 'Unknown'
    name = str(raw_name or 'Unknown Route').replace("'", "\\'")

    stops = r.get('stops', [])
    r_id = r.get('id')
    
    coords = []
    stop_objs = []
    for sid in stops:
        if sid in stop_map:
            st = stop_map[sid]
            coords.append(f"{st['lng']},{st['lat']}")
            stop_objs.append(st)
    
    polyline_arr = "[]"
    if len(coords) > 1:
        coord_str = ";".join(coords)
        if len(coords) < 100:
            osrm_url = f"https://router.project-osrm.org/route/v1/driving/{coord_str}?geometries=geojson&overview=full"
            try:
                # Add headers to avoid 403 on some free APIs
                req = urllib.request.Request(osrm_url, headers={'User-Agent': 'Mozilla/5.0'})
                resp = urllib.request.urlopen(req)
                resp_json = json.loads(resp.read())
                
                geo_coords = resp_json['routes'][0]['geometry']['coordinates']
                flipped_coords = [[lat, lng] for (lng, lat) in geo_coords]
                polyline_arr = json.dumps(flipped_coords)
            except Exception as e:
                print(f"[{idx+1}/{max_routes}] Error fetching OSRM for {name}: {e}")
                fallback = [[st['lat'], st['lng']] for st in stop_objs]
                polyline_arr = json.dumps(fallback)
        else:
            print(f"[{idx+1}/{max_routes}] Route {name} has too many stops. Using straight lines.")
            fallback = [[st['lat'], st['lng']] for st in stop_objs]
            polyline_arr = json.dumps(fallback)
            
        time.sleep(1) # Strict 1s wait for public API limit
    else:
        fallback = [[st['lat'], st['lng']] for st in stop_objs]
        polyline_arr = json.dumps(fallback)
        
    seeder_lines.append(f"        $r = Route::create(['name' => '{name}', 'type' => 'Bus', 'polyline' => json_encode({polyline_arr})]);")
    
    attach_arr = []
    for sort_idx, st in enumerate(stop_objs):
        sname = str(st.get('name', 'Stop')).replace("'", "\\'")
        slat = st['lat']
        slng = st['lng']
        seeder_lines.append(f"        $s = Stop::firstOrCreate(['name' => '{sname}', 'latitude' => {slat}, 'longitude' => {slng}]);")
        attach_arr.append(f"$s->id => ['sort_order' => {sort_idx+1}]")
    
    if attach_arr:
        seeder_lines.append(f"        $r->stops()->attach([{','.join(attach_arr)}]);")
    
    if stop_objs:
        vlat, vlng = stop_objs[0]['lat'], stop_objs[0]['lng']
        # Dummy vehicle mapped to each route
        seeder_lines.append(f"        Vehicle::create(['plate_number' => 'BA 4 KHA {idx*10+100}', 'current_lat' => {vlat}, 'current_lng' => {vlng}, 'status' => 'active', 'route_id' => $r->id]);")

seeder_lines.append("    }")
seeder_lines.append("}")

open('backend/database/seeders/GaadiGuideSeeder.php', 'w', encoding='utf-8').write("\n".join(seeder_lines))

print("GaadiGuideSeeder.php created successfully!")
