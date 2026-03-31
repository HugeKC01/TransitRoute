import 'dart:io';

void main() async {
  final lines = await File('assets/gtfs_data/stops.txt').readAsLines();
  final line = lines.firstWhere((l) => l.startsWith('PK01'));
  final id = line.split(',')[0];
  print('id: ${id}, length: ${id.length}');
}