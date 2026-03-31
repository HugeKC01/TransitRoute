import 'dart:io';

class ShapeSegment {
  final String shapeId;
  final List<String?> pointNames;
  const ShapeSegment(this.shapeId, this.pointNames);
}

void main() async {
  final text = await File('assets/gtfs_data/shapes.txt').readAsString();
  final lines = text.split('\n').map((l) => l.trimRight()).where((l) => l.isNotEmpty).toList();
  final header = lines.first.split(',').map((s) => s.trim().toLowerCase()).toList();
  
  final idxShapeId = header.indexOf('shape_id');
  final idxName = 4;
  
  final byShape = <String, List<String?>>{};
  for (int i = 1; i < lines.length; i++) {
    final row = lines[i].split(',');
    if (row.length <= idxName) continue;
    final id = row[idxShapeId].trim();
    String? name = row[idxName].trim();
    if(name.isEmpty) name = null;
    byShape.putIfAbsent(id, () => []).add(name);
  }
  
  final shapeSegments = byShape.entries.map((e) => ShapeSegment(e.key, e.value)).toList();
  
  final stopA = 'PK01';
  final stopB = 'PK02';
  bool foundShape = false;
  
  for (final shape in shapeSegments) {
     final aLocs = <int>[];
     final bLocs = <int>[];
     for (int k = 0; k < shape.pointNames.length; k++) {
         if (shape.pointNames[k] == stopA) aLocs.add(k);
         if (shape.pointNames[k] == stopB) bLocs.add(k);
     }
     if (aLocs.isNotEmpty && bLocs.isNotEmpty) {
       foundShape = true;
       print('Found shape \$stopA -> \$stopB in \${shape.shapeId} (a:\$aLocs, b:\$bLocs)');
       break;
     }
  }
  if (!foundShape) {
    print('Shape not found between \$stopA and \$stopB!!!');
  }
}
