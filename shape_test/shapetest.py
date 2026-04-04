import pandas as pd
import numpy as np

def match_shapes_to_custom_routes():
    print("Loading custom stops...")
    # 1. Load Custom Stops to get lat/lon for each stop_id
    stops = pd.read_csv('bus_stop.txt', dtype=str, on_bad_lines='skip')
    
    # Safely convert to float, turning text errors (like ' km.18') into NaN (Not a Number)
    stops['stop_lat'] = pd.to_numeric(stops['stop_lat'], errors='coerce')
    stops['stop_lon'] = pd.to_numeric(stops['stop_lon'], errors='coerce')
    
    # Drop any rows where the coordinates are missing or broken
    stops = stops.dropna(subset=['stop_lat', 'stop_lon'])
    
    # Drop any duplicate stop_ids (keeps the first occurrence)
    stops = stops.drop_duplicates(subset=['stop_id'])
    
    # Create a dictionary for fast coordinate lookup: { 'stop_id': (lat, lon) }
    stop_dict = stops.set_index('stop_id')[['stop_lat', 'stop_lon']].to_dict('index')

    print("Loading source shapes...")
    # 2. Load Source Shapes and extract Start & End points for each shape
    shapes = pd.read_csv('shapes_source.txt', dtype=str)
    shapes['shape_pt_lat'] = shapes['shape_pt_lat'].astype(float)
    shapes['shape_pt_lon'] = shapes['shape_pt_lon'].astype(float)
    shapes['shape_pt_sequence'] = shapes['shape_pt_sequence'].astype(int)

    # Sort to ensure the sequence is strictly ordered from start to finish
    shapes = shapes.sort_values(['shape_id', 'shape_pt_sequence'])
    
    # Extract the absolute first and last coordinate for every shape_id
    shape_starts = shapes.groupby('shape_id').first().reset_index()
    shape_ends = shapes.groupby('shape_id').last().reset_index()

    print("Processing ragged bus routes and matching spatially...")
    # 3. Read Custom Routes (Ragged CSV) and match
    output_rows = []
    
    with open('bus_route_stop.txt', 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Prepare the new header by injecting 'shape_id' before the sequence of stops
    header = lines[0].strip().split(',')
    header.insert(5, 'shape_id')

    for line in lines[1:]:
        parts = line.strip().split(',')
        if len(parts) < 6:
            continue
        
        # The first 5 columns are metadata, the rest are stop_ids
        metadata = parts[:5]
        stop_ids = [s for s in parts[5:] if s.strip() != '']
        
        if not stop_ids:
            continue
            
        start_stop = stop_ids[0]
        end_stop = stop_ids[-1]
        
        best_shape_id = ""
        
        # If we have coordinates for both terminals in our bus_stop.txt
        if start_stop in stop_dict and end_stop in stop_dict:
            start_coord = (stop_dict[start_stop]['stop_lat'], stop_dict[start_stop]['stop_lon'])
            end_coord = (stop_dict[end_stop]['stop_lat'], stop_dict[end_stop]['stop_lon'])
            
            # Calculate fast Euclidean distance penalty between custom terminals and source shape terminals
            start_dists = np.sqrt((shape_starts['shape_pt_lat'] - start_coord[0])**2 + 
                                  (shape_starts['shape_pt_lon'] - start_coord[1])**2)
            
            end_dists = np.sqrt((shape_ends['shape_pt_lat'] - end_coord[0])**2 + 
                                (shape_ends['shape_pt_lon'] - end_coord[1])**2)
            
            # Combine distances to find the shape that best aligns with BOTH terminals
            total_dists = start_dists + end_dists
            best_idx = total_dists.idxmin()
            
            best_shape_id = shape_starts.loc[best_idx, 'shape_id']
            
        # Inject the matched shape_id as the 6th column and reconstruct the ragged row
        new_parts = metadata + [str(best_shape_id)] + stop_ids
        output_rows.append(",".join(new_parts))

    print("Saving matched data...")
    # 4. Write the results to a new file
    with open('bus_route_stop_with_shapes.txt', 'w', encoding='utf-8') as f:
        f.write(",".join(header) + "\n")
        f.write("\n".join(output_rows) + "\n")

    print("Done! Check 'bus_route_stop_with_shapes.txt'")

if __name__ == "__main__":
    match_shapes_to_custom_routes()