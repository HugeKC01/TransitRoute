import csv
import os

routes = [
    {"route_id": "F_CPX_G", "agency_id": "CPX", "route_short_name": "Green", "route_long_name": "Chao Phraya Express Green Flag", "route_type": "4", "route_color": "008000", "route_text_color": "FFFFFF", "line_prefixes": "F_CPX"},
    {"route_id": "F_CPX_O", "agency_id": "CPX", "route_short_name": "Orange", "route_long_name": "Chao Phraya Express Orange Flag", "route_type": "4", "route_color": "FFA500", "route_text_color": "FFFFFF", "line_prefixes": "F_CPX"},
    {"route_id": "F_CPX_Y", "agency_id": "CPX", "route_short_name": "Yellow", "route_long_name": "Chao Phraya Express Yellow Flag", "route_type": "4", "route_color": "FFFF00", "route_text_color": "000000", "line_prefixes": "F_CPX"},
    {"route_id": "F_CPX_B", "agency_id": "CPX", "route_short_name": "Blue", "route_long_name": "Chao Phraya Tourist Blue Flag", "route_type": "4", "route_color": "0000FF", "route_text_color": "FFFFFF", "line_prefixes": "F_CPX"},
]

stops = {
    "F_N33": {"stop_name": "Pakkret", "stop_lat": "13.9126", "stop_lon": "100.4950"},
    "F_N30": {"stop_name": "Nonthaburi", "stop_lat": "13.8465", "stop_lon": "100.4912"},
    "F_N21": {"stop_name": "Kiak Kai", "stop_lat": "13.7978", "stop_lon": "100.5186"},
    "F_N13": {"stop_name": "Phra Arthit", "stop_lat": "13.7630", "stop_lon": "100.4938"},
    "F_N10": {"stop_name": "Wang Lang", "stop_lat": "13.7554", "stop_lon": "100.4862"},
    "F_N9": {"stop_name": "Tha Chang", "stop_lat": "13.7526", "stop_lon": "100.4875"},
    "F_N8": {"stop_name": "Tha Tien", "stop_lat": "13.7441", "stop_lon": "100.4896"},
    "F_N5": {"stop_name": "Ratchawong", "stop_lat": "13.7410", "stop_lon": "100.5050"},
    "F_N4": {"stop_name": "Marine Dept", "stop_lat": "13.7317", "stop_lon": "100.5117"},
    "F_N3": {"stop_name": "Si Phraya", "stop_lat": "13.7297", "stop_lon": "100.5133"},
    "F_N1": {"stop_name": "Oriental", "stop_lat": "13.7258", "stop_lon": "100.5147"},
    "F_CEN": {"stop_name": "Sathorn", "stop_lat": "13.7196", "stop_lon": "100.5135"},
    "F_S2": {"stop_name": "Asiatique", "stop_lat": "13.7042", "stop_lon": "100.5036"},
    "F_S3": {"stop_name": "Wat Rajsingkorn", "stop_lat": "13.7011", "stop_lon": "100.5020"},
}

# Example pier orderings
orange_stops = ["F_N30", "F_N21", "F_N13", "F_N10", "F_N9", "F_N8", "F_N5", "F_N4", "F_N3", "F_N1", "F_CEN", "F_S3"]
yellow_stops = ["F_N30", "F_N21", "F_N10", "F_N5", "F_N3", "F_CEN"]
green_stops =  ["F_N33", "F_N30", "F_N21", "F_N13", "F_N10", "F_N9", "F_N5", "F_N3", "F_N1", "F_CEN"]
blue_stops =   ["F_N13", "F_N10", "F_N9", "F_N8", "F_N5", "F_CEN", "F_S2"]

trips = []
stop_times = []

def add_trip(route_id, service_id, trip_id, stop_list, start_hour):
    trips.append({
        "route_id": route_id,
        "service_id": service_id,
        "trip_id": trip_id,
        "trip_headsign": stops[stop_list[-1]]["stop_name"],
        "direction_id": "0",
        "shape_id": "",
        "shape_color": ""
    })
    
    hour = start_hour
    mins = 0
    seq = 1
    for st in stop_list:
        t_str = f"{hour:02d}:{mins:02d}:00"
        stop_times.append({
            "trip_id": trip_id,
            "arrival_time": t_str,
            "departure_time": t_str,
            "stop_id": st,
            "stop_sequence": str(seq)
        })
        mins += 5
        if mins >= 60:
            hour += mins // 60
            mins = mins % 60
        seq += 1

add_trip("F_CPX_O", "WKD", "F_CPX_O_TRIP1", orange_stops, 6)
add_trip("F_CPX_O", "WKD", "F_CPX_O_TRIP2", orange_stops[::-1], 7)

add_trip("F_CPX_Y", "WKD", "F_CPX_Y_TRIP1", yellow_stops, 6)
add_trip("F_CPX_Y", "WKD", "F_CPX_Y_TRIP2", yellow_stops[::-1], 7)

add_trip("F_CPX_G", "WKD", "F_CPX_G_TRIP1", green_stops, 6)
add_trip("F_CPX_G", "WKD", "F_CPX_G_TRIP2", green_stops[::-1], 7)

add_trip("F_CPX_B", "WKD", "F_CPX_B_TRIP1", blue_stops, 9)
add_trip("F_CPX_B", "WKD", "F_CPX_B_TRIP2", blue_stops[::-1], 10)

def append_csv(path, new_rows, key_col, fields):
    existing = set()
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            fields = reader.fieldnames if reader.fieldnames else fields
            for row in reader:
                if key_col and key_col in row:
                    existing.add(row[key_col])
    else:
        with open(path, "w", encoding="utf-8") as f:
            f.write(",".join(fields) + "\n")
            
    with open(path, "a", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        if os.stat(path).st_size == 0 and fields:
            writer.writeheader()
        for r in new_rows:
            if key_col and r.get(key_col):
                if r[key_col] not in existing:
                    writer.writerow(r)
            else:
                writer.writerow(r)

append_csv("assets/gtfs_data/ferry_route.txt", routes, "route_id", ["route_id","agency_id","route_short_name","route_long_name","route_type","route_color","route_text_color","line_prefixes"])

new_stops = []
for sid, dat in stops.items():
    s = dict(dat)
    s["stop_id"] = sid
    s["stop_code"] = sid
    s["zone_id"] = ""
    s["stop_desc"] = ""
    new_stops.append(s)

append_csv("assets/gtfs_data/ferry_stop.txt", new_stops, "stop_id", ["stop_id","stop_name","stop_lat","stop_lon","stop_code","stop_desc","zone_id"])

append_csv("assets/gtfs_data/trips.txt", trips, "trip_id", ["route_id","service_id","trip_id","trip_headsign","direction_id","shape_id","shape_color"])

append_csv("assets/gtfs_data/ferry_stop_times.txt", stop_times, "trip_id", ["trip_id","arrival_time","departure_time","stop_id","stop_sequence"])

print("GTFS ferry files updated successfully.")