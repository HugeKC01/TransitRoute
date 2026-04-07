import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:route/services/gtfs_sync_service.dart';

class TimetableEntry {
  final String tripId;
  final String routeId;
  final String headsign;
  final String departureTime;

  // For frequency based
  final bool isFrequency;
  final String? startTime;
  final String? endTime;
  final int? headwaySecs;

  TimetableEntry({
    required this.tripId,
    required this.routeId,
    required this.headsign,
    required this.departureTime,
    this.isFrequency = false,
    this.startTime,
    this.endTime,
    this.headwaySecs,
  });

  String get displayTime {
    if (isFrequency) {
      if (headwaySecs != null) {
        final mins = headwaySecs! ~/ 60;
        return 'Every $mins mins ($startTime - $endTime)';
      }
      return 'Freq: $startTime - $endTime';
    } else {
      if (departureTime.isEmpty) return 'Unknown Time';
      final parts = departureTime.split(':');
      if (parts.length >= 2) {
        return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      }
      return departureTime;
    }
  }
}

class TimetableService {
  static Future<List<TimetableEntry>> getTimetableForStop(
    String stopId, {
    String? serviceId,
  }) async {
    final entries = <TimetableEntry>[];

    // Determine today's service ID if not provided
    final now = DateTime.now();
    final isSat = now.weekday == DateTime.saturday;
    final isSun = now.weekday == DateTime.sunday;
    final isWkd = !isSat && !isSun;

    // Read trips to map tripId -> routeId, headsign, and serviceId
    final tripMap = <String, Map<String, String>>{};
    try {
      final tripContent = await gtfsSyncService.getGtfsFile(
        'assets/gtfs_data/trips.txt',
      );
      final lines = const LineSplitter().convert(tripContent);
      if (lines.length > 1) {
        final header = lines[0].split(',');
        final tripIdx = header.indexOf('trip_id');
        final routeIdx = header.indexOf('route_id');
        final headsignIdx = header.indexOf('trip_headsign');
        final serviceIdx = header.indexOf('service_id');

        for (int i = 1; i < lines.length; i++) {
          final row = lines[i].split(',');
          if (row.length > tripIdx) {
            final tId = row[tripIdx].trim();
            final rId = (routeIdx != -1 && row.length > routeIdx)
                ? row[routeIdx].trim()
                : '';
            final svcId = (serviceIdx != -1 && row.length > serviceIdx)
                ? row[serviceIdx].trim()
                : '';

            var hSign = (headsignIdx != -1 && row.length > headsignIdx)
                ? row[headsignIdx].trim()
                : '';
            if (tId.startsWith('F_')) {
              hSign = 'Ferry';
            }
            tripMap[tId] = {
              'route_id': rId,
              'headsign': hSign,
              'service_id': svcId,
            };
          }
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }

    // 1. Read fixed_timetables.txt
    try {
      final fixedContent = await gtfsSyncService.getGtfsFile(
        'assets/gtfs_data/fixed_timetables.txt',
      );
      final lines = const LineSplitter().convert(fixedContent);
      if (lines.length > 1) {
        final header = lines[0].split(',');
        final tripIdx = header.indexOf('trip_id');
        final stopIdx = header.indexOf('stop_id');
        final timesIdx = header.indexOf('departure_times');

        if (tripIdx != -1 && stopIdx != -1 && timesIdx != -1) {
          for (int i = 1; i < lines.length; i++) {
            if (lines[i].trim().isEmpty) continue;
            final row = lines[i].split(',');
            if (row.length > stopIdx && row.length > timesIdx) {
              final sId = row[stopIdx].trim();
              if (sId == stopId) {
                final tId = row[tripIdx].trim();
                final tInfo =
                    tripMap[tId] ??
                    {'route_id': '', 'headsign': '', 'service_id': ''};

                // Check calendar service logic
                final tSvc = tInfo['service_id']!;
                bool isValid = false;
                if (tSvc.isEmpty || tSvc == 'ALL' || tSvc == 'EVERYDAY') {
                  isValid = true;
                } else if (tSvc == 'WKD' && isWkd) {
                  isValid = true;
                } else if (tSvc == 'SAT' && isSat) {
                  isValid = true;
                } else if (tSvc == 'SUN' && isSun) {
                  isValid = true;
                } else if (tSvc == 'SUN_SAT' && (isSat || isSun)) {
                  isValid = true;
                } else if (serviceId != null && tSvc == serviceId) {
                  isValid = true;
                }

                if (!isValid) {
                  continue;
                }

                final timesStr = row[timesIdx].trim();
                final times = timesStr.split(';');
                for (final t in times) {
                  if (t.trim().isNotEmpty) {
                    entries.add(
                      TimetableEntry(
                        tripId: tId,
                        routeId: tInfo['route_id']!,
                        headsign: tInfo['headsign']!,
                        departureTime: t.trim(),
                        isFrequency: false,
                      ),
                    );
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }

    // Read frequencies
    final frequencies = <String, List<Map<String, dynamic>>>{};
    try {
      final freqContent = await gtfsSyncService.getGtfsFile(
        'assets/gtfs_data/frequencies.txt',
      );
      final lines = const LineSplitter().convert(freqContent);
      if (lines.length > 1) {
        final header = lines[0].split(',');
        final tripIdx = header.indexOf('trip_id');
        final startIdx = header.indexOf('start_time');
        final endIdx = header.indexOf('end_time');
        final headwayIdx = header.indexOf('headway_secs');

        for (int i = 1; i < lines.length; i++) {
          final row = lines[i].split(',');
          if (row.length > startIdx) {
            final tId = row[tripIdx].trim();
            frequencies.putIfAbsent(tId, () => []).add({
              'start_time': row[startIdx].trim(),
              'end_time': row[endIdx].trim(),
              'headway_secs': int.tryParse(row[headwayIdx].trim()) ?? 0,
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }

    // Helper to read stop times from a specific file
    Future<void> readStopTimes(String assetPath) async {
      try {
        final stContent = await gtfsSyncService.getGtfsFile(assetPath);
        final lines = const LineSplitter().convert(stContent);
        if (lines.length <= 1) return;

        final header = lines[0].split(',');
        final tripIdx = header.indexOf('trip_id');
        final stopIdx = header.indexOf('stop_id');
        final depIdx = header.indexOf('departure_time');

        for (int i = 1; i < lines.length; i++) {
          final row = lines[i].split(',');
          if (row.length > stopIdx) {
            final sId = row[stopIdx].trim();
            if (sId == stopId) {
              final tId = row[tripIdx].trim();
              var dTime = '';
              if (depIdx != -1 && row.length > depIdx) {
                dTime = row[depIdx].trim();
              }

              final tInfo =
                  tripMap[tId] ??
                  {'route_id': '', 'headsign': '', 'service_id': ''};

              // Check calendar service logic for frequencies
              final tSvc = tInfo['service_id']!;
              bool isValid = false;
              if (tSvc.isEmpty || tSvc == 'ALL' || tSvc == 'EVERYDAY') {
                isValid = true;
              } else if (tSvc == 'WKD' && isWkd) {
                isValid = true;
              } else if (tSvc == 'SAT' && isSat) {
                isValid = true;
              } else if (tSvc == 'SUN' && isSun) {
                isValid = true;
              } else if (tSvc == 'SUN_SAT' && (isSat || isSun)) {
                isValid = true;
              } else if (serviceId != null && tSvc == serviceId) {
                isValid = true;
              }

              if (!isValid) {
                continue;
              }

              if (frequencies.containsKey(tId)) {
                for (var freq in frequencies[tId]!) {
                  entries.add(
                    TimetableEntry(
                      tripId: tId,
                      routeId: tInfo['route_id']!,
                      headsign: tInfo['headsign']!,
                      departureTime: dTime,
                      isFrequency: true,
                      startTime: freq['start_time'],
                      endTime: freq['end_time'],
                      headwaySecs: freq['headway_secs'],
                    ),
                  );
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Error: $e");
      }
    }

    await readStopTimes('assets/gtfs_data/stop_times.txt');
    await readStopTimes('assets/gtfs_data/bus_stop_times.txt');
    await readStopTimes('assets/gtfs_data/ferry_stop_times.txt');

    // Remove duplicates based on exact same frequency or time for same trip
    final uniqueEntries = <String, TimetableEntry>{};
    for (var e in entries) {
      final key = e.isFrequency
          ? '${e.tripId}_${e.startTime}'
          : '${e.tripId}_${e.departureTime}';
      uniqueEntries[key] = e;
    }

    final result = uniqueEntries.values.toList();
    result.sort((a, b) {
      final tA = a.isFrequency ? a.startTime! : a.departureTime;
      final tB = b.isFrequency ? b.startTime! : b.departureTime;
      return tA.compareTo(tB);
    });

    return result;
  }
}
