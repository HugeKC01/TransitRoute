import 'dart:convert';
import 'package:route/services/gtfs_sync_service.dart';

class TerminalLoader {
  static List<String> _parseCsvLine(String line) {
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

  static Future<Map<String, String>> loadAllTerminals() async {
    final terminals = <String, String>{};

    Future<void> processFiles(
      String tripsFile,
      String stopTimesFile,
      String stopsFile,
    ) async {
      try {
        final tripsStr = await gtfsSyncService.getGtfsFile(tripsFile);
        final stopTimesStr = await gtfsSyncService.getGtfsFile(stopTimesFile);
        final stopsStr = await gtfsSyncService.getGtfsFile(stopsFile);

        final tripsLines = const LineSplitter().convert(tripsStr);
        final tripRouteMap = <String, String>{};

        if (tripsLines.length > 1) {
          final tHeader = _parseCsvLine(
            tripsLines.first,
          ).map((e) => e.trim()).toList();
          final tTripIdIdx = tHeader.indexOf('trip_id');
          final tRouteIdIdx = tHeader.indexOf('route_id');

          if (tTripIdIdx >= 0 && tRouteIdIdx >= 0) {
            for (int i = 1; i < tripsLines.length; i++) {
              final row = _parseCsvLine(tripsLines[i]);
              if (row.length > tTripIdIdx && row.length > tRouteIdIdx) {
                tripRouteMap[row[tTripIdIdx]] = row[tRouteIdIdx];
              }
            }
          } else {
            // Probably BRT trips which lacks header: `BRT_0,77` -> `trip_id, something`
            for (int i = 0; i < tripsLines.length; i++) {
              final row = _parseCsvLine(tripsLines[i]);
              if (row.isNotEmpty) {
                final tripId = row[0];
                if (tripId.contains('BRT')) {
                  tripRouteMap[tripId] = 'BRT';
                }
              }
            }
          }
        } else if (tripsLines.length == 1) {
          // Single line? Skip or handle if no header.
        }

        final stopTimesLines = const LineSplitter().convert(stopTimesStr);
        if (stopTimesLines.length <= 1) return;
        final stHeader = _parseCsvLine(
          stopTimesLines.first,
        ).map((e) => e.trim()).toList();
        final stTripIdIdx = stHeader.indexOf('trip_id');
        final stStopIdIdx = stHeader.indexOf('stop_id');
        final stSeqIdx = stHeader.indexOf('stop_sequence');

        final tripStopsMap = <String, List<Map<String, dynamic>>>{};
        if (stTripIdIdx >= 0 && stStopIdIdx >= 0 && stSeqIdx >= 0) {
          for (int i = 1; i < stopTimesLines.length; i++) {
            final row = _parseCsvLine(stopTimesLines[i]);
            if (row.length > stTripIdIdx &&
                row.length > stStopIdIdx &&
                row.length > stSeqIdx) {
              final tripId = row[stTripIdIdx];
              if (tripRouteMap.containsKey(tripId)) {
                tripStopsMap.putIfAbsent(tripId, () => []).add({
                  'stop_id': row[stStopIdIdx],
                  'sequence': int.tryParse(row[stSeqIdx]) ?? 0,
                });
              }
            }
          }
        }

        final stopsLines = const LineSplitter().convert(stopsStr);
        if (stopsLines.length <= 1) return;
        final sHeader = _parseCsvLine(
          stopsLines.first,
        ).map((e) => e.trim()).toList();
        final sStopIdIdx = sHeader.indexOf('stop_id');
        final sNameIdx = sHeader.indexOf('stop_name');
        final sThaiNameIdx = sHeader.indexOf('stop_name_th');

        final stopNames = <String, String>{};
        if (sStopIdIdx >= 0) {
          for (int i = 1; i < stopsLines.length; i++) {
            final row = _parseCsvLine(stopsLines[i]);
            if (row.length > sStopIdIdx) {
              String name = '';
              if (sThaiNameIdx >= 0 &&
                  row.length > sThaiNameIdx &&
                  row[sThaiNameIdx].trim().isNotEmpty) {
                name = row[sThaiNameIdx].trim();
              } else if (sNameIdx >= 0 &&
                  row.length > sNameIdx &&
                  row[sNameIdx].trim().isNotEmpty) {
                name = row[sNameIdx].trim();
              }
              if (name.isNotEmpty) {
                stopNames[row[sStopIdIdx].trim()] = name;
              }
            }
          }
        }

        final routeTripsMap = <String, List<String>>{};
        for (final tripId in tripStopsMap.keys) {
          final routeId = tripRouteMap[tripId]!;
          routeTripsMap.putIfAbsent(routeId, () => []).add(tripId);
        }

        for (final entry in routeTripsMap.entries) {
          final routeId = entry.key;
          final tIds = entry.value;

          String longestTrip = tIds.first;
          int maxStops = tripStopsMap[longestTrip]!.length;
          for (int i = 1; i < tIds.length; i++) {
            if (tripStopsMap[tIds[i]]!.length > maxStops) {
              longestTrip = tIds[i];
              maxStops = tripStopsMap[tIds[i]]!.length;
            }
          }

          final sequence = tripStopsMap[longestTrip]!;
          sequence.sort(
            (a, b) => (a['sequence'] as int).compareTo(b['sequence'] as int),
          );

          final referenceFirst = sequence.first['stop_id'] as String;
          final referenceLast = sequence.last['stop_id'] as String;

          final allFirstIds = <String>{};
          final allLastIds = <String>{};

          for (final tId in tIds) {
            final tSeq = tripStopsMap[tId]!;
            if (tSeq.isNotEmpty) {
              tSeq.sort(
                (a, b) =>
                    (a['sequence'] as int).compareTo(b['sequence'] as int),
              );
              final tFirst = tSeq.first['stop_id'] as String;
              final tLast = tSeq.last['stop_id'] as String;
              if (tFirst == referenceFirst || tLast == referenceLast) {
                allFirstIds.add(tFirst);
                allLastIds.add(tLast);
              }
            }
          }

          final firstNames = allFirstIds
              .map((id) => stopNames[id] ?? id)
              .toList();
          final lastNames = allLastIds
              .map((id) => stopNames[id] ?? id)
              .toList();

          terminals[routeId] =
              '${firstNames.join(', ')} - ${lastNames.join(', ')}';
        }
      } catch (e) {
        // file missing or syntax error, just continue
      }
    }

    await processFiles(
      'assets/gtfs_data/trips.txt',
      'assets/gtfs_data/stop_times.txt',
      'assets/gtfs_data/stops.txt',
    );
    await processFiles(
      'assets/gtfs_data/ferry_trips.txt',
      'assets/gtfs_data/ferry_stop_times.txt',
      'assets/gtfs_data/ferry_stop.txt',
    );
    await processFiles(
      'assets/gtfs_data/brt_trips.txt',
      'assets/gtfs_data/bus_stop_times.txt',
      'assets/gtfs_data/bus_stop.txt',
    );

    return terminals;
  }
}
