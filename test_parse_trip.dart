import 'dart:io';

void main() async {
  final text = await File('assets/gtfs_data/trips.txt').readAsString();
  final lines = text.split('\n').map((l) => l.trimRight()).where((l) => l.isNotEmpty).toList();
  final header = lines.first.split(',').map((s) => s.trim().toLowerCase()).toList();
  final idxRouteId = header.indexOf('route_id');
  final idxShapeId = header.indexOf('shape_id');
  print('idxRouteId: $idxRouteId, idxShapeId: $idxShapeId');
  
  for (int i = 1; i < 15; i++) {
     final row = lines[i].split(',');
     if(row.length > idxShapeId) {
       print('Trip \$i, route: \${row[idxRouteId]}, shape: \${row[idxShapeId]}');
     }
  }
}
