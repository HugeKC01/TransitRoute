import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      final start = startTime != null
          ? startTime!.split(':').take(2).join(':')
          : '';
      final end = endTime != null ? endTime!.split(':').take(2).join(':') : '';
      if (headwaySecs != null) {
        final mins = headwaySecs! ~/ 60;
        final sec = headwaySecs! % 60;
        final timeStr = sec > 0 ? '$mins min ${sec}s' : '$mins mins';
        return 'Every $timeStr ($start - $end)';
      }
      return 'Freq: $start - $end';
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
  static bool _isLoaded = false;
  static final Map<String, Map<String, String>> _tripMap = {};
  static List<String> _fixedTimetableLines = [];
  static final Map<String, List<Map<String, dynamic>>> _frequencies = {};
  static final Set<String> _weekendRoutes = {};
  static List<String> _stopTimesLines = [];
  static List<String> _busStopTimesLines = [];
  static List<String> _ferryStopTimesLines = [];

  static Future<void> _loadData() async {
    if (_isLoaded) return;

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
            _tripMap[tId] = {
              'route_id': rId,
              'headsign': hSign,
              'service_id': svcId,
            };
            if (svcId == 'SAT' || svcId == 'SUN' || svcId == 'SUN_SAT') {
              _weekendRoutes.add(rId);
            }
          }
        }
      }
    } catch (_) {}

    try {
      final fixedContent = await gtfsSyncService.getGtfsFile(
        'assets/gtfs_data/fixed_timetables.txt',
      );
      _fixedTimetableLines = const LineSplitter().convert(fixedContent);
    } catch (_) {}

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
            _frequencies.putIfAbsent(tId, () => []).add({
              'start_time': row[startIdx].trim(),
              'end_time': row[endIdx].trim(),
              'headway_secs': int.tryParse(row[headwayIdx].trim()) ?? 0,
            });
          }
        }
      }
    } catch (_) {}

    try {
      final content1 = await gtfsSyncService.getGtfsFile(
        'assets/gtfs_data/stop_times.txt',
      );
      _stopTimesLines = const LineSplitter().convert(content1);
    } catch (_) {}
    try {
      final content2 = await gtfsSyncService.getGtfsFile(
        'assets/gtfs_data/bus_stop_times.txt',
      );
      _busStopTimesLines = const LineSplitter().convert(content2);
    } catch (_) {}
    try {
      final content3 = await gtfsSyncService.getGtfsFile(
        'assets/gtfs_data/ferry_stop_times.txt',
      );
      _ferryStopTimesLines = const LineSplitter().convert(content3);
    } catch (_) {}

    _isLoaded = true;
  }

  static Future<List<TimetableEntry>> getTimetableForStop(
    String stopId, {
    String? serviceId,
  }) async {
    await _loadData();
    final entries = <TimetableEntry>[];

    // Determine today's service ID if not provided
    final now = DateTime.now();
    final isSat = now.weekday == DateTime.saturday;
    final isSun = now.weekday == DateTime.sunday;
    final isWkd = !isSat && !isSun;

    // 1. Read fixed_timetables.txt
    try {
      final lines = _fixedTimetableLines;
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
                    _tripMap[tId] ??
                    {'route_id': '', 'headsign': '', 'service_id': ''};

                // Check calendar service logic
                final tSvc = tInfo['service_id']!;
                final rId = tInfo['route_id']!;
                bool isValid = false;
                if (tSvc.isEmpty || tSvc == 'ALL' || tSvc == 'EVERYDAY') {
                  isValid = true;
                } else if (serviceId != null) {
                  if (tSvc == serviceId) {
                    isValid = true;
                  } else if ((serviceId == 'SAT' || serviceId == 'SUN') &&
                      tSvc == 'WKD' &&
                      !_weekendRoutes.contains(rId)) {
                    isValid = true;
                  } else if ((serviceId == 'SAT' || serviceId == 'SUN') &&
                      tSvc == 'SUN_SAT') {
                    isValid = true;
                  }
                } else {
                  if (tSvc == 'WKD' && isWkd) {
                    isValid = true;
                  } else if (tSvc == 'SAT' && isSat) {
                    isValid = true;
                  } else if (tSvc == 'SUN' && isSun) {
                    isValid = true;
                  } else if (tSvc == 'SUN_SAT' && (isSat || isSun)) {
                    isValid = true;
                  } else if (tSvc == 'WKD' &&
                      (isSat || isSun) &&
                      !_weekendRoutes.contains(rId)) {
                    isValid = true;
                  }
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

    // Helper to read stop times from memory
    void readStopTimes(List<String> lines) {
      try {
        if (lines.isEmpty) return;

        int tripIdx = 0;
        int stopIdx = 3;
        int depIdx = 2;
        int startIdx = 0;

        if (lines[0].contains('trip_id')) {
          final header = lines[0].split(',');
          tripIdx = header.indexOf('trip_id');
          stopIdx = header.indexOf('stop_id');
          depIdx = header.indexOf('departure_time');
          startIdx = 1;
        }

        for (int i = startIdx; i < lines.length; i++) {
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
                  _tripMap[tId] ??
                  {'route_id': '', 'headsign': '', 'service_id': ''};

              // Check calendar service logic for frequencies
              final tSvc = tInfo['service_id']!;
              final rId = tInfo['route_id']!;
              bool isValid = false;
              if (tSvc.isEmpty || tSvc == 'ALL' || tSvc == 'EVERYDAY') {
                isValid = true;
              } else if (serviceId != null) {
                if (tSvc == serviceId) {
                  isValid = true;
                } else if ((serviceId == 'SAT' || serviceId == 'SUN') &&
                    tSvc == 'WKD' &&
                    !_weekendRoutes.contains(rId)) {
                  isValid = true;
                } else if ((serviceId == 'SAT' || serviceId == 'SUN') &&
                    tSvc == 'SUN_SAT') {
                  isValid = true;
                }
              } else {
                if (tSvc == 'WKD' && isWkd) {
                  isValid = true;
                } else if (tSvc == 'SAT' && isSat) {
                  isValid = true;
                } else if (tSvc == 'SUN' && isSun) {
                  isValid = true;
                } else if (tSvc == 'SUN_SAT' && (isSat || isSun)) {
                  isValid = true;
                } else if (tSvc == 'WKD' &&
                    (isSat || isSun) &&
                    !_weekendRoutes.contains(rId)) {
                  isValid = true;
                }
              }

              if (!isValid) {
                continue;
              }

              if (_frequencies.containsKey(tId)) {
                for (var freq in _frequencies[tId]!) {
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
              } else if (dTime.isNotEmpty) {
                entries.add(
                  TimetableEntry(
                    tripId: tId,
                    routeId: tInfo['route_id']!,
                    headsign: tInfo['headsign']!,
                    departureTime: dTime,
                    isFrequency: false,
                  ),
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Error: $e");
      }
    }

    readStopTimes(_stopTimesLines);
    readStopTimes(_busStopTimesLines);
    readStopTimes(_ferryStopTimesLines);

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
