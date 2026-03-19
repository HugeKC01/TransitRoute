import 'dart:io';

void main() async {
  final lines = await File('assets/gtfs_data/stop_times.txt').readAsLines();
  final line = lines.firstWhere((l) => l.startsWith('PK_PK01_PK30') && l.contains('PK01'));
  final parts = line.split(',');
  final id = parts[3];
  print('id: ${id}, length: ${id.length}');
}