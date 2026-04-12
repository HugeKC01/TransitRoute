import csv

def main():
    trips_file = 'assets/gtfs_data/trips.txt'
    with open(trips_file, 'r', encoding='utf-8') as f:
        trips = list(csv.reader(f))
    
    new_trips = []
    # copy everything, but when we see BL,WKD,... add SAT and SUN versions
    for row in trips:
        new_trips.append(row)
        if len(row) > 2 and row[0] == 'BL' and row[1] == 'WKD':
            # Create SAT
            sat_row = list(row)
            sat_row[1] = 'SAT'
            sat_row[2] += '_SAT'
            new_trips.append(sat_row)
            
            # Create SUN
            sun_row = list(row)
            sun_row[1] = 'SUN'
            sun_row[2] += '_SUN'
            new_trips.append(sun_row)
            
    with open(trips_file, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(new_trips)


    stoptimes_file = 'assets/gtfs_data/stop_times.txt'
    with open(stoptimes_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    new_lines = []
    for line in lines:
        new_lines.append(line)
        if line.startswith('BL_BL01_BL38,') or line.startswith('BL_BL38_BL01,'):
            # Create SAT
            sat_line = line.replace('BL_BL01_BL38,', 'BL_BL01_BL38_SAT,').replace('BL_BL38_BL01,', 'BL_BL38_BL01_SAT,')
            new_lines.append(sat_line)
            # Create SUN
            sun_line = line.replace('BL_BL01_BL38,', 'BL_BL01_BL38_SUN,').replace('BL_BL38_BL01,', 'BL_BL38_BL01_SUN,')
            new_lines.append(sun_line)

    with open(stoptimes_file, 'w', encoding='utf-8') as f:
        for line in new_lines:
            f.write(line)


    freq_file = 'assets/gtfs_data/frequencies.txt'
    with open(freq_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Append SAT and SUN frequencies for BL
    new_freq = [
        # SAT
        'BL_BL01_BL38_SAT,06:00:00,16:00:00,480\n',
        'BL_BL38_BL01_SAT,06:00:00,16:00:00,480\n',
        'BL_BL01_BL38_SAT,16:00:00,19:00:00,385\n',
        'BL_BL38_BL01_SAT,16:00:00,19:00:00,385\n',
        'BL_BL01_BL38_SAT,19:00:00,24:00:00,480\n',
        'BL_BL38_BL01_SAT,19:00:00,24:00:00,480\n',
        # SUN
        'BL_BL01_BL38_SUN,06:00:00,24:00:00,480\n',
        'BL_BL38_BL01_SUN,06:00:00,24:00:00,480\n',
    ]

    with open(freq_file, 'a', encoding='utf-8') as f:
        for line in new_freq:
            f.write(line)

    print("Done")

if __name__ == '__main__':
    main()
