import sys

with open('lib/pages/transport_lines_details_page.dart', 'r') as f:
    text = f.read()

# Replace _loadRouteStops
load_stops_sig = "Future<void> _loadRouteStops() async {"
color_sig = "  Color _colorFromHexOr("

start_idx = text.find(load_stops_sig)
end_idx = text.find(color_sig)

new_func = """
  Future<void> _loadRouteStops() async {
    try {
      final routeId = widget.route.routeId;
      String tripsFile = 'assets/gtfs_data/trips.txt';
      String stopTimesFile = 'assets/gtfs_data/stop_times.txt';
      String stopsFile = 'assets/gtfs_data/stops.txt';
      String shapesFile = 'assets/gtfs_data/shapes.txt';
      String? tIdIdxName = 'trip_id';
      String? rIdIdxName = 'route_id';
      
      bool isBus = routeId.startsWith('BUS_');
      if (isBus) {
        tripsFile = 'assets/gtfs_data/bus_route_stop.txt';
        stopTimesFile = '';
        stopsFile = 'assets/gtfs_data/bus_stop.txt';
        shapesFile = 'assets/gtfs_data/shapes_source.txt';
      } else if (routeId == 'BRT') {
        tripsFile = 'assets/gtfs_data/brt_trips.txt';
        stopTimesFile = 'assets/gtfs_data/bus_stop_times.txt';
        stopsFile = 'assets/gtfs_data/bus_stop.txt';
        shapesFile = 'assets/gtfs_data/shapes.txt';
      } else if (widget.route.type.toLowerCase() == 'ferry' || widget.route.type == '4') {
        tripsFile = 'assets/gtfs_data/ferry_trips.txt';
        stopTimesFile = 'assets/gtfs_data/ferry_stop_times.txt';
        stopsFile = 'assets/gtfs_data/ferry_stop.txt';
        shapesFile = '';
      }

      final targetTripIds = <String>{};
      String? targetShapeId;
      final orderedStopIds = <String>[];
      
      if (isBus) {
        final busLineId = routeId.replaceFirst('BUS_', '');
        final busContent = await gtfsSyncService.getGtfsFile(tripsFile);
        final busLines = const LineSplitter().convert(busContent);
        if (busLines.length > 1) {
          for (int i = 1; i < busLines.length; i++) {
             final row = _parseCsvLine(busLines[i]);
             if (row.length > 5 && row[0].trim() == busLineId) {
                targetShapeId = row[5].trim();
                for (int j = 6; j < row.length; j++) {
                  final sid = row[j].trim();
                  if (sid.isNotEmpty) orderedStopIds.add(sid);
                }
                break;
             }
          }
        }
      } else {
        final tripsContent = await gtfsSyncService.getGtfsFile(tripsFile);
        final tripsLines = const LineSplitter().convert(tripsContent);
        if (tripsLines.length > 1) {
          final headerRow = _parseCsvLine(tripsLines.first);
          final routeIdIdx = headerRow.indexOf(rIdIdxName!);
          final tripIdIdx = headerRow.indexOf(tIdIdxName!);
          final shapeIdIdx = headerRow.indexOf('shape_id');
          bool brtFallback = tripIdIdx < 0 && routeId == 'BRT';
          
          for (int i = brtFallback ? 0 : 1; i < tripsLines.length; i++) {
            final row = _parseCsvLine(tripsLines[i]);
            if (row.isEmpty) continue;
            if (brtFallback) {
               if (row[0].contains('BRT')) {
                 targetTripIds.add(row[0]);
                 if (row.length > 7 && row[7].isNotEmpty) targetShapeId = row[7];
               }
            } else if (routeIdIdx >= 0 && tripIdIdx >= 0 && row.length > routeIdIdx && row[routeIdIdx] == routeId) {
              targetTripIds.add(row[tripIdIdx]);
              if (shapeIdIdx >= 0 && row.length > shapeIdIdx && row[shapeIdIdx].isNotEmpty) {
                 targetShapeId = row[shapeIdIdx];
              }
            }
          }
        }

        if (targetTripIds.isNotEmpty && stopTimesFile.isNotEmpty) {
          final stopTimesContent = await gtfsSyncService.getGtfsFile(stopTimesFile);
          final stopTimesLines = const LineSplitter().convert(stopTimesContent);
          if (stopTimesLines.length > 1) {
            final headerRow = _parseCsvLine(stopTimesLines.first);
            final tripIdIdx = headerRow.indexOf('trip_id');
            final stopIdIdx = headerRow.indexOf('stop_id');
            final seqIdx = headerRow.indexOf('stop_sequence');
            
            final tripStopsMap = <String, List<Map<String, dynamic>>>{};
            for (int i = 1; i < stopTimesLines.length; i++) {
              final row = _parseCsvLine(stopTimesLines[i]);
              if (row.isEmpty) continue;
              if (tripIdIdx >= 0 && stopIdIdx >= 0 && row.length > tripIdIdx && targetTripIds.contains(row[tripIdIdx])) {
                tripStopsMap.putIfAbsent(row[tripIdIdx], () => []).add({
                  'stop_id': row[stopIdIdx],
                  'sequence': int.tryParse(row[seqIdx]) ?? 0,
                });
              }
            }
            if (tripStopsMap.isNotEmpty) {
              final sortedTrips = tripStopsMap.values.toList()..sort((a, b) => b.length.compareTo(a.length));
              final longestTrip = sortedTrips.first;
              longestTrip.sort((a, b) => (a['sequence'] as int).compareTo(b['sequence'] as int));
              for (final st in longestTrip) {
                orderedStopIds.add(st['stop_id'] as String);
              }
            }
          }
        }
      }

      final stopsContent = await gtfsSyncService.getGtfsFile(stopsFile);
      final stopsLines = const LineSplitter().convert(stopsContent);
      final Map<String, gtfs.Stop> stopsMap = {};

      if (stopsLines.length > 1) {
        final headerRow = _parseCsvLine(stopsLines.first);
        final idIdx = headerRow.indexOf('stop_id');
        final nameIdx = headerRow.indexOf('stop_name');
        final thaiIdx = headerRow.indexOf('stop_name_th');
        final latIdx = headerRow.indexOf('stop_lat');
        final lonIdx = headerRow.indexOf('stop_lon');
        final codeIdx = headerRow.indexOf('stop_code');
        final descIdx = headerRow.indexOf('stop_desc');
        final zoneIdx = headerRow.indexOf('zone_id');

        for (int i = 1; i < stopsLines.length; i++) {
          final row = _parseCsvLine(stopsLines[i]);
          if (row.isEmpty || row.length <= idIdx) continue;
          final stopId = row[idIdx];
          
          if (orderedStopIds.contains(stopId)) {
            String valueAt(int idx) => (idx >= 0 && idx < row.length) ? row[idx].trim() : '';
            final thaiName = valueAt(thaiIdx);
            
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
      if (targetShapeId != null && targetShapeId.isNotEmpty && shapesFile.isNotEmpty) {
         try {
           final shapeContent = await gtfsSyncService.getGtfsFile(shapesFile);
           final shapeLines = const LineSplitter().convert(shapeContent);
           if (shapeLines.length > 1) {
              final sHead = _parseCsvLine(shapeLines.first);
              final sidIdx = sHead.indexOf('shape_id');
              final latIdx = sHead.indexOf('shape_pt_lat');
              final lonIdx = sHead.indexOf('shape_pt_lon');
              final seqIdx = sHead.indexOf('shape_pt_sequence');
              
              final pts = <Map<String, dynamic>>[];
              for (int i = 1; i < shapeLines.length; i++) {
                 final row = _parseCsvLine(shapeLines[i]);
                 if (row.length > sidIdx && row[sidIdx] == targetShapeId) {
                    pts.add({
                      'lat': double.tryParse(row[latIdx]) ?? 0.0,
                      'lon': double.tryParse(row[lonIdx]) ?? 0.0,
                      'seq': int.tryParse(row[seqIdx]) ?? 0,
                    });
                 }
              }
              pts.sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
              for (final pt in pts) linePoints.add(LatLng(pt['lat'], pt['lon']));
           }
         } catch (_) {}
      }

      if (linePoints.isEmpty && resultStops.isNotEmpty) {
         for (final s in resultStops) linePoints.add(LatLng(s.lat, s.lon));
      }

      setState(() {
        _routeStops = resultStops;
        _lineShape = linePoints;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading stops for route: $e');
      setState(() {
        _loading = false;
      });
    }
  }
"""

text = text[:start_idx] + new_func + text[end_idx:]

with open('lib/pages/transport_lines_details_page.dart', 'w') as f:
    f.write(text)

