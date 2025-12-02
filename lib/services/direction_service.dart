import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'package:route/services/csv_utils.dart';
import 'package:route/services/fare_calculator.dart';
import 'package:route/services/geo_utils.dart' as geo;
import 'package:route/services/gtfs_models.dart' as gtfs;
import 'package:flutter/material.dart';

typedef LineNameResolver = String? Function(String stopId);

class DirectionOption {
  DirectionOption({
    required this.stops,
    required this.tags,
    required this.label,
    required this.distanceMeters,
    required this.minutes,
    required this.fareBreakdown,
  });

  final List<gtfs.Stop> stops;
  final Set<String> tags;
  final String label;
  final double distanceMeters;
  final int minutes;
  final Map<String, int> fareBreakdown;
}

class DirectionResult {
  DirectionResult({
    required this.options,
    required this.selectionIndex,
  });

  final List<DirectionOption> options;
  final int selectionIndex;

  factory DirectionResult.empty() => DirectionResult(
        options: const [],
        selectionIndex: 0,
      );
}

class DirectionService {
  DirectionService({required this.lineNameResolver});

  final LineNameResolver lineNameResolver;

  List<gtfs.Stop> _allStops = const [];
  Map<String, gtfs.Stop> _stopLookup = const {};
  List<gtfs.Route> _routes = const [];
  final FareCalculator _fareCalculator = FareCalculator();

  static const List<List<String>> _transferHubs = [
    ['CEN'],
    ['S7', 'G1'],
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
  ];

  final Map<String, Map<String, double>> _distanceGraph = {};
  final Map<String, Map<String, int>> _timeGraph = {};
  bool _graphBuilt = false;

  void updateData({
    List<gtfs.Stop>? allStops,
    Map<String, gtfs.Stop>? stopLookup,
    List<gtfs.Route>? routes,
    Map<String, String>? fareTypeMap,
    Map<String, int>? fareDataMap,
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
    if (fareTypeMap != null || fareDataMap != null) {
      _fareCalculator.updateData(
        fareTypeMap: fareTypeMap,
        fareDataMap: fareDataMap,
      );
    }
    if (resetGraphs) {
      _graphBuilt = false;
      _distanceGraph.clear();
      _timeGraph.clear();
    }
  }

  Future<DirectionResult> findDirections({
    required String routingMode,
    required String startStopId,
    required String destStopId,
  }) async {
    if (startStopId.isEmpty || destStopId.isEmpty) {
      return DirectionResult.empty();
    }
    if (!_stopLookup.containsKey(startStopId) ||
        !_stopLookup.containsKey(destStopId) ||
        _allStops.isEmpty) {
      return DirectionResult.empty();
    }
    if (startStopId == destStopId) {
      return DirectionResult.empty();
    }

    await _ensureGraphsBuilt();

    final stopTimes = await _loadStopTimes();
    if (stopTimes.isEmpty) {
      return DirectionResult.empty();
    }
    final tripMap = await loadTrips();
    final routeIdToPrefixes = {
      for (final route in _routes) route.routeId: route.linePrefixes,
    };

    final Map<String, _TaggedRoute> optionMap = {};
    void addOption(List<gtfs.Stop> stops, Set<String> tags) {
      if (stops.isEmpty || _containsLoop(stops)) return;
      final key = stops.map((s) => s.stopId).join('>');
      final entry = optionMap.putIfAbsent(
        key,
        () => _TaggedRoute(stops: List<gtfs.Stop>.from(stops), tags: tags),
      );
      entry.tags.addAll(tags);
    }

    final multiRoutes = _computeMultiModeRoutes(startStopId, destStopId);
    for (final route in multiRoutes) {
      addOption(route.stops, route.tags);
    }

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

    final transferRoutes = _generateTransferRoutes(
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
  final distance = geo.routeDistanceMeters(option.stops);
      final minutes = _estimateRouteMinutes(option.stops);
      final fare = _fareCalculator.calculateFare(
        option.stops,
        lineNameResolver: lineNameResolver,
      );
      metrics.add(
        _RouteMetrics(
          route: option,
          distanceMeters: distance,
          minutes: minutes,
          fareBreakdown: fare,
        ),
      );
    }
    if (metrics.isEmpty) {
      return DirectionResult.empty();
    }

    final minFare = metrics.map((m) => m.fareTotal).reduce(math.min);
    final minDistance = metrics.map((m) => m.distanceMeters).reduce(math.min);
    final minMinutes = metrics.map((m) => m.minutes).reduce(math.min);

    for (final metric in metrics) {
      if (metric.fareTotal == minFare) {
        metric.route.tags.add('Cheapest');
      }
      if (metric.distanceMeters == minDistance) {
        metric.route.tags.add('Shortest');
      }
      if (metric.minutes == minMinutes) {
        metric.route.tags.add('Fastest');
      }
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

    final options = metrics
        .map(
          (metric) => DirectionOption(
            stops: List<gtfs.Stop>.from(metric.route.stops),
            tags: Set<String>.from(metric.route.tags),
            label: _optionLabelText(metric.route.tags),
            distanceMeters: metric.distanceMeters,
            minutes: metric.minutes,
            fareBreakdown: Map<String, int>.from(metric.fareBreakdown),
          ),
        )
        .toList();

    if (options.isEmpty) {
      return DirectionResult.empty();
    }

    int selectionIndex = 0;
    for (int i = 0; i < options.length; i++) {
      if (options[i].tags.contains(routingMode)) {
        selectionIndex = i;
        break;
      }
    }

    return DirectionResult(options: options, selectionIndex: selectionIndex);
  }

  Future<void> _ensureGraphsBuilt() async {
    if (_graphBuilt) return;
    await _buildGraphs();
    _graphBuilt = true;
  }

  Future<void> _buildGraphs() async {
    try {
      final stopTimesContent = await rootBundle.loadString(
        'assets/gtfs_data/stop_times.txt',
      );
      final lines = const LineSplitter().convert(stopTimesContent);
      if (lines.length <= 1) return;
      final header = parseCsvLine(lines.first).map((s) => s.trim()).toList();
      final idxTrip = header.indexOf('trip_id');
      final idxStop = header.indexOf('stop_id');
      final idxSeq = header.indexOf('stop_sequence');
      final tripMap = <String, List<Map<String, dynamic>>>{};
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = parseCsvLine(line);
        if (row.length <= idxTrip ||
            row.length <= idxStop ||
            row.length <= idxSeq ||
            idxTrip < 0 ||
            idxStop < 0 ||
            idxSeq < 0) {
          continue;
        }
        final tripId = row[idxTrip].trim();
        final stopId = row[idxStop].trim();
        final seq = int.tryParse(row[idxSeq].trim()) ?? i;
        tripMap.putIfAbsent(tripId, () => []).add({
          'stopId': stopId,
          'seq': seq,
        });
      }
      for (final entry in tripMap.entries) {
        entry.value.sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
        for (int j = 0; j < entry.value.length - 1; j++) {
          final a = entry.value[j]['stopId'] as String;
          final b = entry.value[j + 1]['stopId'] as String;
          final stopA = _stopLookup[a] ??
              _allStops.firstWhere(
                (s) => s.stopId == a,
                orElse: () => gtfs.Stop(stopId: a, name: a, lat: 0, lon: 0),
              );
          final stopB = _stopLookup[b] ??
              _allStops.firstWhere(
                (s) => s.stopId == b,
                orElse: () => gtfs.Stop(stopId: b, name: b, lat: 0, lon: 0),
              );
          final dist = geo.haversine(stopA.lat, stopA.lon, stopB.lat, stopB.lon);
          _distanceGraph.putIfAbsent(a, () => {})[b] = dist;
          _distanceGraph.putIfAbsent(b, () => {})[a] = dist;
          final estMinutes = (dist / 800.0 * 2).clamp(1, 6).toInt();
          _timeGraph.putIfAbsent(a, () => {})[b] = estMinutes;
          _timeGraph.putIfAbsent(b, () => {})[a] = estMinutes;
        }
      }
      _addTransferEdges();
    } catch (_) {}
  }

  void _addTransferEdges() {
    const double transferDistanceMeters = 30.0;
    const int transferMinutes = 3;

    void storeEdge(String from, String to) {
      final existingDistance = _distanceGraph[from]?[to];
      if (existingDistance == null || transferDistanceMeters < existingDistance) {
        _distanceGraph.putIfAbsent(from, () => {})[to] = transferDistanceMeters;
      }
      final existingMinutes = _timeGraph[from]?[to];
      if (existingMinutes == null || transferMinutes < existingMinutes) {
        _timeGraph.putIfAbsent(from, () => {})[to] = transferMinutes;
      }
    }

    for (final hubGroup in _transferHubs) {
      for (int i = 0; i < hubGroup.length; i++) {
        final fromStop = hubGroup[i];
        if (!_stopLookup.containsKey(fromStop)) continue;
        for (int j = i + 1; j < hubGroup.length; j++) {
          final toStop = hubGroup[j];
          if (!_stopLookup.containsKey(toStop)) continue;
          storeEdge(fromStop, toStop);
          storeEdge(toStop, fromStop);
        }
      }
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadStopTimes() async {
    try {
      final content = await rootBundle.loadString(
        'assets/gtfs_data/stop_times.txt',
      );
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return {};
      final header = parseCsvLine(lines.first).map((s) => s.trim()).toList();
      final idxTripId = header.indexOf('trip_id');
      final idxStopId = header.indexOf('stop_id');
      final idxStopSeq = header.indexOf('stop_sequence');
      if (idxTripId < 0 || idxStopId < 0 || idxStopSeq < 0) {
        return {};
      }
      final result = <String, List<Map<String, dynamic>>>{};
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
      for (final entry in result.entries) {
        entry.value.sort((a, b) =>
            (a['stopSequence'] as int).compareTo(b['stopSequence'] as int));
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, gtfs.Trip>> loadTrips() async {
    try {
      final tripsContent = await rootBundle.loadString(
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

  List<gtfs.Stop>? _findDirectTrip({
    required Map<String, List<Map<String, dynamic>>> stopTimes,
    required Map<String, gtfs.Trip> tripMap,
    required Map<String, List<String>> routeIdToPrefixes,
    required String startStopId,
    required String destStopId,
  }) {
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
      return buffer.toString();
    }

    final startPrefix = extractPrefix(startStopId);
    final destPrefix = extractPrefix(destStopId);

    final Map<String, List<String>> routePrefixes = routeIdToPrefixes;
    Set<String> candidateRouteIds = {};
    final bool prefersSukhumvit =
        (startPrefix == 'N' || startPrefix == 'E') ||
        (destPrefix == 'N' || destPrefix == 'E');
    final bool prefersSilom =
        (startPrefix == 'W' || startPrefix == 'S') ||
        (destPrefix == 'W' || destPrefix == 'S');
    if (prefersSukhumvit && !prefersSilom) {
      for (final entry in routePrefixes.entries) {
        final prefixes = entry.value;
        if (prefixes.contains('N') || prefixes.contains('E')) {
          candidateRouteIds.add(entry.key);
        }
      }
    } else if (prefersSilom && !prefersSukhumvit) {
      for (final entry in routePrefixes.entries) {
        final prefixes = entry.value;
        if (prefixes.contains('W') || prefixes.contains('S')) {
          candidateRouteIds.add(entry.key);
        }
      }
    } else {
      candidateRouteIds = routePrefixes.keys.toSet();
    }

    String? selectedTripId;
    int bestSpan = -1;
    for (final entry in stopTimes.entries) {
      final tripId = entry.key;
      final routeId = tripMap[tripId]?.routeId;
      if (routeId == null || !candidateRouteIds.contains(routeId)) continue;
      final tripStops = entry.value;
      final startIdx = tripStops.indexWhere((s) => s['stopId'] == startStopId);
      final destIdx = tripStops.indexWhere((s) => s['stopId'] == destStopId);
      if (startIdx != -1 && destIdx != -1) {
        final span = (destIdx - startIdx).abs();
        if (span > bestSpan) {
          bestSpan = span;
          selectedTripId = tripId;
        }
      }
    }
    if (selectedTripId == null) {
      bestSpan = -1;
      for (final entry in stopTimes.entries) {
        final tripStops = entry.value;
        final startIdx = tripStops.indexWhere((s) => s['stopId'] == startStopId);
        final destIdx = tripStops.indexWhere((s) => s['stopId'] == destStopId);
        if (startIdx != -1 && destIdx != -1) {
          final span = (destIdx - startIdx).abs();
          if (span > bestSpan) {
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
    final startIdx = tripStops.indexWhere((s) => s['stopId'] == startStopId);
    final destIdx = tripStops.indexWhere((s) => s['stopId'] == destStopId);
    if (startIdx == -1 || destIdx == -1) return null;
    final segment = startIdx <= destIdx
        ? tripStops.sublist(startIdx, destIdx + 1)
        : tripStops.sublist(destIdx, startIdx + 1).reversed.toList();
    final stopsList = segment
        .map(
          (step) {
            final id = step['stopId'] as String;
            return _stopLookup[id] ??
                _allStops.firstWhere(
                  (stop) => stop.stopId == id,
                  orElse: () =>
                      gtfs.Stop(stopId: id, name: id, lat: 0, lon: 0),
                );
          },
        )
        .toList();
    return stopsList;
  }

  List<_TaggedRoute> _computeMultiModeRoutes(String start, String dest) {
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

    final fewestStops = _bfsPath(start, dest);
    addRoute(fewestStops, {'Fewest stops'});

    final shortestDistance = _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 1.0,
      timeWeight: 0.2,
    );
    addRoute(shortestDistance, {'Shortest'});

    final fastest = _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 0.1,
      timeWeight: 1.0,
    );
    addRoute(fastest, {'Fastest'});

    final balanced = _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 1.0,
      timeWeight: 1.0,
    );
    addRoute(balanced, {'Balanced'});

    final lowTransfers = _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 1.0,
      timeWeight: 0.4,
      transferPenalty: 4000,
    );
    addRoute(lowTransfers, {'Low transfers'});

    final speedPriority = _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 0.3,
      timeWeight: 1.2,
    );
    addRoute(speedPriority, {'Speed priority'});

    final distancePriority = _dijkstraWeightedPath(
      start,
      dest,
      distanceWeight: 1.2,
      timeWeight: 0.3,
    );
    addRoute(distancePriority, {'Distance priority'});

    final taggedRoutes = routes.values.toList();
    if (taggedRoutes.isEmpty) {
      return taggedRoutes;
    }

    int cheapestFare = 1 << 30;
    final fares = <_TaggedRoute, int>{};
    for (final route in taggedRoutes) {
      final fare = _fareCalculator.calculateFare(
        route.stops,
        lineNameResolver: lineNameResolver,
      )['total'] ?? 0;
      fares[route] = fare;
      if (fare < cheapestFare) {
        cheapestFare = fare;
      }
    }
    for (final route in taggedRoutes) {
      if (fares[route] == cheapestFare) {
        route.tags.add('Cheapest');
      }
    }

    return taggedRoutes;
  }

  List<_TaggedRoute> _generateTransferRoutes({
    required Map<String, List<Map<String, dynamic>>> stopTimes,
    required Map<String, gtfs.Trip> tripMap,
    required Map<String, List<String>> routeIdToPrefixes,
    required String startStopId,
    required String destStopId,
  }) {
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
        final ia = tripStops.indexWhere((s) => s['stopId'] == a);
        final ib = tripStops.indexWhere((s) => s['stopId'] == b);
        if (ia == -1 || ib == -1) continue;
        final lo = ia < ib ? ia : ib;
        final hi = ia < ib ? ib : ia;
        final span = hi - lo;
        if (span < bestSpan) {
          bestSpan = span;
          final seg = tripStops.sublist(lo, hi + 1);
          bestSegment = ia <= ib ? seg : seg.reversed.toList();
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

  List<gtfs.Stop> _bfsPath(String start, String dest) {
    final queue = <String>[start];
    final prev = <String, String?>{start: null};
    int head = 0;
    while (head < queue.length) {
      final current = queue[head++];
      if (current == dest) break;
      final neighbors =
          _distanceGraph[current]?.keys ?? const Iterable<String>.empty();
      for (final neighbor in neighbors) {
        if (!prev.containsKey(neighbor)) {
          prev[neighbor] = current;
          queue.add(neighbor);
        }
      }
    }
    if (!prev.containsKey(dest)) return [];
    final pathIds = <String>[];
    String? cursor = dest;
    while (cursor != null) {
      pathIds.add(cursor);
      cursor = prev[cursor];
    }
    final reversed = pathIds.reversed.toList();
    return reversed
        .map(
          (id) => _stopLookup[id] ??
              _allStops.firstWhere(
                (stop) => stop.stopId == id,
                orElse: () => gtfs.Stop(stopId: id, name: id, lat: 0, lon: 0),
              ),
        )
        .toList();
  }

  List<gtfs.Stop> _dijkstraWeightedPath(
    String start,
    String dest, {
    double distanceWeight = 1.0,
    double timeWeight = 1.0,
    double transferPenalty = 0.0,
  }) {
    final nodes = {..._distanceGraph.keys, ..._timeGraph.keys};
    if (!nodes.contains(start) || !nodes.contains(dest)) {
      return [];
    }
    final distance = <String, double>{
      for (final node in nodes) node: double.infinity,
    };
    final previous = <String, String?>{};
    final visited = <String>{};
    distance[start] = 0;

    while (true) {
      String? current;
      double best = double.infinity;
      for (final entry in distance.entries) {
        if (!visited.contains(entry.key) && entry.value < best) {
          best = entry.value;
          current = entry.key;
        }
      }
      if (current == null) break;
      if (current == dest) break;
      visited.add(current);

      final neighborIds = <String>{};
      neighborIds.addAll(_distanceGraph[current]?.keys ?? const Iterable.empty());
      neighborIds.addAll(_timeGraph[current]?.keys ?? const Iterable.empty());
      for (final neighbor in neighborIds) {
        final edgeDistance =
            _distanceGraph[current]?[neighbor] ??
            _distanceBetweenStops(current, neighbor);
        if (edgeDistance <= 0) continue;
        final edgeTime = (_timeGraph[current]?[neighbor]?.toDouble()) ??
            math.max(1, edgeDistance / 500.0);
        double edgeCost =
            edgeDistance * distanceWeight + edgeTime * timeWeight;
        if (transferPenalty > 0) {
          final currentLine = lineNameResolver(current);
          final neighborLine = lineNameResolver(neighbor);
          if (currentLine != null &&
              neighborLine != null &&
              currentLine != neighborLine) {
            edgeCost += transferPenalty;
          }
        }
        final candidate = distance[current]! + edgeCost;
        if (candidate < (distance[neighbor] ?? double.infinity)) {
          distance[neighbor] = candidate;
          previous[neighbor] = current;
        }
      }
    }

    final finalDistance = distance[dest];
    if (finalDistance == null || finalDistance == double.infinity) {
      return [];
    }

    final path = <String>[];
    String? cursor = dest;
    while (cursor != null) {
      path.add(cursor);
      cursor = previous[cursor];
    }
    final reversed = path.reversed.toList();
    return reversed
        .map(
          (id) => _stopLookup[id] ??
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

  bool _containsLoop(List<gtfs.Stop> stops) {
    final seen = <String>{};
    for (final stop in stops) {
      if (!seen.add(stop.stopId)) {
        return true;
      }
    }
    return false;
  }

}

class _TaggedRoute {
  _TaggedRoute({required this.stops, Set<String>? tags})
    : tags = tags != null ? {...tags} : <String>{};

  final List<gtfs.Stop> stops;
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
