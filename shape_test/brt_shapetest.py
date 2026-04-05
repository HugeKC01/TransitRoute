import pandas as pd
import numpy as np

def match_shapes_to_brt_trips():
    print("Loading custom stops...")
    # 1. Load Custom Stops to get lat/lon for each stop_id
    stops = pd.read_csv('bus_stop.txt', dtype=str, on_bad_lines='skip')
    
    stops['stop_lat'] = pd.to_numeric(stops['stop_lat'], errors='coerce')
    stops['stop_lon'] = pd.to_numeric(stops['stop_lon'], errors='coerce')
    stops = stops.dropna(subset=['stop_lat', 'stop_lon']).drop_duplicates(subset=['stop_id'])
    
    stop_dict = stops.set_index('stop_id')[['stop_lat', 'stop_lon']].to_dict('index')

    print("Loading source shapes...")
    # 2. Load Source Shapes and extract Start & End points for each shape
    shapes = pd.read_csv('shapes_source.txt', dtype=str)
    shapes['shape_pt_lat'] = shapes['shape_pt_lat'].astype(float)
    shapes['shape_pt_lon'] = shapes['shape_pt_lon'].astype(float)
    shapes['shape_pt_sequence'] = shapes['shape_pt_sequence'].astype(int)

    shapes = shapes.sort_values(['shape_id', 'shape_pt_sequence'])
    shape_starts = shapes.groupby('shape_id').first().reset_index()
    shape_ends = shapes.groupby('shape_id').last().reset_index()

    print("Loading bus stop times...")
    # 3. Read bus_stop_times.txt and find start/end stop for each trip
    stop_times = pd.read_csv('bus_stop_times.txt', dtype=str)
    stop_times['stop_sequence'] = stop_times['stop_sequence'].astype(int)
    
    stop_times = stop_times.sort_values(['trip_id', 'stop_sequence'])
    trip_starts = stop_times.groupby('trip_id').first().reset_index()
    trip_ends = stop_times.groupby('trip_id').last().reset_index()

    print("Matching trips to shapes spatially...")
    results = []
    
    for i, start_row in trip_starts.iterrows():
        trip_id = start_row['trip_id']
        start_stop = start_row['stop_id']
        
        # Get the corresponding end stop for this trip
        end_stop = trip_ends[trip_ends['trip_id'] == trip_id]['stop_id'].values[0]
        
        best_shape_id = ""
        
        if start_stop in stop_dict and end_stop in stop_dict:
            start_coord = (stop_dict[start_stop]['stop_lat'], stop_dict[start_stop]['stop_lon'])
            end_coord = (stop_dict[end_stop]['stop_lat'], stop_dict[end_stop]['stop_lon'])
            
            start_dists = np.sqrt((shape_starts['shape_pt_lat'] - start_coord[0])**2 + 
                                  (shape_starts['shape_pt_lon'] - start_coord[1])**2)
            
            end_dists = np.sqrt((shape_ends['shape_pt_lat'] - end_coord[0])**2 + 
                                (shape_ends['shape_pt_lon'] - end_coord[1])**2)
            
            total_dists = start_dists + end_dists
            best_idx = total_dists.idxmin()
            
            best_shape_id = shape_starts.loc[best_idx, 'shape_id']
            
        results.append({'trip_id': trip_id, 'shape_id': best_shape_id})

    print("Saving matched data...")
    # 4. Write the results to a new trips file
    output_df = pd.DataFrame(results)
    output_df.to_csv('brt_trips.txt', index=False)

    print("Done! Check 'brt_trips.txt'")

if __name__ == "__main__":
    match_shapes_to_brt_trips()
