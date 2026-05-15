import pandas as pd
import numpy as np
import re
from collections import defaultdict

def make_route_key(name):
    # Standardize route format for matching (e.g., "75 (4-13)" matches "4-13 (75)")
    name = str(name).replace('(', ' ').replace(')', ' ')
    parts = [p.strip() for p in re.split(r'[^\w-]', name) if p.strip()]
    return tuple(sorted(parts))

def match_shapes_to_custom_routes():
    print("Loading custom stops...")
    stops = pd.read_csv('bus_stop.txt', dtype=str, on_bad_lines='skip')
    
    stops['stop_lat'] = pd.to_numeric(stops['stop_lat'], errors='coerce')
    stops['stop_lon'] = pd.to_numeric(stops['stop_lon'], errors='coerce')
    
    stops = stops.dropna(subset=['stop_lat', 'stop_lon'])
    stops = stops.drop_duplicates(subset=['stop_id'])
    
    stop_dict = stops.set_index('stop_id')[['stop_lat', 'stop_lon']].to_dict('index')

    print("Loading source shapes...")
    shapes = pd.read_csv('shapes_source.txt', dtype=str)
    shapes['shape_pt_lat'] = shapes['shape_pt_lat'].astype(float)
    shapes['shape_pt_lon'] = shapes['shape_pt_lon'].astype(float)
    shapes['shape_pt_sequence'] = shapes['shape_pt_sequence'].astype(int)

    shapes = shapes.sort_values(['shape_id', 'shape_pt_sequence'])
    
    print("Extracting 3-point profiles for shapes (Start, Mid, End)...")
    # Extract Start, End, AND the exact Middle coordinate of the shape
    shape_starts = shapes.groupby('shape_id').first()
    shape_ends = shapes.groupby('shape_id').last()
    shape_mids = shapes.groupby('shape_id').apply(lambda x: x.iloc[len(x)//2])

    print("Building route-to-shape mappings...")
    routes = pd.read_csv('routes_source.txt', dtype=str)
    trips = pd.read_csv('trips_source.txt', dtype=str)
    
    route_to_shapes = defaultdict(set)
    for _, row in trips.iterrows():
        if pd.notna(row['shape_id']) and pd.notna(row['route_id']):
            route_to_shapes[row['route_id']].add(row['shape_id'])
            
    route_key_to_shapes = defaultdict(set)
    for _, row in routes.iterrows():
        if pd.notna(row['route_short_name']) and pd.notna(row['route_id']):
            key = make_route_key(row['route_short_name'])
            route_key_to_shapes[key].update(route_to_shapes[row['route_id']])

    print("Processing ragged bus routes and matching spatially...")
    output_rows = []
    
    with open('bus_route_stop.txt', 'r', encoding='utf-8') as f:
        lines = f.readlines()

    header = lines[0].strip().split(',')
    header.insert(5, 'shape_id')

    # Align all shape profiles into parallel series to make distance math fast
    starts_lat = shape_starts['shape_pt_lat']
    starts_lon = shape_starts['shape_pt_lon']
    ends_lat = shape_ends['shape_pt_lat']
    ends_lon = shape_ends['shape_pt_lon']
    mids_lat = shape_mids['shape_pt_lat']
    mids_lon = shape_mids['shape_pt_lon']

    for line in lines[1:]:
        parts = line.strip().split(',')
        if len(parts) < 6:
            continue
        
        metadata = parts[:5]
        stop_ids = [s for s in parts[5:] if s.strip() != '']
        
        if not stop_ids:
            continue
            
        start_stop = stop_ids[0]
        end_stop = stop_ids[-1]
        
        # Grab the stop perfectly in the middle of the custom route
        mid_stop = stop_ids[len(stop_ids) // 2]
        
        route_short_name = metadata[1]
        route_key = make_route_key(route_short_name)
        candidate_shapes = route_key_to_shapes.get(route_key, set())
        
        best_shape_id = ""
        
        # Ensure we have coordinates for all 3 anchor points
        if start_stop in stop_dict and end_stop in stop_dict and mid_stop in stop_dict:
            start_coord = (stop_dict[start_stop]['stop_lat'], stop_dict[start_stop]['stop_lon'])
            end_coord = (stop_dict[end_stop]['stop_lat'], stop_dict[end_stop]['stop_lon'])
            mid_coord = (stop_dict[mid_stop]['stop_lat'], stop_dict[mid_stop]['stop_lon'])
            
            # Calculate distance penalty against Start, End, AND Midpoint
            start_dists = np.sqrt((starts_lat - start_coord[0])**2 + (starts_lon - start_coord[1])**2)
            end_dists = np.sqrt((ends_lat - end_coord[0])**2 + (ends_lon - end_coord[1])**2)
            mid_dists = np.sqrt((mids_lat - mid_coord[0])**2 + (mids_lon - mid_coord[1])**2)
            
            # Combine distances. Expressway routes will heavily penalize the normal shape at the mid_dists check!
            total_dists = start_dists + end_dists + mid_dists
            
            if candidate_shapes:
                mask = total_dists.index.isin(candidate_shapes)
                if mask.any():
                    best_shape_id = total_dists[mask].idxmin()
                else:
                    best_shape_id = total_dists.idxmin()
            else:
                best_shape_id = total_dists.idxmin()
            
        new_parts = metadata + [str(best_shape_id)] + stop_ids
        output_rows.append(",".join(new_parts))

    print("Saving matched data...")
    with open('bus_route_stop_with_shapes.txt', 'w', encoding='utf-8') as f:
        f.write(",".join(header) + "\n")
        f.write("\n".join(output_rows) + "\n")

    print("Done! Check 'bus_route_stop_with_shapes.txt'")

if __name__ == "__main__":
    match_shapes_to_custom_routes()