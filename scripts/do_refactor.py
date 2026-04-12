import re

with open('lib/pages/transport_lines_details_page.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# We need to replace `List<String> _parseCsvLine(String line) {...` and `Future<void> _loadRouteStops() async {...}`
# But wait, we can just replace everything from `// Basic CSV line parser` down to `Color _colorFromHexOr`

begin_str = """  // Basic CSV line parser supporting quoted fields and commas within quotes
  List<String> _parseCsvLine(String line) {"""
end_str = """  Color _colorFromHexOr(String? hex, Color fallback) {"""

new_block = """  Future<void> _loadRouteStops() async {
    try {
      final routeId = widget.route.routeId;
      String tripsFile = 'assets/gtfs_data/trips.txt';
      String stopTimesFile = 'assets/gtfs_data/stop_times.txt';
      String stopsFile = 'assets/gtfs_data/stops.txt';
      String shapesFile = 'assets/gtfs_data/shapes.txt';
      String? tIdIdxName = 'trip_id';
      String? rIdIdxName = 'route_id';

      bool isBus =
          widget.route.type.toLowerCase() == 'bus' || widget.route.type == '3';
      final isBrt = routeId == 'BRT';
      if (isBrt) {
        isBus = false;
        tripsFile = 'assets/gtfs_data/brt_trips.txt';
        stopTimesFile = 'assets/gtfs_data/bus_stop_times.txt';
        stopsFile = 'assets/gtfs_data/bus_stop.txt';
        shapesFile = 'assets/gtfs_data/shapes.txt';
      } else if (isBus) {
        tripsFile = 'assets/gtfs_data/bus_route_stop.txt';
        stopTimesFile = '';
        stopsFile = 'assets/gtfs_data/bus_stop.txt';
        shapesFile = 'assets/gtfs_data/shapes_source.txt';
      } else if (widget.route.type.toLowerCase() == 'ferry' ||
          widget.route.type == '4') {
        tripsFile = 'assets/gtfs_data/ferry_trips.txt';
        stopTimesFile = 'assets/gtfs_data/ferry_stop_times.txt';
        stopsFile = 'assets/gtfs_data/ferry_stop.txt';
        shapesFile = '';
      }

      String tripsContent = await gtfsSyncService.getGtfsFile(tripsFile);
      String stopTimesContent = '';
      if (stopTimesFile.isNotEmpty) {
        stopTimesContent = await gtfsSyncService.getGtfsFile(stopTimesFile);
      }
      String stopsContent = await gtfsSyncService.getGtfsFile(stopsFile);
      String shapesContent = '';
      if (shapesFile.isNotEmpty) {
        try {
          shapesContent = await gtfsSyncService.getGtfsFile(shapesFile);
        } catch (_) {}
      }

      final result = await compute(_parseRouteDataInBackground, {
        'routeId': routeId,
        'isBus': isBus,
        'isBrt': isBrt,
        'tIdIdxName': tIdIdxName,
        'rIdIdxName': rIdIdxName,
        'tripsContent': tripsContent,
        'stopTimesContent': stopTimesContent,
        'stopsContent': stopsContent,
        'shapesContent': shapesContent,
      });

      if (mounted) {
        setState(() {
          _routeStops = result['routeStops'] as List<gtfs.Stop>;
          _lineShape = result['lineShape'] as List<LatLng>;
          _firstStationNames = result['firstStationNames'] as List<String>;
          _lastStationNames = result['lastStationNames'] as List<String>;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stops for route: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

"""

bottom_block = """
// ---------------- Background Isolate Logic ----------------

List<String> _parseCsvLineStatic(String line) {
  final result = <String>[];
  final buffer = StringBuffer();
  bool inQuotes = false;
  for (int i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      result.add(buffer.toString().trim());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  result.add(buffer.toString().trim());
  return result;
}

Map<String, dynamic> _parseRouteDataInBackground(Map<String, dynamic> params) {
  final routeId = params['routeId'] as String;
  final isBus = params['isBus'] as bool;
  final isBrt = params['isBrt'] as bool;
  final tIdIdxName = params['tIdIdxName'] as String?;
  final rIdIdxName = params['rIdIdxName'] as String?;
  final tripsContent = params['tripsContent'] as String;
  final stopTimesContent = params['stopTimesContent'] as String;
  final stopsContent = params['stopsContent'] as String;
  final shapeContent = params['shapesContent'] as String;

  final targetTripIds = <String>{};
  String? targetShapeId;
  final orderedStopIds = <String>[];
  final allFirstStopIds = <String>{};
  final allLastStopIds = <String>{};

  if (isBus) {
    final busLines = const LineSplitter().convert(tripsContent);
    if (busLines.length > 1) {
      String? bestShape;
      List<String> bestStops = [];
      for (int i = 1; i < busLines.length; i++) {
        final row = _parseCsvLineStatic(busLines[i]);
        if (row.length > 5) {
          final rShortName = row[1].trim();
          if (rShortName.split(' ')[0].trim() == routeId) {
            final stops = <String>[];
            for (int j = 6; j < row.length; j++) {
              final sid = row[j].trim();
              if (sid.isNotEmpty) stops.add(sid);
            }
            if (stops.isNotEmpty) {
              allFirstStopIds.add(stops.first);
              allLastStopIds.add(stops.last);
            }
            if (stops.length > bestStops.length) {
              bestStops = stops;
              bestShape = row[5].trim();
            }
          }
        }
      }
      if (bestShape != null) targetShapeId = bestShape;
      orderedStopIds.addAll(bestStops);
    }
  } else {
    final tripsLines = const LineSplitter().convert(tripsContent);
    if (tripsLines.length > 1) {
      final headerRow = _parseCsvLineStatic(tripsLines.first);
      final routeIdIdx = headerRow.indexOf(rIdIdxName!);
      final tripIdIdx = headerRow.indexOf(tIdIdxName!);
      final shapeIdIdx = headerRow.indexOf('shape_id');
      bool brtFallback = tripIdIdx < 0 && routeId == 'BRT';

      for (int i = brtFallback ? 0 : 1; i < tripsLines.length; i++) {
        final row = _parseCsvLineStatic(tripsLines[i]);
        if (row.isEmpty) continue;
        if (brtFallback) {
          if (row[0].contains('BRT')) {
            targetTripIds.add(row[0]);
            if (row.length > 1 && row[1].isNotEmpty && row[0] == 'BRT_0') {
              targetShapeId = row[1].trim();
            }
          }
        } else if (routeIdIdx >= 0 &&
            tripIdIdx >= 0 &&
            row.length > routeIdIdx &&
            row[routeIdIdx] == routeId) {
          targetTripIds.add(row[tripIdIdx]);
          if (shapeIdIdx >= 0 &&
              row.length > shapeIdIdx &&
              row[shapeIdIdx].isNotEmpty) {
            targetShapeId = row[shapeIdIdx];
          }
        } else if (routeIdIdx < 0 &&
            tripIdIdx >= 0 &&
            row.length > tripIdIdx) {
          if (row[tripIdIdx].contains(routeId)) {
            targetTripIds.add(row[tripIdIdx]);
            if (shapeIdIdx >= 0 &&
                row.length > shapeIdIdx &&
                row[shapeIdIdx].isNotEmpty) {
              targetShapeId = row[shapeIdIdx];
            }
          }
        }
      }
    }

    if (targetTripIds.isNotEmpty && stopTimesContent.isNotEmpty) {
      final stopTimesLines = const LineSplitter().convert(stopTimesContent);
      if (stopTimesLines.isNotEmpty) {
        final headerRow = _parseCsvLineStatic(stopTimesLines.first);
        int tripIdIdx = headerRow.indexOf('trip_id');
        if (tripIdIdx < 0) tripIdIdx = 0;
        int stopIdIdx = headerRow.indexOf('stop_id');
        if (stopIdIdx < 0) stopIdIdx = 3;
        int seqIdx = headerRow.indexOf('stop_sequence');
        if (seqIdx < 0) seqIdx = 4;

        bool stFallback = !headerRow.contains('trip_id');

        final tripStopsMap = <String, List<Map<String, dynamic>>>{};
        for (int i = stFallback ? 0 : 1; i < stopTimesLines.length; i++) {
          final row = _parseCsvLineStatic(stopTimesLines[i]);
          if (row.isEmpty) continue;
          if (tripIdIdx >= 0 &&
              stopIdIdx >= 0 &&
              seqIdx >= 0 &&
              row.length > tripIdIdx &&
              row.length > stopIdIdx &&
              row.length > seqIdx &&
              targetTripIds.contains(row[tripIdIdx])) {
            tripStopsMap.putIfAbsent(row[tripIdIdx], () => []).add({
              'stop_id': row[stopIdIdx],
              'sequence': int.tryParse(row[seqIdx]) ?? 0,
            });
          }
        }
        if (tripStopsMap.isNotEmpty) {
          final sortedTrips = tripStopsMap.values.toList()
            ..sort((a, b) => b.length.compareTo(a.length));
          final longestTrip = sortedTrips.first;
          longestTrip.sort(
            (a, b) =>
                (a['sequence'] as int).compareTo(b['sequence'] as int),
          );
          final referenceFirst = longestTrip.first['stop_id'] as String;
          final referenceLast = longestTrip.last['stop_id'] as String;

          for (final trip in tripStopsMap.values) {
            if (trip.isNotEmpty) {
              trip.sort(
                (a, b) =>
                    (a['sequence'] as int).compareTo(b['sequence'] as int),
              );
              final thisFirst = trip.first['stop_id'] as String;
              final thisLast = trip.last['stop_id'] as String;
              if (thisLast == referenceLast ||
                  thisFirst == referenceFirst) {
                allFirstStopIds.add(thisFirst);
                allLastStopIds.add(thisLast);
              }
            }
          }
          for (final st in longestTrip) {
            orderedStopIds.add(st['stop_id'] as String);
          }
        }
      }
    }
  }

  final stopsLines = const LineSplitter().convert(stopsContent);
  final Map<String, gtfs.Stop> stopsMap = {};
  final resolvedFirstStops = <String, String>{};
  final resolvedLastStops = <String, String>{};

  if (stopsLines.length > 1) {
    final headerRow = _parseCsvLineStatic(stopsLines.first);
    int idIdx = headerRow.indexOf('stop_id');
    if (idIdx < 0) idIdx = 0;
    int nameIdx = headerRow.indexOf('stop_name');
    if (nameIdx < 0) nameIdx = 1;
    int thaiIdx = headerRow.indexOf('stop_name_th');
    int latIdx = headerRow.indexOf('stop_lat');
    if (latIdx < 0) latIdx = 2;
    int lonIdx = headerRow.indexOf('stop_lon');
    if (lonIdx < 0) lonIdx = 3;
    final codeIdx = headerRow.indexOf('stop_code');
    final descIdx = headerRow.indexOf('stop_desc');
    final zoneIdx = headerRow.indexOf('zone_id');

    for (int i = 1; i < stopsLines.length; i++) {
      final row = _parseCsvLineStatic(stopsLines[i]);
      if (row.isEmpty || row.length <= idIdx) continue;
      final stopId = row[idIdx];

      String valueAt(int idx) =>
          (idx >= 0 && idx < row.length) ? row[idx].trim() : '';
      final thaiName = valueAt(thaiIdx);
      final pName = thaiName.isNotEmpty ? thaiName : valueAt(nameIdx);

      if (allFirstStopIds.contains(stopId)) {
        resolvedFirstStops[stopId] = pName;
      }
      if (allLastStopIds.contains(stopId)) {
        resolvedLastStops[stopId] = pName;
      }

      if (orderedStopIds.contains(stopId)) {
        stopsMap[stopId] = gtfs.Stop(
          stopId: stopId,
          name: valueAt(nameIdx),
          thaiName: thaiName.isNotEmpty ? thaiName : null,
          lat: double.tryParse(valueAt(latIdx)) ?? 0.0,
          lon: double.tryParse(valueAt(lonIdx)) ?? 0.0,
          code: valueAt(codeIdx).isEmpty ? null : valueAt(codeIdx),
          desc: valueAt(descIdx).isEmpty ? null : valueAt(descIdx),
          zoneId: valueAt(zoneIdx).isEmpty ? null : valueAt(zoneIdx),
        );
      }
    }
  }

  final resultStops = <gtfs.Stop>[];
  final seenStops = <String>{};
  for (final id in orderedStopIds) {
    if (stopsMap.containsKey(id) && !seenStops.contains(id)) {
      resultStops.add(stopsMap[id]!);
      seenStops.add(id);
    }
  }

  final linePoints = <LatLng>[];
  if (targetShapeId != null &&
      targetShapeId.isNotEmpty &&
      shapeContent.isNotEmpty) {
    try {
      final shapeLines = const LineSplitter().convert(shapeContent);
      if (shapeLines.length > 1) {
        final sHead = _parseCsvLineStatic(shapeLines.first);
        final sidIdx = sHead.indexOf('shape_id');
        final latIdx = sHead.indexOf('shape_pt_lat');
        final lonIdx = sHead.indexOf('shape_pt_lon');
        final seqIdx = sHead.indexOf('shape_pt_sequence');

        final pts = <Map<String, dynamic>>[];
        for (int i = 1; i < shapeLines.length; i++) {
          final row = _parseCsvLineStatic(shapeLines[i]);
          if (row.length > sidIdx && row[sidIdx] == targetShapeId) {
            pts.add({
              'lat': double.tryParse(row[latIdx]) ?? 0.0,
              'lon': double.tryParse(row[lonIdx]) ?? 0.0,
              'seq': int.tryParse(row[seqIdx]) ?? 0,
            });
          }
        }
        pts.sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
        for (final pt in pts) {
          linePoints.add(LatLng(pt['lat'], pt['lon']));
        }
      }
    } catch (_) {}
  }

  if (linePoints.isEmpty && resultStops.isNotEmpty) {
    for (final s in resultStops) {
      linePoints.add(LatLng(s.lat, s.lon));
    }
  }

  final firstStationNames = allFirstStopIds
      .map((id) => resolvedFirstStops[id])
      .where((n) => n != null && n.isNotEmpty)
      .cast<String>()
      .toSet()
      .toList();
  final lastStationNames = allLastStopIds
      .map((id) => resolvedLastStops[id])
      .where((n) => n != null && n.isNotEmpty)
      .cast<String>()
      .toSet()
      .toList();

  return {
    'routeStops': resultStops,
    'lineShape': linePoints,
    'firstStationNames': firstStationNames,
    'lastStationNames': lastStationNames,
  };
}
"""

start_idx = text.find(begin_str)
end_idx = text.find(end_str)

new_code = text[:start_idx] + new_block + text[end_idx:] + bottom_block

# need to import foundation
if "import 'package:flutter/foundation.dart';" not in new_code:
    new_code = new_code.replace("import 'package:flutter/material.dart';", "import 'package:flutter/foundation.dart';\\nimport 'package:flutter/material.dart';")

with open('lib/pages/transport_lines_details_page.dart', 'w', encoding='utf-8') as f:
    f.write(new_code)
print("done")
