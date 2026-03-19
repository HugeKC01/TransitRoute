import 'dart:io';

void main() async {
  final file = File('assets/gtfs_data/shapes.txt');
  final lines = await file.readAsLines();
  final header = lines.first.split(',');
  final idxName = header.indexWhere((h) => h.trim() == 'shape_pt_name' || h.trim() == 'shape_name' || h.trim() == 'shape_pt_label');
  print('idxName: \$idxName');
}
