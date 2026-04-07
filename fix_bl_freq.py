import csv

new_freqs = []
with open('assets/gtfs_data/frequencies.txt', 'r') as f:
    reader = csv.reader(f)
    header = next(reader)
    new_freqs.append(header)
    for row in reader:
        if not row[0].startswith('BL_'):
            new_freqs.append(row)

bl_additions = [
    ['BL_BL01_BL38', '05:30:00', '07:00:00', '300'],
    ['BL_BL38_BL01', '05:30:00', '07:00:00', '300'],
    ['BL_BL01_BL38', '07:00:00', '09:00:00', '209'],
    ['BL_BL38_BL01', '07:00:00', '09:00:00', '209'],
    ['BL_BL01_BL38', '09:00:00', '16:30:00', '400'],
    ['BL_BL38_BL01', '09:00:00', '16:30:00', '400'],
    ['BL_BL01_BL38', '16:30:00', '19:30:00', '230'],
    ['BL_BL38_BL01', '16:30:00', '19:30:00', '230'],
    ['BL_BL01_BL38', '19:30:00', '21:00:00', '320'],
    ['BL_BL38_BL01', '19:30:00', '21:00:00', '320'],
    ['BL_BL01_BL38', '21:00:00', '24:00:00', '435'],
    ['BL_BL38_BL01', '21:00:00', '24:00:00', '435']
]

new_freqs.extend(bl_additions)

with open('assets/gtfs_data/frequencies.txt', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerows(new_freqs)
