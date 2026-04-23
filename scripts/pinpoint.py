import json
import csv
import os

def get_all_coordinates(geom):
    """
    ดึงพิกัดทั้งหมดออกจาก Geometry ทุกประเภท (Recursive)
    เพื่อนำมาคำนวณหาจุดกึ่งกลาง (Centroid)
    """
    coords = []
    if not geom:
        return coords
        
    g_type = geom.get('type')
    
    if g_type == 'Point':
        coords.append(geom['coordinates'])
    elif g_type in ['LineString', 'MultiPoint']:
        coords.extend(geom['coordinates'])
    elif g_type in ['Polygon', 'MultiLineString']:
        # วนลูปดึงพิกัดจากทุกเส้นขอบ
        for part in geom['coordinates']:
            coords.extend(part)
    elif g_type == 'MultiPolygon':
        # วนลูปลึกสำหรับ MultiPolygon
        for poly in geom['coordinates']:
            for ring in poly:
                coords.extend(ring)
    elif g_type == 'GeometryCollection':
        for g in geom.get('geometries', []):
            coords.extend(get_all_coordinates(g))
            
    return coords

def main():
    input_file = 'export.geojson'
    output_file = 'pinpoint.txt'

    if not os.path.exists(input_file):
        print(f"Error: ไม่พบไฟล์ '{input_file}'")
        return

    print(f"--- เริ่มต้นประมวลผลไฟล์: {input_file} ---")

    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # กำหนด Header ตามมาตรฐาน GTFS ที่คุณต้องการ
    fieldnames = ['stop_id', 'stop_name', 'stop_name_en', 'stop_lat', 'stop_lon', 'stop_desc']

    stats = {"added": 0, "skipped_no_name": 0}

    with open(output_file, 'w', newline='', encoding='utf-8-sig') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

        for feature in data.get('features', []):
            props = feature.get('properties', {})
            geom = feature.get('geometry', {})
            
            # 1. ดึงชื่อจาก Tag ต่างๆ (ลำดับความสำคัญ: name:th > name > official_name:th)
            name_th = props.get('name:th') or props.get('name') or props.get('official_name:th') or ""
            name_en = props.get('name:en') or props.get('official_name:en') or ""

            # 2. เงื่อนไข: ถ้าไม่มีชื่อเลยทั้งคู่ ให้ข้าม (Remove the pinpoint that doesn't have name)
            if not name_th and not name_en:
                stats["skipped_no_name"] += 1
                continue

            # 3. การจัดการชื่อ (Phrase the available name to both columns if one is missing)
            if name_th and not name_en:
                name_en = name_th
            elif name_en and not name_th:
                name_th = name_en

            # 4. คำนวณพิกัด (Handle Polygons/Relations Centroid)
            all_pts = get_all_coordinates(geom)
            
            if all_pts:
                # หาค่าเฉลี่ย Lat และ Lon
                avg_lat = sum(p[1] for p in all_pts) / len(all_pts)
                avg_lon = sum(p[0] for p in all_pts) / len(all_pts)
                
                # ดึงประเภทสถานที่มาใส่ในคำอธิบาย
                stop_desc = props.get('amenity') or props.get('shop') or \
                            props.get('office') or props.get('leisure') or \
                            props.get('tourism') or "landmark"
                
                writer.writerow({
                    'stop_id': props.get('@id'),
                    'stop_name': name_th,
                    'stop_name_en': name_en,
                    'stop_lat': f"{avg_lat:.6f}",
                    'stop_lon': f"{avg_lon:.6f}",
                    'stop_desc': stop_desc
                })
                stats["added"] += 1

    print(f"--- สรุปผลการทำงาน ---")
    print(f"✅ เพิ่มข้อมูลลง pinpoint.txt: {stats['added']} รายการ")
    print(f"❌ ข้ามเนื่องจากไม่มีชื่อ: {stats['skipped_no_name']} รายการ")
    print(f"บันทึกไฟล์เรียบร้อยแล้วที่: {output_file}")

if __name__ == "__main__":
    main()