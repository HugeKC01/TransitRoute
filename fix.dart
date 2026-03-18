import 'dart:io';

void main() {
  final f = File('assets/gtfs_data/bus_stop_times.txt');
  var lines = f.readAsLinesSync();
  lines = lines.where((l) => !l.startsWith('BRT_')).toList();
  f.writeAsStringSync(lines.join('\\n') + '\\n');
}
