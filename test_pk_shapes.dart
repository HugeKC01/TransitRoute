import 'dart:io';

void main() async {
  final shapes = File('assets/gtfs_data/shapes.txt').readAsLinesSync();
  final stops = <String, bool>{};
  for (final line in shapes) {
    if (line.startsWith('PK_MAIN')) {
       final p = line.split(',');
       if (p.length > 4) {
          final sName = p[4].trim();
          if (sName.isNotEmpty) stops[sName] = true;
       }
    }
  }
  print(stops.keys.toList());
}
