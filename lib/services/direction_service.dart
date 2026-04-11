import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:collection/collection.dart';

import 'package:route/services/gtfs_sync_service.dart';
import 'package:http/http.dart' as http;

import 'package:route/services/csv_utils.dart';
import 'package:route/services/fare_calculator.dart';
import 'package:route/services/geo_utils.dart' as geo;
import 'package:route/services/gtfs_models.dart' as gtfs;
import 'package:route/services/transit_update_service.dart';
import 'package:route/services/timetable_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

Map<String, List<Map<String, dynamic>>> _parseStopTimesIsolate(String content) {
  final result = <String, List<Map<String, dynamic>>>{};
  final lines = const LineSplitter().convert(content);
  if (lines.length <= 1) return result;
  final header = parseCsvLine(lines.first).map((s) => s.trim()).toList();
  final idxTripId = header.indexOf('trip_id');
  final idxStopId = header.indexOf('stop_id');
  final idxStopSeq = header.indexOf('stop_sequence');
  if (idxTripId < 0 || idxStopId < 0 || idxStopSeq < 0) {
    return result;
  }
  for (int i = 1; i < lines.length; i++) {
    final line = lines[i].trimRight();
    if (line.isEmpty) continue;
    final row = parseCsvLine(line);
    if (row.length <= idxTripId ||
        row.length <= idxStopId ||
        row.length <= idxStopSeq) {
      continue;
    }
    final tripId = row[idxTripId].trim();
    final stopId = row[idxStopId].trim();
    final stopSequence = int.tryParse(row[idxStopSeq].trim()) ?? i;
    if (tripId.isEmpty || stopId.isEmpty) continue;
    result.putIfAbsent(tripId, () => []).add({
      'stopId': stopId,
      'stopSequence': stopSequence,
    });
  }
  return result;
}

typedef LineNameResolver = String? Function(String stopId);

class _DijkstraNode {
  final String stopId;
  final String lineName;
  final double cost;
  _DijkstraNode(this.stopId, this.lineName, this.cost);
}

enum TravelMode {
  walk,
  bicycle,
  taxi,
  transit, // Broken down further via tags or routeId (BTS, MRT, Bus, Ferry)
}

class LocationPoint {
  final double lat;
  final double lon;
  final String name;
  final String? stopId; // null if this is an arbitrary map coordinate

  LocationPoint({
    required this.lat,
    required this.lon,
    required this.name,
    this.stopId,
  });

  factory LocationPoint.fromStop(gtfs.Stop stop) {
    return LocationPoint(
      lat: stop.lat,
      lon: stop.lon,
      name: stop.name,
      stopId: stop.stopId,
    );
  }
}

class RouteSegment {
  final TravelMode mode;
  final LocationPoint start;
  final LocationPoint end;
  double distanceMeters;
  int durationMinutes;
  int fare; // Monetary cost for this specific segment

  // Transit-specific details
  final String? routeId;
  final String? shapeId;
  final String? routeShortName;
  final String? routeType;
  String? instruction; // e.g., "Walk to BTS Siam" or "Take Sukhumvit Line"
  final List<gtfs.Stop>? intermediateStops;
  List<LocationPoint>? roadPolyline;
  final bool hasIssue;
  final String? issueNotice;

  // Timetable
  String? nextDepartureTime;
  String? frequencyInfo;

  RouteSegment({
    required this.mode,
    required this.start,
    required this.end,
    required this.distanceMeters,
    required this.durationMinutes,
    this.fare = 0,
    this.routeId,
    this.shapeId,
    this.routeShortName,
    this.routeType,
    this.instruction,
    this.intermediateStops,
    this.roadPolyline,
    this.hasIssue = false,
    this.issueNotice,
  });

  bool get isBus {
    if (mode != TravelMode.transit) return false;
    final rType = routeType;
    if (rType != null) {
      if (rType == '3' || rType.toLowerCase() == 'bus') return true;
    }
    final name = routeShortName?.toLowerCase() ?? '';
    if (name.contains('bus') || name.contains('bmta') || name.contains('brt')) {
      return true;
    }
    if (intermediateStops != null && intermediateStops!.isNotEmpty) {
      final id = intermediateStops!.first.stopId.trim();
      if (id.startsWith('ST_') ||
          id.startsWith('STOP_') ||
          int.tryParse(id) != null) {
        return true;
      }
    }
    return false;
  }

  bool get isFerry {
    if (mode != TravelMode.transit) return false;
    final rType = routeType;
    if (rType != null) {
      if (rType == '4' || rType.toLowerCase() == 'ferry') return true;
    }
    final name = routeShortName?.toLowerCase() ?? '';
    if (name.contains('boat') || name.contains('ferry')) return true;
    return false;
  }

  bool get isTrain {
    if (mode != TravelMode.transit) return false;
    final rType = routeType;
    if (rType != null) {
      if (rType == '2' || rType.toLowerCase() == 'rail') return true;
    }
    return false;
  }

  bool get isMetro {
    if (mode != TravelMode.transit) return false;
    if (isBus || isFerry || isTrain) return false;
    return true;
  }
}

class DirectionOption {
  DirectionOption({
    required this.segments,
    required this.tags,
    required this.label,
    required this.distanceMeters,
    required this.minutes,
    required this.fareBreakdown,
    this.hasIssue = false,
    this.issueNotice,
  });

  final List<RouteSegment> segments;
  final Set<String> tags;
  String label;
  final double distanceMeters;
  final int minutes;
  final Map<String, int> fareBreakdown;
  final bool hasIssue;
  final String? issueNotice;

  // Helper to retrieve all transit stops involved across all segments
  List<gtfs.Stop> get allStops {
    return segments
        .where((s) => s.intermediateStops != null)
        .expand((s) => s.intermediateStops!)
        .toList();
  }
}

class DirectionResult {
  DirectionResult({required this.options, required this.selectionIndex});

  final List<DirectionOption> options;
  final int selectionIndex;

  factory DirectionResult.empty() =>
      DirectionResult(options: const [], selectionIndex: 0);
}

class DirectionService {
  DirectionService({required this.lineNameResolver});

  static const List<String> _stopTimeAssets = [
    'assets/gtfs_data/stop_times.txt',
    'assets/gtfs_data/bus_stop_times.txt',
    'assets/gtfs_data/ferry_stop_times.txt',
  ];

  final LineNameResolver lineNameResolver;

  List<gtfs.Stop> _allStops = const [];
  Map<String, gtfs.Stop> _stopLookup = const {};
  List<gtfs.Route> _routes = const [];
  Map<String, gtfs.BusRouteInfo> _busRouteInfoMap = const {};
  final FareCalculator _fareCalculator = FareCalculator();

  static const List<List<String>> _transferHubs = [
    ['CEN'],
    ['S7', 'G1'],
    ['S6', 'F_CEN'],
    ['BL01'],
    ['BL13', 'N8'],
    ['BL14', 'N9'],
    ['BL22', 'E4'],
    ['BL26', 'S2'],
    ['BL34', 'S12'],
    ['PP16', 'BL10'],
    ['PP15', 'RW02'],
    ['PP11', 'PK01'],
    ['BL15', 'YL01'],
    ['E15', 'YL23'],
    ['N17', 'PK16'],
    ['RN06', 'PK14'],
    ['PK10'],
    ['BL11', 'RW01', 'RN01'],
    ['N2', 'A8'],
    ['BL21', 'A6'],
    ['YL11', 'A4'],
  ];

  final Map<String, Map<String, double>> _distanceGraph = {};
  final Map<String, Map<String, int>> _timeGraph = {};
  final Map<String, Map<String, Set<String>>> _transitEdges = {};
  final Map<String, String> _stopToRouteTypeCache = {};
  final Map<String, String> _lineToRouteTypeCache = {};
  bool _graphBuilt = false;

  String? getRouteTypeForStop(String stopId) {
    if (_stopToRouteTypeCache.containsKey(stopId)) {
      return _stopToRouteTypeCache[stopId];
    }
    String? result;
    if (stopId.startsWith('ST_') || stopId.startsWith('STOP_')) {
      result = '3'; // Bus
    } else if (int.tryParse(stopId) != null) {
      result = '3'; // Bus numeric IDs
    } else {
      for (final route in _routes) {
        for (final pref in route.linePrefixes) {
          if (stopId == pref ||
              (pref != 'F_' && stopId.startsWith(pref)) ||
              (pref == 'F_' && stopId.startsWith('F_'))) {
            result = route.type;
            break;
          }
        }
        if (result != null) break;
      }
    }
    _stopToRouteTypeCache[stopId] = result ?? '';
    return result == '' ? null : result;
  }

  String? getRouteTypeForLine(String lineName) {
    if (lineName == 'BMTA Bus') return '3'; // Hardcode fallback for generic bus
    if (_lineToRouteTypeCache.containsKey(lineName)) {
      return _lineToRouteTypeCache[lineName];
    }
    String? result;
    for (final route in _routes) {
      if (route.longName == lineName ||
          route.routeId == lineName ||
          route.shortName == lineName) {
        result = route.type;
        break;
      }
    }

    if (result == null && _busRouteInfoMap.containsKey(lineName)) {
      result = '3';
    }

    _lineToRouteTypeCache[lineName] = result ?? '';
    return result == '' ? null : result;
  }

  void updateData({
    List<gtfs.Stop>? allStops,
    Map<String, gtfs.Stop>? stopLookup,
    List<gtfs.Route>? routes,
    Map<String, String>? fareTypeMap,
    Map<String, int>? fareDataMap,
    Map<String, int>? stopOrderMap,
    Map<String, List<int>>? fareTableMap,
    Map<String, int>? ferryFlatFares,
    Map<String, int>? ferryZoneMatrix,
    Map<String, String>? ferryZones,
    Map<String, gtfs.BusRouteInfo>? busRouteInfoMap,
  }) {
    bool resetGraphs = false;
    if (allStops != null) {
      _allStops = List<gtfs.Stop>.from(allStops);
      resetGraphs = true;
    }
    if (stopLookup != null) {
      _stopLookup = Map<String, gtfs.Stop>.from(stopLookup);
      resetGraphs = true;
    }
    if (routes != null) {
      _routes = List<gtfs.Route>.from(routes);
    }
    if (busRouteInfoMap != null) {
      _busRouteInfoMap = Map<String, gtfs.BusRouteInfo>.from(busRouteInfoMap);
    }
    if (fareTypeMap != null ||
        fareDataMap != null ||
        stopOrderMap != null ||
        fareTableMap != null ||
        ferryFlatFares != null ||
        ferryZoneMatrix != null ||
        ferryZones != null ||
        busRouteInfoMap != null) {
      _fareCalculator.updateData(
        fareTypeMap: fareTypeMap,
        fareDataMap: fareDataMap,
        stopOrderMap: stopOrderMap,
        fareTableMap: fareTableMap,
        ferryFlatFares: ferryFlatFares,
        ferryZoneMatrix: ferryZoneMatrix,
        ferryZones: ferryZones,
        busRouteInfoMap: busRouteInfoMap,
      );
    }
    if (resetGraphs) {
      _graphBuilt = false;
      _distanceGraph.clear();
      _timeGraph.clear();
      _transitEdges.clear();
      _cachedStopTimes = null;
      _cachedTrips = null;
    }
  }

  List<gtfs.Stop> getTransferStations(String stopId) {
    final Set<String> connectedStopIds = {};
    for (final hubGroup in _transferHubs) {
      if (hubGroup.contains(stopId)) {
        for (final s in hubGroup) {
          if (s != stopId) {
            connectedStopIds.add(s);
          }
        }
      }
    }
    final currentStop = _stopLookup[stopId];
    if (currentStop != null) {
      for (final stop in _allStops) {
        if (stop.stopId != stopId && !connectedStopIds.contains(stop.stopId)) {
          final dist = geo.haversine(
            currentStop.lat,
            currentStop.lon,
            stop.lat,
            stop.lon,
          );
          if (dist <= 300.0) {
            connectedStopIds.add(stop.stopId);
          }
        }
      }
    }
    final List<gtfs.Stop> transfers = [];
    for (final id in connectedStopIds) {
      final s = _stopLookup[id];
      if (s != null) {
        transfers.add(s);
      }
    }
    return transfers;
  }

  String? _findClosestStop(LocationPoint point) {
    if (point.stopId != null) return point.stopId;
    if (_allStops.isEmpty) return null;

    gtfs.Stop? closestStop;
    double minDistance = double.infinity;

    for (final stop in _allStops) {
      final distance = geo.haversine(point.lat, point.lon, stop.lat, stop.lon);
      if (distance < minDistance) {
        minDistance = distance;
        closestStop = stop;
      }
    }

    return closestStop?.stopId;
  }

  Future<DirectionResult> findDirections({
    required String routingMode,
    required List<String> allowedTransitTypes,
    required LocationPoint startPoint,
    required LocationPoint destPoint,
  }) async {
    await _ensureGraphsBuilt();

    final startStopId = startPoint.stopId ?? _findClosestStop(startPoint);
    final destStopId = destPoint.stopId ?? _findClosestStop(destPoint);

    if (startStopId == null || destStopId == null) {
      return DirectionResult.empty();
    }
    if (startStopId.isEmpty || destStopId.isEmpty) {
      return DirectionResult.empty();
    }
    if (!_stopLookup.containsKey(startStopId) ||
        !_stopLookup.containsKey(destStopId) ||
        _allStops.isEmpty) {
      return DirectionResult.empty();
    }
    if (startStopId == destStopId &&
        startPoint.stopId != null &&
        destPoint.stopId != null) {
      return DirectionResult.empty(); // It's exactly the same transit stop
    }

    final stopTimes = await _loadStopTimes();
    if (stopTimes.isEmpty) {
      return DirectionResult.empty();
    }
    final tripMap = await loadTrips();
    final routeIdToPrefixes = {
      for (final route in _routes) route.routeId: route.linePrefixes,
    };

    final Map<String, _TaggedRoute> optionMap = {};

    RouteSegment createFirstLastMileLeg(
      LocationPoint a,
      LocationPoint b, {
      required bool isStart,
      required gtfs.Stop anchorStop,
    }) {
      final dist = geo.haversine(a.lat, a.lon, b.lat, b.lon);
      TravelMode mode = TravelMode.walk;
      int duration = (dist / 80.0).ceil();
      int calcFare = 0;
      String action = isStart ? 'Walk' : 'Walk';

      if (dist > 1500) {
        mode = TravelMode.taxi;
        duration = (dist / 400.0).ceil() + 5; // 24km/h + 5m wait
        calcFare = 35 + ((dist / 1000.0) * 6).ceil(); // Base BKK Taxi
        action = 'Taxi';
      } else if (dist > 600) {
        mode = TravelMode.bicycle; // Treating as Motorcycle Taxi / Win in BKK
        duration = (dist / 250.0).ceil() + 2;
        calcFare = 15 + ((dist / 1000.0) * 10).ceil(); // Base Win Taxi
        action = 'Motorcycle Taxi';
      }

      return RouteSegment(
        mode: mode,
        start: a,
        end: b,
        distanceMeters: dist,
        durationMinutes: duration,
        fare: calcFare,
        instruction: '$action ${isStart ? 'to' : 'from'} ${anchorStop.name}',
      );
    }

    List<RouteSegment> synthesizeVirtualLegs(List<gtfs.Stop> transitCore) {
      final segments = _buildSegmentsFromStops(transitCore);

      if (startPoint.stopId == null && transitCore.isNotEmpty) {
        final firstStop = transitCore.first;
        segments.insert(
          0,
          createFirstLastMileLeg(
            startPoint,
            LocationPoint.fromStop(firstStop),
            isStart: true,
            anchorStop: firstStop,
          ),
        );
      }

      if (destPoint.stopId == null && transitCore.isNotEmpty) {
        final lastStop = transitCore.last;
        segments.add(
          createFirstLastMileLeg(
            LocationPoint.fromStop(lastStop),
            destPoint,
            isStart: false,
            anchorStop: lastStop,
          ),
        );
      }

      // Merge any consecutive walk segments into a single cohesive walk
      final merged = <RouteSegment>[];
      for (final seg in segments) {
        if (merged.isNotEmpty &&
            merged.last.mode == TravelMode.walk &&
            seg.mode == TravelMode.walk) {
          final last = merged.last;

          String? combinedInstruction = last.instruction;
          if (seg.instruction != null &&
              seg.instruction != 'Walk to transfer') {
            combinedInstruction = seg.instruction;
          } else if (last.instruction != null &&
              last.instruction!.startsWith('Walk to')) {
            combinedInstruction = 'Walk to ${seg.end.name}';
          }

          merged[merged.length - 1] = RouteSegment(
            mode: TravelMode.walk,
            start: last.start,
            end: seg.end,
            distanceMeters: last.distanceMeters + seg.distanceMeters,
            durationMinutes: last.durationMinutes + seg.durationMinutes,
            instruction: combinedInstruction,
          );
        } else {
          merged.add(seg);
        }
      }

      // Filter out pure 0-distance zero-minute segments at the ends or middle
      // (which sometimes get created by single-stop artifacts) unless it's literally the only segment.
      if (merged.length > 1) {
        merged.removeWhere(
          (s) =>
              s.mode == TravelMode.walk &&
              s.distanceMeters == 0 &&
              s.durationMinutes == 0,
        );
      }

      var finalSegments = merged.isNotEmpty ? merged : segments;
      bool changed = true;
      while (changed) {
        changed = false;
        for (int i = 0; i < finalSegments.length - 1; i++) {
          if (finalSegments[i].mode == TravelMode.transit &&
              finalSegments[i].routeShortName != null) {
            if (finalSegments[i + 1].mode == TravelMode.transit &&
                finalSegments[i].routeShortName ==
                    finalSegments[i + 1].routeShortName) {
              final s1 = finalSegments[i];
              final s2 = finalSegments[i + 1];

              final combinedStops = <gtfs.Stop>[];
              if (s1.intermediateStops != null) {
                combinedStops.addAll(s1.intermediateStops!);
              }
              if (s2.intermediateStops != null) {
                if (combinedStops.isNotEmpty &&
                    s2.intermediateStops!.isNotEmpty &&
                    combinedStops.last.stopId ==
                        s2.intermediateStops!.first.stopId) {
                  combinedStops.addAll(s2.intermediateStops!.sublist(1));
                } else {
                  combinedStops.addAll(s2.intermediateStops!);
                }
              }

              finalSegments[i] = RouteSegment(
                mode: TravelMode.transit,
                start: s1.start,
                end: s2.end,
                distanceMeters: s1.distanceMeters + s2.distanceMeters,
                durationMinutes: s1.durationMinutes + s2.durationMinutes,
                routeShortName: s1.routeShortName,
                shapeId: s1.shapeId ?? s2.shapeId,
                routeType: s1.routeType,
                intermediateStops: combinedStops,
              );
              finalSegments.removeAt(i + 1);
              changed = true;
              break;
            }

            if (i + 2 < finalSegments.length &&
                finalSegments[i + 1].mode == TravelMode.walk &&
                finalSegments[i + 2].mode == TravelMode.transit &&
                finalSegments[i].routeShortName ==
                    finalSegments[i + 2].routeShortName) {
              final s1 = finalSegments[i];
              final walk = finalSegments[i + 1];
              final s2 = finalSegments[i + 2];

              final combinedStops = <gtfs.Stop>[];
              if (s1.intermediateStops != null) {
                combinedStops.addAll(s1.intermediateStops!);
              }
              if (s2.intermediateStops != null) {
                if (combinedStops.isNotEmpty &&
                    s2.intermediateStops!.isNotEmpty &&
                    combinedStops.last.stopId ==
                        s2.intermediateStops!.first.stopId) {
                  combinedStops.addAll(s2.intermediateStops!.sublist(1));
                } else {
                  combinedStops.addAll(s2.intermediateStops!);
                }
              }

              finalSegments[i] = RouteSegment(
                mode: TravelMode.transit,
                start: s1.start,
                end: s2.end,
                distanceMeters:
                    s1.distanceMeters + walk.distanceMeters + s2.distanceMeters,
                durationMinutes:
                    s1.durationMinutes +
                    walk.durationMinutes +
                    s2.durationMinutes,
                routeShortName: s1.routeShortName,
                shapeId: s1.shapeId ?? s2.shapeId,
                routeType: s1.routeType,
                intermediateStops: combinedStops,
              );
              finalSegments.removeAt(i + 1);
              finalSegments.removeAt(i + 1);
              changed = true;
              break;
            }
          }
        }
      }

      return finalSegments;
    }

    void addOption(List<gtfs.Stop> stops, Set<String> tags) {
      if (stops.isEmpty || _containsLoop(stops)) return;
      final key = stops.map((s) => s.stopId).join('>');
      final entry = optionMap.putIfAbsent(
        key,
        () => _TaggedRoute(
          stops: List<gtfs.Stop>.from(stops),
          tags: tags,
          segments: synthesizeVirtualLegs(
            stops,
          ), // Bake in the multi-modal legs correctly
        ),
      );
      entry.tags.addAll(tags);
    }

    final multiRoutes = await _computeMultiModeRoutes(startStopId, destStopId);
    for (final route in multiRoutes) {
      addOption(route.stops, route.tags);
    }

    await Future.delayed(const Duration(milliseconds: 10));

    final selectedTrip = _findDirectTrip(
      stopTimes: stopTimes,
      tripMap: tripMap,
      routeIdToPrefixes: routeIdToPrefixes,
      startStopId: startStopId,
      destStopId: destStopId,
    );
    if (selectedTrip != null) {
      addOption(selectedTrip, {'Direct'});
    }

    await Future.delayed(const Duration(milliseconds: 10));

    final transferRoutes = await _generateTransferRoutes(
      stopTimes: stopTimes,
      tripMap: tripMap,
      routeIdToPrefixes: routeIdToPrefixes,
      startStopId: startStopId,
      destStopId: destStopId,
    );
    for (final route in transferRoutes) {
      addOption(route.stops, route.tags);
    }

    if (optionMap.isEmpty) {
      return DirectionResult.empty();
    }

    final metrics = <_RouteMetrics>[];
    for (final option in optionMap.values) {
      option.segments ??= _buildSegmentsFromStops(option.stops);

      bool matchesAllowedTypes = true;
      double totalWalkingDistance = 0.0;
      bool hasLongWalkSegment = false;
      for (final seg in option.segments!) {
        if (seg.mode == TravelMode.walk) {
          totalWalkingDistance += seg.distanceMeters;
          if (seg.distanceMeters > 1000) {
            hasLongWalkSegment = true;
          }
        }
        if (seg.mode == TravelMode.transit) {
          if (seg.isFerry && !allowedTransitTypes.contains('Ferry')) {
            matchesAllowedTypes = false;
            break;
          }
          if (seg.isBus && !allowedTransitTypes.contains('Bus')) {
            matchesAllowedTypes = false;
            break;
          }
          if (seg.isTrain && !allowedTransitTypes.contains('Train')) {
            matchesAllowedTypes = false;
            break;
          }
          if (seg.isMetro && !allowedTransitTypes.contains('Metro')) {
            matchesAllowedTypes = false;
            break;
          }
        }
      }
      if (!matchesAllowedTypes) continue;
      if (hasLongWalkSegment || totalWalkingDistance > 2000) continue;

      final distance = option.segments!.fold(
        0.0,
        (sum, seg) => sum + seg.distanceMeters,
      );
      final minutes = option.segments!.fold(
        0,
        (sum, seg) => sum + seg.durationMinutes,
      );

      final fareBreakdown = _fareCalculator.calculateFare(option.stops);

      for (final seg in option.segments!) {
        if (seg.isBus &&
            seg.routeShortName != null &&
            seg.routeShortName != 'BRT' &&
            seg.intermediateStops != null) {
          int sFare = _fareCalculator.getBusFare(
            seg.distanceMeters,
            seg.routeShortName!,
          );
          seg.fare = sFare;

          if (sFare > 0) {
            String subLabel = seg.instruction ?? 'Transit';
            fareBreakdown[subLabel] = (fareBreakdown[subLabel] ?? 0) + sFare;
            fareBreakdown['total'] = (fareBreakdown['total'] ?? 0) + sFare;
          }
        } else if (seg.mode == TravelMode.transit &&
            seg.intermediateStops != null) {
          seg.fare =
              _fareCalculator.calculateFare(seg.intermediateStops!)['total'] ??
              0;
        } else if (seg.fare > 0) {
          // If a pre-calculated non-transit fare exists
          String subLabel = seg.instruction ?? 'Transit';
          fareBreakdown[subLabel] = (fareBreakdown[subLabel] ?? 0) + seg.fare;
          fareBreakdown['total'] = (fareBreakdown['total'] ?? 0) + seg.fare;
        }
      }

      metrics.add(
        _RouteMetrics(
          route: option,
          distanceMeters: distance,
          minutes: minutes,
          fareBreakdown: fareBreakdown, // Now true integrated fare calculation
        ),
      );
    }
    if (metrics.isEmpty) {
      return DirectionResult.empty();
    }

    final minDistance = metrics.map((m) => m.distanceMeters).reduce(math.min);

    // Filter out options that are ridiculously long compared to the shortest route
    metrics.removeWhere((m) => m.distanceMeters > minDistance * 3);

    if (metrics.isEmpty) {
      return DirectionResult.empty();
    }

    final minFare = metrics.map((m) => m.fareTotal).reduce(math.min);
    final minMinutes = metrics.map((m) => m.minutes).reduce(math.min);

    // Calculate transfers and stops using actual segment counts
    final minTransfers = metrics
        .map((m) {
          return m.route.segments!
              .where((s) => s.mode == TravelMode.transit)
              .length;
        })
        .reduce(math.min);

    final minStops = metrics.map((m) => m.route.stops.length).reduce(math.min);

    for (final metric in metrics) {
      final route = metric.route;

      // Clean up previous dynamically generated heuristic tags if they are inaccurate
      route.tags.remove('Shortest');
      route.tags.remove('Fastest');
      route.tags.remove('Cheapest');
      route.tags.remove('Low transfers');
      route.tags.remove('Fewest stops');

      if (metric.fareTotal == minFare) route.tags.add('Cheapest');
      if (metric.distanceMeters == minDistance) route.tags.add('Shortest');
      if (metric.minutes == minMinutes) route.tags.add('Fastest');

      final transfers = route.segments!
          .where((s) => s.mode == TravelMode.transit)
          .length;
      if (transfers == minTransfers) route.tags.add('Low transfers');
      if (route.stops.length == minStops) route.tags.add('Fewest stops');
    }

    metrics.sort((a, b) {
      final aPriority = a.route.tags.contains(routingMode) ? 0 : 1;
      final bPriority = b.route.tags.contains(routingMode) ? 0 : 1;
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);

      final fareCompare = a.fareTotal.compareTo(b.fareTotal);
      if (fareCompare != 0) return fareCompare;

      final minuteCompare = a.minutes.compareTo(b.minutes);
      if (minuteCompare != 0) return minuteCompare;

      return a.distanceMeters.compareTo(b.distanceMeters);
    });

    final transitService = TransitUpdateService();

    final options = metrics.map((metric) {
      final segments = metric.route.segments!;

      bool optionHasIssue = false;
      String? optionIssueNotice;

      for (int i = 0; i < segments.length; i++) {
        final seg = segments[i];
        if (seg.mode == TravelMode.transit && seg.routeShortName != null) {
          final reports = transitService.getReportsForLine(seg.routeShortName!);
          if (reports.isNotEmpty) {
            final highestSeverity = reports.reduce(
              (r1, r2) => r1.severity > r2.severity ? r1 : r2,
            );
            segments[i] = RouteSegment(
              mode: seg.mode,
              start: seg.start,
              end: seg.end,
              distanceMeters: seg.distanceMeters,
              durationMinutes: seg.durationMinutes,
              fare: seg.fare,
              routeId: seg.routeId,
              routeShortName: seg.routeShortName,
              routeType: seg.routeType,
              instruction: seg.instruction,
              intermediateStops: seg.intermediateStops,
              roadPolyline: seg.roadPolyline,
              hasIssue: true,
              issueNotice: highestSeverity.title,
            );
            optionHasIssue = true;
            optionIssueNotice ??= highestSeverity.title;
          }
        }
      }

      return DirectionOption(
        segments: segments,
        tags: Set<String>.from(metric.route.tags),
        label: _optionLabelText(metric.route.tags),
        distanceMeters: metric.distanceMeters,
        minutes: metric.minutes,
        fareBreakdown: Map<String, int>.from(metric.fareBreakdown),
        hasIssue: optionHasIssue,
        issueNotice: optionIssueNotice,
      );
    }).toList();

    // Re-sort options to penalize ones with issues
    options.sort((a, b) {
      if (a.hasIssue && !b.hasIssue) return 1;
      if (!a.hasIssue && b.hasIssue) return -1;
      return 0; // Maintain previous relative order for ties in issue status
    });

    final List<DirectionOption> uniqueOptions = [];
    final Map<String, DirectionOption> sigMap = {};

    for (final opt in options) {
      final sigParts = opt.segments
          .where((s) => s.mode == TravelMode.transit)
          .map((seg) {
            final startId =
                seg.intermediateStops?.first.stopId ?? seg.start.name;
            final endId = seg.intermediateStops?.last.stopId ?? seg.end.name;
            return 'Transit(${seg.routeShortName})[$startId->$endId]';
          });
      final sig = sigParts.isEmpty ? 'WalkOnly' : sigParts.join('|');

      if (sigMap.containsKey(sig)) {
        sigMap[sig]!.tags.addAll(opt.tags);
        sigMap[sig]!.label = _optionLabelText(sigMap[sig]!.tags);
      } else {
        sigMap[sig] = opt;
        uniqueOptions.add(opt);
      }
    }

    if (uniqueOptions.isEmpty) {
      return DirectionResult.empty();
    }

    int selectionIndex = 0;

    String targetTag = routingMode;

    for (int i = 0; i < uniqueOptions.length; i++) {
      if (uniqueOptions[i].tags.contains(targetTag)) {
        selectionIndex = i;
        break;
      }
    }

    await _enrichSegmentsWithRoadRouting(uniqueOptions);
    await _enrichSegmentsWithTimetable(uniqueOptions);

    return DirectionResult(
      options: uniqueOptions,
      selectionIndex: selectionIndex,
    );
  }

  final Map<String, List<LocationPoint>> _osrmPolylineCache = {};
  final Map<String, double> _osrmDistCache = {};
  final Map<String, int> _osrmDurationCache = {};
  final Map<String, Future<void>> _osrmOngoingRequests = {};

  Future<void> _enrichSegmentsWithRoadRouting(
    List<DirectionOption> options,
  ) async {
    final List<Future<void>> routingTasks = [];
    for (final option in options) {
      for (final segment in option.segments) {
        if (segment.mode == TravelMode.walk ||
            segment.mode == TravelMode.bicycle ||
            segment.mode == TravelMode.taxi) {
          routingTasks.add(_fetchRoadRouting(segment));
        }
      }
    }
    try {
      await Future.wait(routingTasks).timeout(const Duration(seconds: 1));
    } catch (_) {}
  }

  Future<void> _fetchRoadRouting(RouteSegment segment) async {
    String baseUrl = 'https://router.project-osrm.org/route/v1/driving';
    if (segment.mode == TravelMode.walk) {
      baseUrl = 'https://routing.openstreetmap.de/routed-foot/route/v1/driving';
    } else if (segment.mode == TravelMode.bicycle) {
      baseUrl = 'https://routing.openstreetmap.de/routed-bike/route/v1/driving';
    }

    final List<String> coordsStrs = [];
    if (segment.mode == TravelMode.transit &&
        segment.intermediateStops != null &&
        segment.intermediateStops!.isNotEmpty) {
      final s = segment.intermediateStops!;
      int step = (s.length / 80).ceil();
      if (step < 1) step = 1;
      for (int i = 0; i < s.length; i += step) {
        coordsStrs.add('${s[i].lon},${s[i].lat}');
      }
      if ((s.length - 1) % step != 0) {
        coordsStrs.add('${s.last.lon},${s.last.lat}');
      }
    } else {
      coordsStrs.add('${segment.start.lon},${segment.start.lat}');
      coordsStrs.add('${segment.end.lon},${segment.end.lat}');
    }
    final coordsString = coordsStrs.join(';');

    final url = '$baseUrl/$coordsString?overview=full&geometries=geojson';

    if (_osrmOngoingRequests.containsKey(url)) {
      await _osrmOngoingRequests[url];
    }

    if (_osrmPolylineCache.containsKey(url)) {
      segment.roadPolyline = _osrmPolylineCache[url];
      if (segment.mode != TravelMode.transit) {
        if (_osrmDistCache.containsKey(url)) {
          segment.distanceMeters = _osrmDistCache[url]!;
        }
        if (_osrmDurationCache.containsKey(url)) {
          segment.durationMinutes = _osrmDurationCache[url]!;
        }
      }
      return;
    }

    final completer = Completer<void>();
    _osrmOngoingRequests[url] = completer.future;

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final geom = data['routes'][0]['geometry'];
          if (geom != null && geom['type'] == 'LineString') {
            final coords = geom['coordinates'] as List;
            final polyline = coords
                .map(
                  (c) => LocationPoint(
                    lat: c[1] as double,
                    lon: c[0] as double,
                    name: '',
                  ),
                )
                .toList();
            segment.roadPolyline = polyline;
            _osrmPolylineCache[url] = polyline;

            final dist = data['routes'][0]['distance'];
            final duration = data['routes'][0]['duration'];
            if (segment.mode != TravelMode.transit) {
              if (dist != null) {
                segment.distanceMeters = (dist as num).toDouble();
                _osrmDistCache[url] = segment.distanceMeters;
              }
              if (duration != null) {
                segment.durationMinutes = ((duration as num) / 60).ceil();
                _osrmDurationCache[url] = segment.durationMinutes;
              }
            }
          }
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      debugPrint("Error routing road: $e");
    } finally {
      completer.complete();
      _osrmOngoingRequests.remove(url);
    }
  }

  Future<void> _ensureGraphsBuilt() async {
    if (_graphBuilt) return;
    await _buildGraphs();
    _graphBuilt = true;
  }

  Future<void> _buildGraphs() async {
    try {
      final stopTimes = await _loadStopTimes();
      if (stopTimes.isEmpty) return;
      final tripMap = await loadTrips();

      for (final entry in stopTimes.entries) {
        final tripId = entry.key;
        final trip = tripMap[tripId];
        String? defaultLineName;
        if (trip != null) {
          final route = _routes.firstWhere(
            (r) => r.routeId == trip.routeId,
            orElse: () => gtfs.Route(
              routeId: '',
              shortName: '',
              longName: '',
              type: '',
              agencyId: '',
              linePrefixes: [],
            ),
          );
          if (route.routeId.isNotEmpty) {
            defaultLineName = route.longName.isNotEmpty
                ? route.longName
                : route.routeId;
          }
        }

        entry.value.sort(
          (a, b) =>
              (a['stopSequence'] as int).compareTo(b['stopSequence'] as int),
        );
        for (int j = 0; j < entry.value.length; j++) {
          entry.value[j]['lineName'] ??= defaultLineName;
        }
        for (int j = 0; j < entry.value.length - 1; j++) {
          final a = entry.value[j]['stopId'] as String;
          final b = entry.value[j + 1]['stopId'] as String;

          final lineName =
              entry.value[j]['lineName'] as String? ?? defaultLineName;

          final stopA =
              _stopLookup[a] ??
              _allStops.firstWhere(
                (s) => s.stopId == a,
                orElse: () => gtfs.Stop(stopId: a, name: a, lat: 0, lon: 0),
              );
          final stopB =
              _stopLookup[b] ??
              _allStops.firstWhere(
                (s) => s.stopId == b,
                orElse: () => gtfs.Stop(stopId: b, name: b, lat: 0, lon: 0),
              );
          // Ensure edges derived from trips are strictly directed (from stop i to stop i+1).
          // Do not add the reverse edge (b -> a) to avoid incorrect reverse routing.
          final dist = geo.haversine(
            stopA.lat,
            stopA.lon,
            stopB.lat,
            stopB.lon,
          );
          _distanceGraph.putIfAbsent(a, () => {})[b] = dist;
          final estMinutes = (dist / 800.0 * 2).clamp(1, 6).toInt();
          _timeGraph.putIfAbsent(a, () => {})[b] = estMinutes;

          _transitEdges.putIfAbsent(a, () => {}).putIfAbsent(b, () => {});
          if (lineName != null) {
            _transitEdges[a]![b]!.add(lineName);
          }
        }
      }
      _addTransferEdges();
    } catch (_) {}
  }

  void _addTransferEdges() {
    const double maxWalkTransferMeters =
        300.0; // 300m walk is standard max seamless transfer

    void storeEdge(String from, String to, double distStr, int minutes) {
      final existingD = _distanceGraph[from]?[to];
      if (existingD == null || distStr < existingD) {
        _distanceGraph.putIfAbsent(from, () => {})[to] = distStr;
        _distanceGraph.putIfAbsent(to, () => {})[from] = distStr;
      }
      final existingM = _timeGraph[from]?[to];
      if (existingM == null || minutes < existingM) {
        _timeGraph.putIfAbsent(from, () => {})[to] = minutes;
        _timeGraph.putIfAbsent(to, () => {})[from] = minutes;
      }
    }

    // 1. Hardcoded hubs for guaranteed complex intersections
    // They are physically connected, so low penalty
    for (final hubGroup in _transferHubs) {
      for (int i = 0; i < hubGroup.length; i++) {
        final fromStop = hubGroup[i];
        if (!_stopLookup.containsKey(fromStop)) continue;
        for (int j = i + 1; j < hubGroup.length; j++) {
          final toStop = hubGroup[j];
          if (!_stopLookup.containsKey(toStop)) continue;
          storeEdge(fromStop, toStop, 30.0, 3);
        }
      }
    }

    // 2. Dynamic Spatial Proximity (Less complicate, dynamic)
    // Connecting ANY two stops within 300 meters
    for (int i = 0; i < _allStops.length; i++) {
      final stopA = _allStops[i];
      for (int j = i + 1; j < _allStops.length; j++) {
        final stopB = _allStops[j];

        if (stopA.stopId == stopB.stopId) continue;

        // Quick lat/lon diff check to avoid thousands of haversine trig calls
        // 0.003 degrees is roughly 330m in latitude
        if ((stopA.lat - stopB.lat).abs() > 0.003 ||
            (stopA.lon - stopB.lon).abs() > 0.003) {
          continue;
        }

        final dist = geo.haversine(stopA.lat, stopA.lon, stopB.lat, stopB.lon);
        if (dist <= maxWalkTransferMeters) {
          // Dynamic calculation: distance / 80 meters per min + 2 mins wait/connection overhead
          final walkMinutes = (dist / 80.0).ceil() + 2;
          storeEdge(stopA.stopId, stopB.stopId, dist, walkMinutes);
        }
      }
    }
  }

  Map<String, List<Map<String, dynamic>>>? _cachedStopTimes;
  Map<String, gtfs.Trip>? _cachedTrips;

  Future<Map<String, List<Map<String, dynamic>>>> _loadStopTimes() async {
    if (_cachedStopTimes != null) {
      return _cachedStopTimes!;
    }

    final stopTimes = await _loadStopTimesFromAssets(_stopTimeAssets);

    try {
      final content = await gtfsSyncService.getGtfsFile(
        'assets/gtfs_data/bus_route_stop.txt',
      );
      final lines = const LineSplitter().convert(content);
      if (lines.length > 1) {
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trimRight();
          if (line.isEmpty) continue;
          final row = parseCsvLine(line);
          if (row.length > 5) {
            final busLineId = row[0].trim();
            final lineName = row[1].trim();
            // row[2] = description_bus, row[3] = type_id, row[4] = agency_id
            final tripId = 'BUS_$busLineId';
            int sequence = 1;
            for (int j = 6; j < row.length; j++) {
              final stopId = row[j].trim();
              if (stopId.isEmpty) continue;
              stopTimes.putIfAbsent(tripId, () => []).add({
                'stopId': stopId,
                'stopSequence': sequence++,
                'lineName': lineName,
              });
            }
          }
        }
      }
    } catch (_) {}

    _cachedStopTimes = stopTimes;
    return stopTimes;
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadStopTimesFromAssets(
    List<String> assets,
  ) async {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final asset in assets) {
      try {
        final content = await gtfsSyncService.getGtfsFile(asset);
        final parsed = await compute(_parseStopTimesIsolate, content);
        for (final e in parsed.entries) {
          result.putIfAbsent(e.key, () => []).addAll(e.value);
        }
      } catch (_) {
        continue;
      }
    }
    for (final entry in result.entries) {
      entry.value.sort(
        (a, b) =>
            (a['stopSequence'] as int).compareTo(b['stopSequence'] as int),
      );
    }
    return result;
  }

  Future<Map<String, gtfs.Trip>> loadTrips() async {
    if (_cachedTrips != null) {
      return _cachedTrips!;
    }

    try {
      final tripsContent = await gtfsSyncService.getGtfsFile(
        'assets/gtfs_data/trips.txt',
      );
      final lines = const LineSplitter().convert(tripsContent);
      if (lines.length <= 1) return {};
      final header = parseCsvLine(lines.first).map((s) => s.trim()).toList();
      final idxRouteId = header.indexOf('route_id');
      final idxTripId = header.indexOf('trip_id');
      final idxServiceId = header.indexOf('service_id');
      final idxHeadsign = header.indexOf('trip_headsign');
      final idxDirection = header.indexOf('direction_id');
      final idxShapeId = header.indexOf('shape_id');
      final idxShapeColor = header.indexWhere(
        (value) => value == 'shape_color' || value == 'shape-color',
      );
      if (idxRouteId < 0 || idxTripId < 0) {
        return {};
      }
      final result = <String, gtfs.Trip>{};
      for (int i = 1; i < lines.length; i++) {
        final row = parseCsvLine(lines[i]);
        if (row.length <= idxTripId || row.length <= idxRouteId) {
          continue;
        }
        final tripId = row[idxTripId].trim();
        final routeId = row[idxRouteId].trim();
        if (tripId.isEmpty || routeId.isEmpty) continue;
        final serviceId = (idxServiceId >= 0 && row.length > idxServiceId)
            ? row[idxServiceId].trim()
            : '';
        final headsign = (idxHeadsign >= 0 && row.length > idxHeadsign)
            ? row[idxHeadsign].trim()
            : '';
        final directionId = (idxDirection >= 0 && row.length > idxDirection)
            ? row[idxDirection].trim()
            : null;
        final shapeId = (idxShapeId >= 0 && row.length > idxShapeId)
            ? row[idxShapeId].trim()
            : null;
        final shapeColorStr = (idxShapeColor >= 0 && row.length > idxShapeColor)
            ? row[idxShapeColor].trim()
            : null;
        Color? shapeColor;
        if (shapeColorStr != null && shapeColorStr.isNotEmpty) {
          shapeColor = _parseHexColor(shapeColorStr);
        }
        final trip = gtfs.Trip(
          tripId: tripId,
          routeId: routeId,
          serviceId: serviceId,
          headsign: headsign,
          directionId: (directionId != null && directionId.isEmpty)
              ? null
              : directionId,
          shapeId: (shapeId != null && shapeId.isEmpty) ? null : shapeId,
          shapeColor: shapeColor,
        );
        result[tripId] = trip;
      }

      // Also append trips from bus_route_stop.txt
      try {
        final content = await gtfsSyncService.getGtfsFile(
          'assets/gtfs_data/bus_route_stop.txt',
        );
        final busLines = const LineSplitter().convert(content);
        if (busLines.length > 1) {
          for (int i = 1; i < busLines.length; i++) {
            final line = busLines[i].trimRight();
            if (line.isEmpty) continue;
            final row = parseCsvLine(line);
            if (row.length > 5) {
              final busLineId = row[0].trim();
              final routeShortName = row[1].trim();
              final headsign = row[2].trim(); // description_bus
              // row[3] = type_id, row[4] = agency_id
              final shapeIdRaw = row[5].trim();
              final routeId = routeShortName.split(' ').first;
              final tripId = 'BUS_$busLineId';
              result[tripId] = gtfs.Trip(
                tripId: tripId,
                routeId: routeId,
                serviceId: 'WKD',
                headsign: headsign,
                directionId: '0',
                shapeId: shapeIdRaw.isNotEmpty ? shapeIdRaw : null,
                shapeColor: null,
              );
            }
          }
        }
      } catch (_) {}

      // Add shapes for ferry and BRT
      final auxAssets = [
        'assets/gtfs_data/ferry_trips.txt',
        'assets/gtfs_data/brt_trips.txt',
      ];
      for (final asset in auxAssets) {
        try {
          final content = await gtfsSyncService.getGtfsFile(asset);
          final auxLines = const LineSplitter().convert(content);
          if (auxLines.length > 1) {
            for (int i = 1; i < auxLines.length; i++) {
              final line = auxLines[i].trimRight();
              if (line.isEmpty) continue;
              final row = parseCsvLine(line);
              if (row.length >= 2) {
                final tripId = row[0].trim();
                final shapeId = row[1].trim();
                if (tripId.isNotEmpty &&
                    shapeId.isNotEmpty &&
                    result.containsKey(tripId)) {
                  final oldTrip = result[tripId]!;
                  result[tripId] = gtfs.Trip(
                    tripId: oldTrip.tripId,
                    routeId: oldTrip.routeId,
                    serviceId: oldTrip.serviceId,
                    headsign: oldTrip.headsign,
                    directionId: oldTrip.directionId,
                    shapeId: shapeId,
                    shapeColor: oldTrip.shapeColor,
                  );
                }
              }
            }
          }
        } catch (_) {}
      }

      _cachedTrips = result;
      return result;
    } catch (_) {
      return {};
    }
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    var s = hex.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('#')) s = s.substring(1);
    try {
      if (s.length == 6) {
        return Color(int.parse('0xFF$s'));
      }
      if (s.length == 8) {
        return Color(int.parse('0x$s'));
      }
    } catch (_) {}
    return null;
  }

  (int, int)? _findBestSegmentIndices(
    List<Map<String, dynamic>> tripStops,
    String a,
    String b,
  ) {
    int bestI = -1;
    int bestJ = -1;
    int minSpan = 1 << 30;
    for (int i = 0; i < tripStops.length; i++) {
      if (tripStops[i]['stopId'] == a) {
        for (int j = i + 1; j < tripStops.length; j++) {
          if (tripStops[j]['stopId'] == b) {
            final seqI = tripStops[i]['stopSequence'] as int? ?? i;
            final seqJ = tripStops[j]['stopSequence'] as int? ?? j;
            if (seqI < seqJ) {
              final span = j - i;
              if (span < minSpan) {
                minSpan = span;
                bestI = i;
                bestJ = j;
              }
            }
          }
        }
      }
    }
    if (bestI != -1 && bestJ != -1) {
      return (bestI, bestJ);
    }
    return null;
  }

  List<gtfs.Stop>? _findDirectTrip({
    required Map<String, List<Map<String, dynamic>>> stopTimes,
    required Map<String, gtfs.Trip> tripMap,
    required Map<String, List<String>> routeIdToPrefixes,
    required String startStopId,
    required String destStopId,
  }) {
    final Map<String, List<String>> routePrefixes = routeIdToPrefixes;
    Set<String> candidateRouteIds = routePrefixes.keys.toSet();

    String? selectedTripId;
    int bestSpan = 1 << 30;
    for (final entry in stopTimes.entries) {
      final tripId = entry.key;
      final routeId = tripMap[tripId]?.routeId;
      if (routeId == null || !candidateRouteIds.contains(routeId)) continue;
      final tripStops = entry.value;
      final indices = _findBestSegmentIndices(
        tripStops,
        startStopId,
        destStopId,
      );
      if (indices != null) {
        final startIdx = indices.$1;
        final destIdx = indices.$2;
        final span = destIdx - startIdx;
        if (span < bestSpan) {
          bestSpan = span;
          selectedTripId = tripId;
        }
      }
    }
    if (selectedTripId == null) {
      bestSpan = 1 << 30;
      for (final entry in stopTimes.entries) {
        final tripStops = entry.value;
        final indices = _findBestSegmentIndices(
          tripStops,
          startStopId,
          destStopId,
        );
        if (indices != null) {
          final startIdx = indices.$1;
          final destIdx = indices.$2;
          final span = destIdx - startIdx;
          if (span < bestSpan) {
            bestSpan = span;
            selectedTripId = entry.key;
          }
        }
      }
    }
    if (selectedTripId == null) {
      return null;
    }
    final tripStops = stopTimes[selectedTripId];
    if (tripStops == null) return null;
    final indices = _findBestSegmentIndices(tripStops, startStopId, destStopId);
    if (indices == null) return null;
    final startIdx = indices.$1;
    final destIdx = indices.$2;
    final segment = tripStops.sublist(startIdx, destIdx + 1);
    final stopsList = segment.map((step) {
      final id = step['stopId'] as String;
      return _stopLookup[id] ??
          _allStops.firstWhere(
            (stop) => stop.stopId == id,
            orElse: () => gtfs.Stop(stopId: id, name: id, lat: 0, lon: 0),
          );
    }).toList();
    return stopsList;
  }

  Future<List<_TaggedRoute>> _computeMultiModeRoutes(
    String start,
    String dest,
  ) async {
    final nodes = {..._distanceGraph.keys, ..._timeGraph.keys};
    if (!nodes.contains(start) || !nodes.contains(dest)) {
      return [];
    }
    final Map<String, _TaggedRoute> routes = {};

    void addRoute(List<gtfs.Stop> stops, Set<String> tags) {
      if (stops.isEmpty) return;
      final key = stops.map((s) => s.stopId).join('>');
      final entry = routes.putIfAbsent(
        key,
        () => _TaggedRoute(stops: List<gtfs.Stop>.from(stops), tags: tags),
      );
      entry.tags.addAll(tags);
    }

    await Future.delayed(Duration.zero);
    final fewestStops = await _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 0.1,
      timeWeight: 0.1,
      transferPenalty: 8000,
    );
    addRoute(fewestStops, {'Fewest stops'});

    await Future.delayed(Duration.zero);
    final shortestDistance = await _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 1.0,
      timeWeight: 0.2,
    );
    addRoute(shortestDistance, {'Shortest'});

    await Future.delayed(Duration.zero);
    final fastest = await _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 0.1,
      timeWeight: 1.0,
    );
    addRoute(fastest, {'Fastest'});

    await Future.delayed(Duration.zero);
    final balanced = await _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 1.0,
      timeWeight: 1.0,
    );
    addRoute(balanced, {'Balanced'});

    await Future.delayed(Duration.zero);
    final lowTransfers = await _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 1.0,
      timeWeight: 0.4,
      transferPenalty: 4000,
    );
    addRoute(lowTransfers, {'Low transfers'});

    await Future.delayed(Duration.zero);
    final speedPriority = await _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 0.3,
      timeWeight: 1.2,
    );
    addRoute(speedPriority, {'Speed priority'});

    await Future.delayed(Duration.zero);
    final distancePriority = await _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 1.2,
      timeWeight: 0.3,
    );
    addRoute(distancePriority, {'Distance priority'});

    await Future.delayed(Duration.zero);
    final busPriority = await _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 1.0,
      timeWeight: 1.0,
      railCostPenalty: 5000.0,
    );
    addRoute(busPriority, {'Bus priority'});

    await Future.delayed(Duration.zero);
    final railPriority = await _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 1.0,
      timeWeight: 0.2, // fast rail
      busCostPenalty: 5000.0,
    );
    addRoute(railPriority, {'Rail priority'});

    final taggedRoutes = routes.values.toList();
    if (taggedRoutes.isEmpty) {
      return taggedRoutes;
    }

    int cheapestFare = 1 << 30;
    final fares = <_TaggedRoute, int>{};
    for (final route in taggedRoutes) {
      route.segments ??= _buildSegmentsFromStops(route.stops);
      int fare = _fareCalculator.calculateFare(route.stops)['total'] ?? 0;
      for (final seg in route.segments!) {
        if (seg.isBus &&
            seg.routeShortName != null &&
            seg.routeShortName != 'BRT' &&
            seg.intermediateStops != null) {
          int sFare = _fareCalculator.getBusFare(
            seg.distanceMeters,
            seg.routeShortName!,
          );
          seg.fare = sFare;
          fare += sFare;
        } else if (seg.mode == TravelMode.transit &&
            seg.intermediateStops != null) {
          seg.fare =
              _fareCalculator.calculateFare(seg.intermediateStops!)['total'] ??
              0;
        } else if (seg.fare > 0) {
          fare += seg.fare;
        }
      }
      fares[route] = fare;
      if (fare < cheapestFare) {
        cheapestFare = fare;
      }
    }
    for (final route in taggedRoutes) {
      if (fares[route] == cheapestFare) {
        route.tags.add('Cheapest');
      }

      final hasRail =
          route.segments?.any(
            (s) => s.mode == TravelMode.transit && (s.isTrain || s.isMetro),
          ) ??
          false;
      if (route.tags.contains('Rail priority') && !hasRail) {
        route.tags.remove('Rail priority');
      }

      final hasBus =
          route.segments?.any((s) => s.mode == TravelMode.transit && s.isBus) ??
          false;
      if (route.tags.contains('Bus priority') && !hasBus) {
        route.tags.remove('Bus priority');
      }
    }

    return taggedRoutes;
  }

  Future<List<_TaggedRoute>> _generateTransferRoutes({
    required Map<String, List<Map<String, dynamic>>> stopTimes,
    required Map<String, gtfs.Trip> tripMap,
    required Map<String, List<String>> routeIdToPrefixes,
    required String startStopId,
    required String destStopId,
  }) async {
    final List<_TaggedRoute> results = [];
    if (startStopId == destStopId) return results;

    List<Map<String, dynamic>>? findSegmentBetween(
      String a,
      String b,
      Set<String> allowedRouteIds,
    ) {
      List<Map<String, dynamic>>? bestSegment;
      int bestSpan = 1 << 30;
      for (final entry in stopTimes.entries) {
        final routeId = tripMap[entry.key]?.routeId;
        if (routeId == null || !allowedRouteIds.contains(routeId)) continue;
        final tripStops = entry.value;
        final indices = _findBestSegmentIndices(tripStops, a, b);
        if (indices == null) continue;
        final ia = indices.$1;
        final ib = indices.$2;
        final span = ib - ia;
        if (span < bestSpan) {
          bestSpan = span;
          bestSegment = tripStops.sublist(ia, ib + 1);
        }
      }
      return bestSegment;
    }

    String extractPrefix(String stopId) {
      if (stopId == 'CEN') return 'CEN';
      final buffer = StringBuffer();
      for (final ch in stopId.split('')) {
        if (RegExp(r'[A-Za-z]').hasMatch(ch)) {
          buffer.write(ch);
        } else {
          break;
        }
      }
      final prefix = buffer.toString();
      return prefix.isEmpty ? stopId : prefix;
    }

    final startPrefix = extractPrefix(startStopId);
    final destPrefix = extractPrefix(destStopId);

    Set<String> startRouteIds = {};
    Set<String> destRouteIds = {};
    for (final entry in routeIdToPrefixes.entries) {
      final prefixes = entry.value;
      if (prefixes.contains(startPrefix)) startRouteIds.add(entry.key);
      if (prefixes.contains(destPrefix)) destRouteIds.add(entry.key);
    }
    if (startRouteIds.isEmpty || destRouteIds.isEmpty) {
      final allRouteIds = routeIdToPrefixes.keys.toSet();
      if (startRouteIds.isEmpty) startRouteIds = allRouteIds;
      if (destRouteIds.isEmpty) destRouteIds = allRouteIds;
    }

    for (final hubGroup in _transferHubs) {
      await Future.delayed(Duration.zero);
      for (final hubA in hubGroup) {
        final seg1 = findSegmentBetween(startStopId, hubA, startRouteIds);
        if (seg1 == null) continue;
        for (final hubB in hubGroup) {
          final seg2 = findSegmentBetween(hubB, destStopId, destRouteIds);
          if (seg2 == null) continue;
          final merged = <Map<String, dynamic>>[...seg1];
          final dropDup =
              seg2.isNotEmpty &&
              merged.isNotEmpty &&
              seg2.first['stopId'] == merged.last['stopId'];
          merged.addAll(dropDup ? seg2.sublist(1) : seg2);
          final combinedStops = merged.map((step) {
            final stopId = step['stopId'] as String;
            return _stopLookup[stopId] ??
                _allStops.firstWhere(
                  (st) => st.stopId == stopId,
                  orElse: () =>
                      gtfs.Stop(stopId: stopId, name: stopId, lat: 0, lon: 0),
                );
          }).toList();
          final tags = <String>{'Transfer'};
          if (hubA == hubB) {
            tags.add('Single transfer');
          }
          final viaName = _stopLookup[hubA]?.name ?? _stopLookup[hubB]?.name;
          if (viaName != null) {
            tags.add('Via $viaName');
          }
          results.add(_TaggedRoute(stops: combinedStops, tags: tags));
        }
      }
    }

    return results;
  }

  Future<List<gtfs.Stop>> _dijkstraWeightedPath(
    String start,
    String dest, {
    double distanceWeight = 1.0,
    double timeWeight = 1.0,
    double transferPenalty = 1000.0,
    double busCostPenalty = 0.0,
    double railCostPenalty = 0.0,
  }) async {
    final nodes = {..._distanceGraph.keys, ..._timeGraph.keys};
    if (!nodes.contains(start) || !nodes.contains(dest)) {
      return [];
    }

    int getModePriority(String line) {
      if (line == 'START' || line == 'WALK') return 5;
      final lineType = getRouteTypeForLine(line);
      if (lineType == '4') return 4; // Ferry
      if (lineType == '3') return 3; // Bus
      if (lineType == '2') return 2; // Train (SRT Mainline)
      return 1; // Metro (1) or others
    }

    final distance = <String, double>{};
    final previous = <String, String?>{};
    // We import collection package at the top and add _DijkstraNode class at the bottom.
    final queue = PriorityQueue<_DijkstraNode>(
      (a, b) => a.cost.compareTo(b.cost),
    );

    final startState = "$start|START";
    distance[startState] = 0.0;
    queue.add(_DijkstraNode(start, "START", 0.0));

    String? bestDestState;
    double bestDestCost = double.infinity;

    int iterations = 0;

    while (queue.isNotEmpty) {
      if (++iterations % 2000 == 0) {
        await Future.delayed(Duration.zero);
      }

      final currentNode = queue.removeFirst();
      final currentStop = currentNode.stopId;
      final currentLine = currentNode.lineName;
      final currentDist = currentNode.cost;

      final currentState = "$currentStop|$currentLine";
      if (currentDist > (distance[currentState] ?? double.infinity)) continue;

      if (currentStop == dest) {
        if (currentDist < bestDestCost) {
          bestDestCost = currentDist;
          bestDestState = currentState;
        }
        break;
      }

      final neighborIds = <String>{};
      neighborIds.addAll(
        _distanceGraph[currentStop]?.keys ?? const Iterable.empty(),
      );
      neighborIds.addAll(
        _timeGraph[currentStop]?.keys ?? const Iterable.empty(),
      );

      for (final neighbor in neighborIds) {
        final edgeDistance =
            _distanceGraph[currentStop]?[neighbor] ??
            _distanceBetweenStops(currentStop, neighbor);
        if (edgeDistance <= 0) continue;
        final edgeTime =
            (_timeGraph[currentStop]?[neighbor]?.toDouble()) ??
            math.max(1, edgeDistance / 500.0);

        final baseEdgeCost =
            edgeDistance * distanceWeight + edgeTime * timeWeight;

        final rType = getRouteTypeForStop(neighbor);
        final isNeighborBus = rType == '3';

        double nodePenalty = 0.0;
        if (busCostPenalty > 0 && isNeighborBus) nodePenalty += busCostPenalty;
        if (railCostPenalty > 0 && !isNeighborBus) {
          nodePenalty += railCostPenalty;
        }

        final Set<String> transitLines =
            _transitEdges[currentStop]?[neighbor] ?? {};
        final bool hasTransitEdge = transitLines.isNotEmpty;

        List<String> validLines = [];
        if (hasTransitEdge) {
          validLines.addAll(transitLines);
          if (edgeDistance <= 500) {
            validLines.add('WALK');
          }
        } else {
          final neighborLinesStr =
              lineNameResolver(neighbor)?.split(', ') ?? [];
          validLines.addAll(neighborLinesStr);
          validLines.add('WALK');
        }

        validLines = validLines.toSet().toList();
        if (validLines.isEmpty) validLines = ['WALK'];

        for (final nLine in validLines) {
          double cost = currentDist + baseEdgeCost + nodePenalty;

          bool isTransfer = false;
          if (currentLine != 'START' &&
              currentLine != 'WALK' &&
              nLine != 'WALK' &&
              currentLine != nLine) {
            isTransfer = true;
          }
          if (nLine == 'WALK' &&
              currentLine != 'START' &&
              currentLine != 'WALK') {
            isTransfer = true;
          }
          if (currentLine == 'WALK' && nLine != 'WALK') {
            isTransfer = true;
          }

          if (isTransfer) {
            cost += transferPenalty > 0 ? transferPenalty : 200;

            int p1 = getModePriority(currentLine);
            int p2 = getModePriority(nLine);

            if (p2 > p1) {
              cost += 500;
            } else if (p2 < p1) {
              cost += 0;
            }

            if (p1 == p2 && currentLine != nLine) {
              cost += transferPenalty * 0.2;
            }
          }

          if (currentLine == 'WALK' && nLine == 'WALK') {
            cost += 2000;
          }
          if (nLine == 'WALK') {
            cost += baseEdgeCost * 3;
          }

          if (getModePriority(nLine) == 3) {
            cost += 50;
          }

          final nextState = "$neighbor|$nLine";
          if (cost < (distance[nextState] ?? double.infinity)) {
            distance[nextState] = cost;
            previous[nextState] = currentState;
            queue.add(_DijkstraNode(neighbor, nLine, cost));
          }
        }
      }
    }

    if (bestDestState == null) return [];

    final pathIds = <String>[];
    String? cursor = bestDestState;
    while (cursor != null) {
      final stopId = cursor.split('|')[0];
      if (pathIds.isEmpty || pathIds.last != stopId) {
        pathIds.add(stopId);
      }
      cursor = previous[cursor];
    }

    final reversed = pathIds.reversed.toList();
    return reversed
        .map(
          (id) =>
              _stopLookup[id] ??
              _allStops.firstWhere(
                (stop) => stop.stopId == id,
                orElse: () => gtfs.Stop(stopId: id, name: id, lat: 0, lon: 0),
              ),
        )
        .toList();
  }

  double _distanceBetweenStops(String a, String b) {
    final stopA = _stopLookup[a];
    final stopB = _stopLookup[b];
    if (stopA == null || stopB == null) {
      return 0;
    }
    return geo.haversine(stopA.lat, stopA.lon, stopB.lat, stopB.lon);
  }

  int _estimateRouteMinutes(List<gtfs.Stop> stops) {
    int total = 0;
    for (int i = 0; i < stops.length - 1; i++) {
      final fromId = stops[i].stopId;
      final toId = stops[i + 1].stopId;
      final segment = _timeGraph[fromId]?[toId];
      if (segment != null) {
        total += segment;
      } else {
        final distMeters = geo.haversine(
          stops[i].lat,
          stops[i].lon,
          stops[i + 1].lat,
          stops[i + 1].lon,
        );
        total += math.max(1, (distMeters / 500).round());
      }
    }
    return math.max(1, total);
  }

  String _optionLabelText(Set<String> tags) {
    if (tags.isEmpty) return 'Route';
    const priority = [
      'Shortest',
      'Fastest',
      'Cheapest',
      'Direct',
      'Balanced',
      'Low transfers',
      'Fewest stops',
      'Transfer',
    ];
    final ordered = <String>[];
    for (final item in priority) {
      if (tags.contains(item)) ordered.add(item);
    }
    final remaining = tags.where((tag) => !priority.contains(tag)).toList()
      ..sort();
    ordered.addAll(remaining);
    if (ordered.length == 1) return ordered.first;
    return ordered.take(3).join(' • ');
  }

  List<RouteSegment> _buildSegmentsFromStops(List<gtfs.Stop> stops) {
    if (stops.isEmpty) return [];

    final segments = <RouteSegment>[];
    int currentSegmentStartIndex = 0;

    String? getShapeForSegment(List<gtfs.Stop> segStops, String? lineName) {
      if (_cachedStopTimes == null ||
          _cachedTrips == null ||
          lineName == null ||
          segStops.isEmpty) {
        return null;
      }
      String? bestShape;
      int bestMatchCount = -1;

      for (final entry in _cachedStopTimes!.entries) {
        final tripId = entry.key;
        final trip = _cachedTrips![tripId];
        if (trip == null || trip.shapeId == null) continue;

        final tripStops = entry.value;
        if (tripStops.isEmpty) continue;

        int matchCount = 0;
        int currentTripIdx = 0;

        for (final stop in segStops) {
          int foundIdx = -1;
          for (int i = currentTripIdx; i < tripStops.length; i++) {
            if (tripStops[i]['stopId'] == stop.stopId &&
                tripStops[i]['lineName'] == lineName) {
              foundIdx = i;
              break;
            }
          }
          if (foundIdx != -1) {
            matchCount++;
            currentTripIdx = foundIdx + 1;
          }
        }

        if (matchCount > bestMatchCount && matchCount > 1) {
          bestMatchCount = matchCount;
          bestShape = trip.shapeId;
          if (bestMatchCount == segStops.length) {
            break;
          }
        }
      }
      return bestShape;
    }

    List<String> getLinesForStop(String stopId) {
      final lines = <String>{};

      // Add lines dynamically loaded from GTFS / bus_route_stop.txt
      final outgoing = _transitEdges[stopId];
      if (outgoing != null) {
        for (final edges in outgoing.values) {
          lines.addAll(edges);
        }
      }
      // Also check incoming edges if we want all lines for the stop
      for (final a in _transitEdges.keys) {
        final bEdges = _transitEdges[a]?[stopId];
        if (bEdges != null) {
          lines.addAll(bEdges);
        }
      }

      if (stopId.startsWith('ST_') ||
          stopId.startsWith('STOP_') ||
          int.tryParse(stopId) != null) {
        lines.add('BMTA Bus');
      }
      final r = lineNameResolver(stopId);
      if (r != null && r.isNotEmpty) {
        lines.addAll(r.split(', '));
      }

      // Fallback
      for (final route in _routes) {
        for (final pref in route.linePrefixes) {
          if (pref == stopId ||
              (stopId.startsWith(pref) &&
                  (pref == 'F_' || !pref.startsWith('F_')))) {
            lines.add(
              route.longName.isNotEmpty ? route.longName : route.routeId,
            );
            break;
          }
        }
      }
      return lines.toList();
    }

    String? _getBestLine(List<String> candidates, int startIndex) {
      if (candidates.isEmpty) return null;
      if (candidates.length == 1) return candidates.first;
      int bestReach = -1;
      String bestLine = candidates.first;
      for (final line in candidates) {
        int reach = 0;
        for (int k = startIndex; k < stops.length - 1; k++) {
          final s1 = stops[k].stopId;
          final s2 = stops[k + 1].stopId;
          final d = _transitEdges[s1]?[s2] ?? <String>{};
          if (d.isNotEmpty) {
            if (!d.contains(line)) break;
          } else {
            final a = getLinesForStop(s1);
            final b = getLinesForStop(s2);
            if (!a.contains(line) || !b.contains(line)) break;
          }
          reach++;
        }
        if (reach > bestReach) {
          bestReach = reach;
          bestLine = line;
        }
      }
      return bestLine;
    }

    String? currentLineName;
    if (stops.length > 1) {
      final a = getLinesForStop(stops[0].stopId);
      final b = getLinesForStop(stops[1].stopId);
      final shared = a.where((x) => b.contains(x)).toList();
      final directLines =
          _transitEdges[stops[0].stopId]?[stops[1].stopId] ?? {};
      final validShared = shared
          .where((x) => directLines.isEmpty || directLines.contains(x))
          .toList();
      currentLineName = validShared.isNotEmpty
          ? _getBestLine(validShared, 0)
          : (shared.isNotEmpty
                ? _getBestLine(shared, 0)
                : (a.isNotEmpty
                      ? _getBestLine(a.toList(), 0)
                      : lineNameResolver(stops[0].stopId)?.split(', ').first));
    } else {
      final a = getLinesForStop(stops[0].stopId);
      currentLineName = a.isNotEmpty
          ? a.first
          : lineNameResolver(stops[0].stopId)?.split(', ').first;
    }

    for (int i = 1; i < stops.length; i++) {
      final stop = stops[i];
      final prev = stops[i - 1];

      final a = getLinesForStop(prev.stopId);
      final b = getLinesForStop(stop.stopId);
      final shared = a.where((x) => b.contains(x)).toList();

      final Map<String, Set<String>>? edgeMap = _transitEdges[prev.stopId];
      final bool isDirectTransit = edgeMap?.containsKey(stop.stopId) ?? false;
      final Set<String> directLines = isDirectTransit
          ? (edgeMap![stop.stopId] ?? {})
          : {};

      // If there are specific lines that operate this physical transit edge, ensure the shared line is one of them.
      // If it's train/ferry (empty directLines but isDirectTransit), we assume all shared lines are good.
      bool hasValidLine = shared.isNotEmpty;
      if (isDirectTransit && directLines.isNotEmpty) {
        hasValidLine = shared.any((line) => directLines.contains(line));
      }

      if (!isDirectTransit || !hasValidLine) {
        // WALK TRANSFER! No common line or no physical transit connection.
        final subStops = stops.sublist(currentSegmentStartIndex, i);
        if (subStops.isNotEmpty) {
          segments.add(
            RouteSegment(
              mode: subStops.length > 1 ? TravelMode.transit : TravelMode.walk,
              start: LocationPoint.fromStop(subStops.first),
              end: LocationPoint.fromStop(subStops.last),
              distanceMeters: subStops.length > 1
                  ? geo.routeDistanceMeters(subStops)
                  : 0.0,
              durationMinutes: subStops.length > 1
                  ? _estimateRouteMinutes(subStops)
                  : 0,
              intermediateStops: subStops,
              routeShortName: currentLineName,
              shapeId: getShapeForSegment(subStops, currentLineName),
              routeType: currentLineName != null
                  ? getRouteTypeForLine(currentLineName)
                  : null,
            ),
          );
        }

        double dx = geo.haversine(prev.lat, prev.lon, stop.lat, stop.lon);
        segments.add(
          RouteSegment(
            mode: TravelMode.walk,
            start: LocationPoint.fromStop(prev),
            end: LocationPoint.fromStop(stop),
            distanceMeters: dx,
            durationMinutes: (dx / 80.0).ceil(),
            instruction: 'Walk to transfer',
          ),
        );
        currentSegmentStartIndex = i;
        if (i + 1 < stops.length) {
          final na = getLinesForStop(stop.stopId);
          final nb = getLinesForStop(stops[i + 1].stopId);
          final ns = na.where((x) => nb.contains(x)).toList();
          final nextDirectLines =
              _transitEdges[stop.stopId]?[stops[i + 1].stopId] ?? {};
          final validNs = ns
              .where(
                (x) => nextDirectLines.isEmpty || nextDirectLines.contains(x),
              )
              .toList();
          currentLineName = validNs.isNotEmpty
              ? _getBestLine(validNs, i)
              : (ns.isNotEmpty
                    ? _getBestLine(ns, i)
                    : (na.isNotEmpty
                          ? _getBestLine(na.toList(), i)
                          : lineNameResolver(stop.stopId)?.split(', ').first));
        } else {
          final na = getLinesForStop(stop.stopId);
          currentLineName = na.isNotEmpty
              ? na.first
              : lineNameResolver(stop.stopId)?.split(', ').first;
        }
      } else {
        // We already verified via hasValidLine that `shared` containing valid lines for this edge isn't empty (if directLines not empty).
        // Try to keep currentLineName if it's legally valid.
        String? edgeLine;
        if (currentLineName != null &&
            shared.contains(currentLineName) &&
            (directLines.isEmpty || directLines.contains(currentLineName))) {
          edgeLine = currentLineName;
        } else {
          final validShared = shared
              .where((x) => directLines.isEmpty || directLines.contains(x))
              .toList();
          edgeLine = validShared.isNotEmpty
              ? _getBestLine(validShared, i - 1)
              : _getBestLine(shared, i - 1);
        }

        if (edgeLine != currentLineName) {
          final subStops = stops.sublist(currentSegmentStartIndex, i);
          if (subStops.isNotEmpty) {
            segments.add(
              RouteSegment(
                mode: subStops.length > 1
                    ? TravelMode.transit
                    : TravelMode.walk,
                start: LocationPoint.fromStop(subStops.first),
                end: LocationPoint.fromStop(subStops.last),
                distanceMeters: subStops.length > 1
                    ? geo.routeDistanceMeters(subStops)
                    : 0.0,
                durationMinutes: subStops.length > 1
                    ? _estimateRouteMinutes(subStops)
                    : 0,
                intermediateStops: subStops,
                routeShortName: currentLineName,
                shapeId: getShapeForSegment(subStops, currentLineName),
                routeType: currentLineName != null
                    ? getRouteTypeForLine(currentLineName)
                    : null,
              ),
            );
          }
          currentSegmentStartIndex = i - 1;
          currentLineName = edgeLine;
        }
      }
    }

    if (currentSegmentStartIndex < stops.length) {
      final remainingStops = stops.sublist(currentSegmentStartIndex);
      if (remainingStops.length > 1) {
        segments.add(
          RouteSegment(
            mode: TravelMode.transit,
            start: LocationPoint.fromStop(remainingStops.first),
            end: LocationPoint.fromStop(remainingStops.last),
            distanceMeters: geo.routeDistanceMeters(remainingStops),
            durationMinutes: _estimateRouteMinutes(remainingStops),
            intermediateStops: remainingStops,
            routeShortName: currentLineName,
            shapeId: getShapeForSegment(remainingStops, currentLineName),
            routeType: currentLineName != null
                ? getRouteTypeForLine(currentLineName)
                : null,
          ),
        );
      } else if (remainingStops.length == 1 && segments.isEmpty) {
        // Edge case: entire route is a single stop
        segments.add(
          RouteSegment(
            mode: TravelMode.walk,
            start: LocationPoint.fromStop(remainingStops.first),
            end: LocationPoint.fromStop(remainingStops.last),
            distanceMeters: 0,
            durationMinutes: 0,
            intermediateStops: remainingStops,
            routeShortName: currentLineName,
            shapeId: getShapeForSegment(remainingStops, currentLineName),
            routeType: currentLineName != null
                ? getRouteTypeForLine(currentLineName)
                : null,
          ),
        );
      }
    }

    return segments;
  }

  bool _containsLoop(List<gtfs.Stop> stops) {
    final seen = <String>{};
    for (final stop in stops) {
      if (!seen.add(stop.stopId)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _enrichSegmentsWithTimetable(
    List<DirectionOption> options,
  ) async {
    for (final option in options) {
      for (final segment in option.segments) {
        if (segment.mode == TravelMode.transit) {
          final stopMatch = _allStops
              .where(
                (s) =>
                    s.name == segment.start.name || s.lat == segment.start.lat,
              )
              .toList();

          if (stopMatch.isNotEmpty) {
            final stopId = stopMatch.first.stopId;
            try {
              final entries = await TimetableService.getTimetableForStop(
                stopId,
              );
              if (entries.isNotEmpty) {
                final now = DateTime.now();
                final currentTimeString =
                    '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

                TimetableEntry? nextMatch;
                for (var e in entries) {
                  if (e.isFrequency) {
                    if (e.startTime != null &&
                        e.endTime != null &&
                        currentTimeString.compareTo(e.startTime!) >= 0 &&
                        currentTimeString.compareTo(e.endTime!) <= 0) {
                      nextMatch = e;
                      break;
                    }
                  } else {
                    if (e.departureTime.isNotEmpty &&
                        e.departureTime.compareTo(currentTimeString) >= 0) {
                      if (nextMatch == null ||
                          e.departureTime.compareTo(nextMatch.departureTime) <
                              0) {
                        nextMatch = e;
                      }
                    }
                  }
                }

                if (nextMatch != null) {
                  if (nextMatch.isFrequency) {
                    segment.frequencyInfo =
                        'Every ${nextMatch.headwaySecs != null ? nextMatch.headwaySecs! ~/ 60 : "?"} mins';
                  } else {
                    final parts = nextMatch.departureTime.split(':');
                    segment.nextDepartureTime =
                        '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
                  }
                }
              }
            } catch (_) {}
          }
        }
      }
    }
  }
}

class _TaggedRoute {
  _TaggedRoute({required this.stops, this.segments, Set<String>? tags})
    : tags = tags != null ? {...tags} : <String>{};

  final List<gtfs.Stop> stops;
  List<RouteSegment>? segments;
  final Set<String> tags;
}

class _RouteMetrics {
  _RouteMetrics({
    required this.route,
    required this.distanceMeters,
    required this.minutes,
    required this.fareBreakdown,
  });

  final _TaggedRoute route;
  final double distanceMeters;
  final int minutes;
  final Map<String, int> fareBreakdown;

  int get fareTotal => fareBreakdown['total'] ?? 0;
}
