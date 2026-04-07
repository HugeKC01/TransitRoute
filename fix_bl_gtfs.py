import csv
from datetime import datetime, timedelta

def update_stop_times():
    with open('assets/gtfs_data/stop_times.txt', 'r') as f:
        reader = csv.reader(f)
        rows = list(reader)

    header = rows[0]
    new_rows = [header]

    t0 = None
    d0 = None

    t1 = None
    d1 = None

    for row in rows[1:]:
        trip_id, arr, dep, stop_id, seq = row
        if trip_id == 'BL_BL38_BL01':
            if t0 is None:
                t0 = datetime.strptime(arr, "%H:%M:%S")
                d0 = datetime.strptime("05:30:00", "%H:%M:%S")
            
            delta = datetime.strptime(arr, "%H:%M:%S") - t0
            new_time = (d0 + delta).strftime("%H:%M:%S")
            row = [trip_id, new_time, new_time, stop_id, seq]
        
        elif trip_id == 'BL_BL01_BL38':
            if t1 is None:
                t1 = datetime.strptime(arr, "%H:%M:%S")
                d1 = datetime.strptime("05:43:00", "%H:%M:%S")
                
            delta = datetime.strptime(arr, "%H:%M:%S") - t1
            new_time = (d1 + delta).strftime("%H:%M:%S")
            row = [trip_id, new_time, new_time, stop_id, seq]
            
        new_rows.append(row)

    with open('assets/gtfs_data/stop_times.txt', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(new_rows)
        
update_stop_times()
