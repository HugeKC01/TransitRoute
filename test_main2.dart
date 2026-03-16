import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

void main() async {
  final tripToLine = <String, String>{};
  final tripContent = File('assets/gtfs_data/trips.txt').readAsStringSync();
  final lines = const LineSplitter().convert(tripContent);
  if (lines.length > 1) {
    final header = lines[0].split(',');
    final routeIdx = header.indexOf('route_id');
    final tripIdx = header.indexOf('trip_id');
    if (routeIdx != -1 && tripIdx != -1) {
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        final row = lines[i].split(',');
        if (row.length > math.max(routeIdx, tripIdx)) {
          final rId = row[routeIdx].trim();
          final tId = row[tripIdx].trim();
          tripToLine[tId] = rId;
        }
      }
    }
  }

  final stContent = File('assets/gtfs_data/ferry_stop_times.txt').readAsStringSync();
  final stLines = const LineSplitter().convert(stContent);
  final stHeader = stLines[0].split(',');
  final tripIdx2 = stHeader.indexOf('trip_id');
  final stopIdx = stHeader.indexOf('stop_id');
  
  final _stopToLinesMap = <String, Set<String>>{};

  for (int i = 1; i < stLines.length; i++) {
    if (stLines[i].trim().isEmpty) continue;
    final row = stLines[i].split(',');
    if (row.length > math.max(tripIdx2, stopIdx)) {
      final tId = row[tripIdx2].trim();
      final sId = row[stopIdx].trim();
      final lineName = tripToLine[tId];
      if (lineName != null) {
        _stopToLinesMap.putIfAbsent(sId, () => {}).add(lineName);
      } else if (tId.startsWith('F_')) {
        final routeId = tId.split('_TRIP')[0];
        _stopToLinesMap.putIfAbsent(sId, () => {}).add(routeId);
      }
    }
  }
  print('F_N18 routes: ' + _stopToLinesMap['F_N18'].toString());
  print('F_N30 routes: ' + _stopToLinesMap['F_N30'].toString());
  print('F_N1 routes: ' + _stopToLinesMap['F_N1'].toString());
}
