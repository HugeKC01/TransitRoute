import json
import csv
import os

def get_all_coordinates(geom):
    """
    ดึงพิกัดทั้งหมดออกจาก Geometry ทุกประเภท (Recursive)
    เพื่อนำมาคำนวณหาจุดกึ่งกลาง (Centroid)
    """
    coords = []
    g_type = geom.get('type')
    
    if g_type == 'Point':
        coords.append(geom['coordinates'])
    elif g_type in ['LineString', 'MultiPoint']:
        coords.extend(geom['coordinates'])
    elif g_type in ['Polygon', 'MultiLineString']:
        # วนลูปดึงพิกัดจากทุก Ring/Line
        for part in geom['coordinates']:
            coords.extend(part)
    elif g_type == 'MultiPolygon':
        # วนลูปลึกขึ้นสำหรับ MultiPolygon
        for poly in geom['coordinates']:
            for ring in poly:
                coords.extend(ring)
    elif g_type == 'GeometryCollection':
        for g in geom.get('geometries', []):
            coords.extend(get_all_coordinates(g))
            
    return coords

def process_geojson_to_gtfs(input_filename, output_filename):
    if not os.path.exists(input_filename):
        print(f"Error: ไม่พบไฟล์ '{input_filename}' ในโฟลเดอร์นี้")
        return

    print(f"--- เริ่มต้นการแปลงไฟล์ '{input_filename}' ---")

    with open(input_filename, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # กำหนดคอลัมน์มาตรฐาน GTFS พร้อมคอลัมน์ภาษาอังกฤษแยก
    fieldnames = ['stop_id', 'stop_name', 'stop_name_en', 'stop_lat', 'stop_lon', 'stop_desc']

    count = 0
    with open(output_filename, 'w', newline='', encoding='utf-8-sig') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

        for feature in data.get('features', []):
            props = feature.get('properties', {})
            geom = feature.get('geometry', {})
            
            if not geom:
                continue

            # 1. ระบุประเภทสถานที่เพื่อใช้เป็น Fallback Name (กรณีไม่มีชื่อระบุไว้)
            raw_type = props.get('leisure') or props.get('amenity') or \
                       props.get('shop') or props.get('office') or \
                       props.get('tourism') or props.get('government') or "Landmark"
            
            # ทำความสะอาดชื่อประเภท (เช่น social_services -> Social Services)
            clean_type = raw_type.replace('_', ' ').title()

            # 2. ดึงชื่อจาก Tag ต่างๆ (จัดการ Priority)
            name_th = props.get('name:th') or props.get('name') or props.get('official_name:th') or ""
            name_en = props.get('name:en') or props.get('official_name:en') or ""

            # 3. จัดการเรื่องภาษา (Cross-Language Fallback)
            # ถ้ามีภาษาหนึ่ง แต่ไม่มีอีกภาษา ให้ใช้ชื่อภาษาที่มีแทนทั้งคู่
            if name_en and not name_th:
                name_th = name_en
            elif name_th and not name_en:
                name_en = name_th
            
            # 4. กรณีไม่มีชื่อเลยทั้ง TH และ EN (แก้ปัญหา Unknown)
            # จะใช้รูปแบบ: "ประเภท (ID)" เช่น "Park (way/12345)"
            if not name_th and not name_en:
                fallback_label = f"{clean_type} ({props.get('@id')})"
                name_th = fallback_label
                name_en = fallback_label

            # 5. คำนวณหาพิกัด Lat/Lon จากทุกจุดใน Geometry
            all_pts = get_all_coordinates(geom)
            
            if all_pts:
                # คำนวณค่าเฉลี่ยของพิกัดทั้งหมด
                avg_lat = sum(p[1] for p in all_pts) / len(all_pts)
                avg_lon = sum(p[0] for p in all_pts) / len(all_pts)
                
                # เขียนข้อมูลลงไฟล์ CSV
                writer.writerow({
                    'stop_id': props.get('@id'),
                    'stop_name': name_th,
                    'stop_name_en': name_en,
                    'stop_lat': f"{avg_lat:.6f}",
                    'stop_lon': f"{avg_lon:.6f}",
                    'stop_desc': raw_type
                })
                count += 1

    print(f"--- สำเร็จ! แปลงข้อมูลทั้งหมด {count} สถานที่ ลงในไฟล์ '{output_filename}' ---")

if __name__ == "__main__":
    # คุณสามารถเปลี่ยนชื่อไฟล์ตรงนี้ได้
    INPUT = 'export.geojson'
    OUTPUT = 'pinpoint.txt'
    
    process_geojson_to_gtfs(INPUT, OUTPUT)