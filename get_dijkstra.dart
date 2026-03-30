import 'dart:io';

void main() {
  var lines = File('lib/services/direction_service.dart').readAsLinesSync();
  int start = lines.indexWhere((l) => l.contains('_dijkstraWeightedPath('));
  int end = lines.indexWhere((l) => l.contains('_distanceBetweenStops('));
  print(lines.sublist(start, end).join('\n'));
}
