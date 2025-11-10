import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:math' as math;
import 'gtfs_models.dart' as gtfs;
import 'transport_lines_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
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

class _MyHomePageState extends State<MyHomePage> {
  final MapController _mapController = MapController();
  List<gtfs.Stop> allStops = [];
  Map<String, gtfs.Stop> stopLookup = {};

  Map<String, List<String>> linePrefixes = {};
  Map<String, Color> lineColors = {};
  List<gtfs.Route> allRoutes = [];
  // Fare mappings (loaded from assets)
  Map<String, String> fareTypeMap = {}; // fareId -> 'm'|'s'
  Map<String, int> fareDataMap = {}; // e.g. 'm3' -> 28

  // Routing preference: 'Shortest', 'Fastest', 'Cheapest'
  String routingMode = 'Shortest';
  // Cached graphs for multi-mode routing
  final Map<String, Map<String, double>> distanceGraph = {};
  final Map<String, Map<String, int>> timeGraph = {};
  bool graphBuilt = false;

  // Helper to get line name by stopId
  String? _getLineName(String stopId) {
    for (var entry in linePrefixes.entries) {
      for (var prefix in entry.value) {
        if (stopId.startsWith(prefix)) return entry.key;
      }
    }
    return null;
  }

  Future<List<gtfs.Route>> _parseRoutesFromAsset(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return [];
      final routes = <gtfs.Route>[];
      final header = _parseCsvLine(lines[0]).map((s) => s.trim()).toList();
      final idxRouteId = header.indexOf('route_id');
      final idxAgencyId = header.indexOf('agency_id');
      final idxShortName = header.indexOf('route_short_name');
      final idxLongName = header.indexOf('route_long_name');
      final idxType = header.indexOf('route_type');
      final idxColor = header.indexOf('route_color');
      final idxTextColor = header.indexOf('route_text_color');
      final idxLinePrefixes = header.indexOf('line_prefixes');
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = _parseCsvLine(line);
        if (row.length < 7) continue;
        final linePrefixes =
            idxLinePrefixes >= 0 && row.length > idxLinePrefixes
            ? row
                  .sublist(idxLinePrefixes)
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList()
                  .cast<String>()
            : <String>[];
        routes.add(
          gtfs.Route(
            routeId: row[idxRouteId].trim(),
            agencyId: row[idxAgencyId].trim(),
            shortName: row[idxShortName].trim(),
            longName: row[idxLongName].trim(),
            type: row[idxType].trim(),
            color: idxColor >= 0 ? _cleanHex(row[idxColor]) : null,
            textColor: idxTextColor >= 0 ? _cleanHex(row[idxTextColor]) : null,
            linePrefixes: linePrefixes,
          ),
        );
      }
      return routes;
    } catch (_) {
      return [];
    }
  }

  String? selectedStartStopId;
  String? selectedDestinationStopId;
  List<List<gtfs.Stop>> directionOptions = [];
  List<String> directionOptionLabels = [];
  List<Set<String>> directionOptionTags = [];
  int selectedDirectionIndex = 0;

  Future<void> _findDirection() async {
    if (!graphBuilt) {
      await _buildGraphs();
      graphBuilt = true;
    }
    if (selectedStartStopId == null || selectedDestinationStopId == null) {
      return;
    }
    // Load stop_times.txt
    final stopTimesContent = await rootBundle.loadString(
      'assets/gtfs_data/stop_times.txt',
    );
    final stopTimesLines = const LineSplitter().convert(stopTimesContent);
    if (stopTimesLines.length <= 1) return;
    // Parse stop_times (robust CSV with header indices)
    final stopTimes = <String, List<Map<String, dynamic>>>{};
    final header = _parseCsvLine(
      stopTimesLines.first,
    ).map((s) => s.trim()).toList();
    final idxTripId = header.indexOf('trip_id');
    final idxStopId = header.indexOf('stop_id');
    final idxStopSeq = header.indexOf('stop_sequence');
    for (var i = 1; i < stopTimesLines.length; i++) {
      final line = stopTimesLines[i].trimRight();
      if (line.isEmpty) continue;
      final row = _parseCsvLine(line);
      if (row.isEmpty || idxTripId < 0 || idxStopId < 0 || idxStopSeq < 0) {
        continue;
      }
      if (row.length <= idxTripId ||
          row.length <= idxStopId ||
          row.length <= idxStopSeq) {
        continue;
      }
      final tripId = row[idxTripId].trim();
      final stopId = row[idxStopId].trim();
      final stopSequence = int.tryParse(row[idxStopSeq].trim()) ?? i;
      if (tripId.isEmpty || stopId.isEmpty) continue;
      stopTimes.putIfAbsent(tripId, () => []).add({
        'stopId': stopId,
        'stopSequence': stopSequence,
      });
    }
    // Ensure each trip's stops are sorted by stop_sequence
    for (final entry in stopTimes.entries) {
      entry.value.sort(
        (a, b) =>
            (a['stopSequence'] as int).compareTo(b['stopSequence'] as int),
      );
    }

    // Load trips.txt to map trip_id -> route_id
    final tripsContent = await rootBundle.loadString(
      'assets/gtfs_data/trips.txt',
    );
    final tripsLines = tripsContent.split('\n');
    final Map<String, String> tripToRoute = {}; // trip_id -> route_id
    if (tripsLines.length > 1) {
      final header = tripsLines[0].split(',');
      final idxRouteId = header.indexOf('route_id');
      final idxTripId = header.indexOf('trip_id');
      for (int i = 1; i < tripsLines.length; i++) {
        final row = _parseCsvLine(tripsLines[i]);
        if (row.length <= idxTripId ||
            row.length <= idxRouteId ||
            idxTripId < 0 ||
            idxRouteId < 0) {
          continue;
        }
        final routeId = row[idxRouteId];
        final tripId = row[idxTripId];
        if (routeId.isEmpty || tripId.isEmpty) continue;
        tripToRoute[tripId] = routeId;
      }
    }

    // Helper: extract alpha prefix (e.g., N/E/S/W/BL/CEN)
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

    final startPrefix = extractPrefix(selectedStartStopId!);
    final destPrefix = extractPrefix(selectedDestinationStopId!);

    // Build routeId -> prefixes map from routes loaded earlier
    final Map<String, List<String>> routeIdToPrefixes = {
      for (final r in allRoutes) r.routeId: r.linePrefixes,
    };

    // Determine candidate routeIds to consider based on prefixes
    Set<String> candidateRouteIds = {};
    final bool prefersSukhumvit =
        (startPrefix == 'N' || startPrefix == 'E') ||
        (destPrefix == 'N' || destPrefix == 'E');
    final bool prefersSilom =
        (startPrefix == 'W' || startPrefix == 'S') ||
        (destPrefix == 'W' || destPrefix == 'S');
    if (prefersSukhumvit && !prefersSilom) {
      for (final e in routeIdToPrefixes.entries) {
        final p = e.value;
        if (p.contains('N') || p.contains('E')) candidateRouteIds.add(e.key);
      }
    } else if (prefersSilom && !prefersSukhumvit) {
      for (final e in routeIdToPrefixes.entries) {
        final p = e.value;
        if (p.contains('W') || p.contains('S')) candidateRouteIds.add(e.key);
      }
    } else {
      // Ambiguous (e.g., CEN to CEN), allow any BTS routes present
      for (final e in routeIdToPrefixes.entries) {
        candidateRouteIds.add(e.key);
      }
    }

    // Choose the best trip containing both stops and matching candidate routes
    String? selectedTripId;
    int bestSpan = -1;
    for (var entry in stopTimes.entries) {
      final tripId = entry.key;
      final routeId = tripToRoute[tripId];
      if (routeId == null || !candidateRouteIds.contains(routeId)) continue;
      final tripStops = entry.value;
      final startIdx = tripStops.indexWhere(
        (s) => s['stopId'] == selectedStartStopId,
      );
      final destIdx = tripStops.indexWhere(
        (s) => s['stopId'] == selectedDestinationStopId,
      );
      if (startIdx != -1 && destIdx != -1) {
        final span = (destIdx - startIdx).abs();
        if (span > bestSpan) {
          bestSpan = span;
          selectedTripId = tripId;
        }
      }
    }
    // Fallback: if nothing matched the candidate routes, search all trips
    if (selectedTripId == null) {
      bestSpan = -1;
      for (var entry in stopTimes.entries) {
        final tripStops = entry.value;
        final startIdx = tripStops.indexWhere(
          (s) => s['stopId'] == selectedStartStopId,
        );
        final destIdx = tripStops.indexWhere(
          (s) => s['stopId'] == selectedDestinationStopId,
        );
        if (startIdx != -1 && destIdx != -1) {
          final span = (destIdx - startIdx).abs();
          if (span > bestSpan) {
            bestSpan = span;
            selectedTripId = entry.key;
          }
        }
      }
    }

    final Map<String, _TaggedRoute> optionMap = {};
    void addOption(List<gtfs.Stop> stops, Set<String> tags) {
      if (stops.isEmpty) return;
      final key = stops.map((s) => s.stopId).join('>');
      final entry = optionMap.putIfAbsent(
        key,
        () => _TaggedRoute(stops: List<gtfs.Stop>.from(stops), tags: tags),
      );
      entry.tags.addAll(tags);
    }

    final multiRoutes = _computeMultiModeRoutes(
      selectedStartStopId!,
      selectedDestinationStopId!,
    );
    for (final route in multiRoutes) {
      addOption(route.stops, route.tags);
    }

    if (selectedTripId != null) {
      final tripStops = stopTimes[selectedTripId]!
        ..sort(
          (a, b) =>
              (a['stopSequence'] as int).compareTo(b['stopSequence'] as int),
        );
      final startIdx = tripStops.indexWhere(
        (s) => s['stopId'] == selectedStartStopId,
      );
      final destIdx = tripStops.indexWhere(
        (s) => s['stopId'] == selectedDestinationStopId,
      );
      if (startIdx != -1 && destIdx != -1) {
        final segment = startIdx <= destIdx
            ? tripStops.sublist(startIdx, destIdx + 1)
            : tripStops.sublist(destIdx, startIdx + 1).reversed.toList();
        final stopsList = segment
            .map(
              (s) =>
                  stopLookup[s['stopId']] ??
                  allStops.firstWhere(
                    (stop) => stop.stopId == s['stopId'],
                    orElse: () => gtfs.Stop(
                      stopId: s['stopId'],
                      name: s['stopId'],
                      lat: 0,
                      lon: 0,
                    ),
                  ),
            )
            .toList();
        if (stopsList.isNotEmpty) {
          addOption(stopsList, {'Direct'});
        }
      }
    }

    final transferRoutes = _generateTransferRoutes(
      stopTimes: stopTimes,
      tripToRoute: tripToRoute,
      routeIdToPrefixes: routeIdToPrefixes,
      startStopId: selectedStartStopId!,
      destStopId: selectedDestinationStopId!,
    );
    for (final route in transferRoutes) {
      addOption(route.stops, route.tags);
    }

    if (optionMap.isEmpty) {
      setState(() {
        directionOptions = [];
        directionOptionLabels = [];
        directionOptionTags = [];
        selectedDirectionIndex = 0;
      });
      return;
    }

    final metrics = <_RouteMetrics>[];
    for (final option in optionMap.values) {
      final distance = _routeDistanceMeters(option.stops);
      final minutes = _estimateRouteMinutes(option.stops);
      final fare = _calculateFare(option.stops);
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
      setState(() {
        directionOptions = [];
        directionOptionLabels = [];
        directionOptionTags = [];
        selectedDirectionIndex = 0;
      });
      return;
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
        .map((m) => List<gtfs.Stop>.from(m.route.stops))
        .toList();
    final tagsList = metrics
        .map((m) => Set<String>.from(m.route.tags))
        .toList();
    final labels = tagsList.map(_optionLabelText).toList();

    int selectionIndex = 0;
    for (int i = 0; i < tagsList.length; i++) {
      if (tagsList[i].contains(routingMode)) {
        selectionIndex = i;
        break;
      }
    }

    setState(() {
      directionOptions = options;
      directionOptionTags = tagsList;
      directionOptionLabels = labels;
      selectedDirectionIndex = selectionIndex;
    });
  }

  Color _getLineColor(String stopId) {
    final lineName = _getLineName(stopId);
    if (lineName != null && lineColors.containsKey(lineName)) {
      return lineColors[lineName]!;
    }
    return Colors.purple;
  }

  String _extractPrefix(String stopId) {
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

  // Build graphs from stop_times (adjacent stops edges)
  Future<void> _buildGraphs() async {
    try {
      final stopTimesContent = await rootBundle.loadString(
        'assets/gtfs_data/stop_times.txt',
      );
      final lines = const LineSplitter().convert(stopTimesContent);
      if (lines.length <= 1) return;
      final header = _parseCsvLine(lines.first).map((s) => s.trim()).toList();
      final idxTrip = header.indexOf('trip_id');
      final idxStop = header.indexOf('stop_id');
      final idxSeq = header.indexOf('stop_sequence');
      final tripMap = <String, List<Map<String, dynamic>>>{};
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = _parseCsvLine(line);
        if (row.length <= idxTrip ||
            row.length <= idxStop ||
            row.length <= idxSeq) {
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
        entry.value.sort(
          (a, b) => (a['seq'] as int).compareTo(b['seq'] as int),
        );
        for (int j = 0; j < entry.value.length - 1; j++) {
          final a = entry.value[j]['stopId'] as String;
          final b = entry.value[j + 1]['stopId'] as String;
          final stopA = allStops.firstWhere(
            (s) => s.stopId == a,
            orElse: () => gtfs.Stop(stopId: a, name: a, lat: 0, lon: 0),
          );
          final stopB = allStops.firstWhere(
            (s) => s.stopId == b,
            orElse: () => gtfs.Stop(stopId: b, name: b, lat: 0, lon: 0),
          );
          final dist = _haversine(stopA.lat, stopA.lon, stopB.lat, stopB.lon);
          distanceGraph.putIfAbsent(a, () => {})[b] = dist;
          distanceGraph.putIfAbsent(b, () => {})[a] = dist;
          final estMinutes = (dist / 800.0 * 2).clamp(1, 6).toInt();
          timeGraph.putIfAbsent(a, () => {})[b] = estMinutes;
          timeGraph.putIfAbsent(b, () => {})[a] = estMinutes;
        }
      }
    } catch (_) {}
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371000.0; // meters
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radius * c;
  }

  double _distanceBetweenStops(String a, String b) {
    final stopA = stopLookup[a];
    final stopB = stopLookup[b];
    if (stopA == null || stopB == null) {
      return 0;
    }
    return _haversine(stopA.lat, stopA.lon, stopB.lat, stopB.lon);
  }

  List<_TaggedRoute> _computeMultiModeRoutes(String start, String dest) {
    final nodes = {...distanceGraph.keys, ...timeGraph.keys};
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
      final fare = _calculateFare(route.stops)['total'] ?? 0;
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
    required Map<String, String> tripToRoute,
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
        final routeId = tripToRoute[entry.key];
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

    final startPrefix = _extractPrefix(startStopId);
    final destPrefix = _extractPrefix(destStopId);

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

    final List<List<String>> transferHubs = [
      ['CEN'],
      ['S7', 'G1'],
      ['BL01'],
      ['BL13', 'N8'],
      ['BL14', 'N9'],
      ['BL22', 'E4'],
      ['BL26', 'S2'],
      ['BL34', 'S12'],
    ];

    for (final hubGroup in transferHubs) {
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
          final combinedStops = merged.map((s) {
            final stopId = s['stopId'] as String;
            return stopLookup[stopId] ??
                allStops.firstWhere(
                  (st) => st.stopId == stopId,
                  orElse: () =>
                      gtfs.Stop(stopId: stopId, name: stopId, lat: 0, lon: 0),
                );
          }).toList();
          final tags = <String>{'Transfer'};
          if (hubA == hubB) {
            tags.add('Single transfer');
          }
          final viaName = stopLookup[hubA]?.name ?? stopLookup[hubB]?.name;
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
          distanceGraph[current]?.keys ?? const Iterable<String>.empty();
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
          (id) => allStops.firstWhere(
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
    final nodes = {...distanceGraph.keys, ...timeGraph.keys};
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
      neighborIds.addAll(
        distanceGraph[current]?.keys ?? const Iterable.empty(),
      );
      neighborIds.addAll(timeGraph[current]?.keys ?? const Iterable.empty());
      for (final neighbor in neighborIds) {
        final edgeDistance =
            distanceGraph[current]?[neighbor] ??
            _distanceBetweenStops(current, neighbor);
        if (edgeDistance <= 0) continue;
        final edgeTime =
            (timeGraph[current]?[neighbor]?.toDouble()) ??
            math.max(1, edgeDistance / 500.0);
        double edgeCost = edgeDistance * distanceWeight + edgeTime * timeWeight;
        if (transferPenalty > 0) {
          final currentLine = _getLineName(current);
          final neighborLine = _getLineName(neighbor);
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

    if (distance[dest] == null || distance[dest] == double.infinity) {
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
          (id) => allStops.firstWhere(
            (stop) => stop.stopId == id,
            orElse: () => gtfs.Stop(stopId: id, name: id, lat: 0, lon: 0),
          ),
        )
        .toList();
  }

  Color _getPolylineColor(String lineName) {
    if (lineColors.containsKey(lineName)) {
      return lineColors[lineName]!;
    }
    return Colors.purple;
  }

  Polyline _connectionPolyline(LatLng from, LatLng to) {
    return Polyline(points: [from, to], color: Colors.black, strokeWidth: 8.0);
  }

  Polyline _linePolyline(LatLng from, LatLng to, Color color) {
    return Polyline(points: [from, to], color: color, strokeWidth: 6.0);
  }

  List<Polyline> _buildRoutePolylines(List<gtfs.Stop> route) {
    final polylines = <Polyline>[];
    if (route.length < 2) return polylines;
    String? previousLine = _getLineName(route[0].stopId);
    for (int i = 1; i < route.length; i++) {
      final currentLine = _getLineName(route[i].stopId);
      final from = LatLng(route[i - 1].lat, route[i - 1].lon);
      final to = LatLng(route[i].lat, route[i].lon);
      if (currentLine != previousLine) {
        if (route[i - 1].lat != route[i].lat ||
            route[i - 1].lon != route[i].lon) {
          polylines.add(_connectionPolyline(from, to));
        }
      } else {
        polylines.add(
          _linePolyline(
            from,
            to,
            _getPolylineColor(currentLine ?? previousLine ?? ''),
          ),
        );
      }
      previousLine = currentLine;
    }
    return polylines;
  }

  double _routeDistanceMeters(List<gtfs.Stop> stops) {
    double total = 0;
    for (int i = 0; i < stops.length - 1; i++) {
      total += _haversine(
        stops[i].lat,
        stops[i].lon,
        stops[i + 1].lat,
        stops[i + 1].lon,
      );
    }
    return total;
  }

  int _estimateRouteMinutes(List<gtfs.Stop> stops) {
    int total = 0;
    for (int i = 0; i < stops.length - 1; i++) {
      final fromId = stops[i].stopId;
      final toId = stops[i + 1].stopId;
      final segment = timeGraph[fromId]?[toId];
      if (segment != null) {
        total += segment;
      } else {
        final distMeters = _haversine(
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

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
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

  List<gtfs.Stop> get _sortedStops {
    final unique = <String, gtfs.Stop>{
      for (final stop in allStops) stop.stopId: stop,
    };
    final sorted = unique.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  Future<void> _swapStops() async {
    if (selectedStartStopId == null && selectedDestinationStopId == null) {
      return;
    }
    setState(() {
      final temp = selectedStartStopId;
      selectedStartStopId = selectedDestinationStopId;
      selectedDestinationStopId = temp;
    });
    if (selectedStartStopId != null && selectedDestinationStopId != null) {
      await _findDirection();
    }
  }

  Future<void> _updateRoutingMode(String newMode) async {
    if (routingMode == newMode) return;
    setState(() {
      routingMode = newMode;
    });
    if (selectedStartStopId != null &&
        selectedDestinationStopId != null &&
        directionOptions.isNotEmpty) {
      await _findDirection();
    }
  }

  void _selectRouteOption(int index) {
    if (index < 0 || index >= directionOptions.length) return;
    const order = ['Shortest', 'Fastest', 'Cheapest'];
    String? nextMode;
    if (index < directionOptionTags.length) {
      final tags = directionOptionTags[index];
      for (final candidate in order) {
        if (tags.contains(candidate)) {
          nextMode = candidate;
          break;
        }
      }
    }
    final options = List<List<gtfs.Stop>>.from(directionOptions);
    final tagsList = directionOptionTags
        .map((set) => Set<String>.from(set))
        .toList();
    final selectedStops = options.removeAt(index);
    final selectedTags = tagsList.removeAt(index);
    final reorderedOptions = [selectedStops, ...options];
    final reorderedTags = [selectedTags, ...tagsList];
    final labels = reorderedTags.map(_optionLabelText).toList();

    setState(() {
      directionOptions = reorderedOptions;
      directionOptionTags = reorderedTags;
      directionOptionLabels = labels;
      selectedDirectionIndex = 0;
      if (nextMode != null) {
        routingMode = nextMode;
      }
    });
  }

  Widget _buildRouteOptionsSection(BuildContext context) {
    if (directionOptions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Route options', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...List.generate(
            directionOptions.length,
            (index) => _buildRouteOptionCard(context, index),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteOptionCard(BuildContext context, int index) {
    if (index < 0 || index >= directionOptions.length) {
      return const SizedBox.shrink();
    }
    final stops = directionOptions[index];
    if (stops.isEmpty) return const SizedBox.shrink();
    final label = index < directionOptionLabels.length
        ? directionOptionLabels[index]
        : 'Option ${index + 1}';
    final tags = index < directionOptionTags.length
        ? directionOptionTags[index]
        : <String>{};
    const order = [
      'Shortest',
      'Fastest',
      'Cheapest',
      'Direct',
      'Balanced',
      'Low transfers',
      'Fewest stops',
      'Transfer',
    ];
    final sortedTags = tags.toList()
      ..sort((a, b) {
        final ai = order.indexOf(a);
        final bi = order.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });
    final distanceText = _formatDistance(_routeDistanceMeters(stops));
    final minutes = _estimateRouteMinutes(stops);
    final fare = _calculateFare(stops);
    final isSelected = index == selectedDirectionIndex;
    final lineSegments = _splitRouteByLine(stops);

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectRouteOption(index),
        child: Card(
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.75)
              : theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sortedTags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    children: sortedTags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$distanceText • ~${minutes.toString()} min • ${stops.length} stops',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fare ฿${fare['total'] ?? 0}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'm:${fare['mCount'] ?? 0} (฿${fare['mPrice'] ?? 0})  s:${fare['sCount'] ?? 0} (฿${fare['sPrice'] ?? 0})',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: lineSegments.map((segment) {
                    final lineName = segment.isNotEmpty
                        ? (_getLineName(segment.first.stopId) ?? 'Unknown line')
                        : 'Unknown line';
                    final color = lineColors[lineName] ?? Colors.purple;
                    return Chip(
                      avatar: CircleAvatar(backgroundColor: color),
                      label: Text(lineName),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final startId = selectedStartStopId;
    final destId = selectedDestinationStopId;
    final routeStops = directionStopsView;
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(13.7463, 100.5347),
        initialZoom: 12.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.route',
        ),
        if (allStops.isNotEmpty)
          MarkerLayer(
            markers: allStops
                .map(
                  (stop) => Marker(
                    point: LatLng(stop.lat, stop.lon),
                    width: (stop.stopId == startId || stop.stopId == destId)
                        ? 22
                        : 16,
                    height: (stop.stopId == startId || stop.stopId == destId)
                        ? 22
                        : 16,
                    child: Tooltip(
                      message: stop.name,
                      child: Container(
                        decoration: BoxDecoration(
                          color: (stop.stopId == startId)
                              ? Colors.greenAccent.withValues(alpha: 0.85)
                              : (stop.stopId == destId)
                              ? Colors.redAccent.withValues(alpha: 0.85)
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getLineColor(stop.stopId),
                            width:
                                (stop.stopId == startId ||
                                    stop.stopId == destId)
                                ? 4
                                : 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        if (routeStops.isNotEmpty)
          PolylineLayer(polylines: _buildRoutePolylines(routeStops)),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
        ),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final panelWidth = math.min(440.0, width * 0.35);
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: panelWidth,
          color: theme.colorScheme.surface,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildControlPanel(context),
              _buildRouteOptionsSection(context),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _buildMap(context)),
      ],
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    final hasRoutes = directionOptions.isNotEmpty;
    final initialSize = hasRoutes ? 0.4 : 0.25;
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(child: _buildMap(context)),
        DraggableScrollableSheet(
          initialChildSize: initialSize,
          minChildSize: 0.2,
          maxChildSize: 0.9,
          builder: (context, controller) {
            final bottomPadding = MediaQuery.of(context).padding.bottom;
            return Material(
              elevation: 12,
              color: theme.colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: ListView(
                controller: controller,
                padding: EdgeInsets.only(bottom: bottomPadding + 24),
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildControlPanel(context),
                  _buildRouteOptionsSection(context),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildControlPanel(BuildContext context) {
    final stops = _sortedStops;
    final dropdownItems = stops
        .map(
          (stop) => DropdownMenuItem<String>(
            value: stop.stopId,
            child: Text(stop.name),
          ),
        )
        .toList();
    final startValue = stops.any((stop) => stop.stopId == selectedStartStopId)
        ? selectedStartStopId
        : null;
    final destValue =
        stops.any((stop) => stop.stopId == selectedDestinationStopId)
        ? selectedDestinationStopId
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'Shortest',
                          label: Text('Shortest'),
                          icon: Icon(Icons.format_list_numbered),
                        ),
                        ButtonSegment(
                          value: 'Fastest',
                          label: Text('Fastest'),
                          icon: Icon(Icons.speed),
                        ),
                        ButtonSegment(
                          value: 'Cheapest',
                          label: Text('Cheapest'),
                          icon: Icon(Icons.attach_money),
                        ),
                      ],
                      selected: <String>{routingMode},
                      onSelectionChanged: (selection) {
                        if (selection.isNotEmpty) {
                          _updateRoutingMode(selection.first);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed:
                        (selectedStartStopId != null &&
                            selectedDestinationStopId != null)
                        ? () {
                            _findDirection();
                          }
                        : null,
                    icon: const Icon(Icons.route),
                    label: const Text('Plan route'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: startValue,
                      decoration: const InputDecoration(
                        labelText: 'Start station',
                        prefixIcon: Icon(Icons.trip_origin),
                        border: OutlineInputBorder(),
                      ),
                      items: dropdownItems,
                      onChanged: (value) {
                        setState(() {
                          selectedStartStopId = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Swap start and destination',
                    icon: const Icon(Icons.swap_horiz),
                    onPressed:
                        (selectedStartStopId != null ||
                            selectedDestinationStopId != null)
                        ? () {
                            _swapStops();
                          }
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: destValue,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        prefixIcon: Icon(Icons.flag),
                        border: OutlineInputBorder(),
                      ),
                      items: dropdownItems,
                      onChanged: (value) {
                        setState(() {
                          selectedDestinationStopId = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<gtfs.Stop> get directionStopsView {
    if (directionOptions.isNotEmpty &&
        selectedDirectionIndex < directionOptions.length &&
        directionOptions[selectedDirectionIndex].isNotEmpty) {
      return directionOptions[selectedDirectionIndex];
    }
    return [];
  }

  List<List<gtfs.Stop>> _splitRouteByLine(List<gtfs.Stop> route) {
    if (route.isEmpty) return [];
    List<List<gtfs.Stop>> segments = [];
    List<gtfs.Stop> current = [route.first];
    String lastLine = _getLineName(route.first.stopId) ?? '';
    // If first is CEN and lastLine is ambiguous/empty, try to infer from next non-CEN
    if ((route.first.stopId == 'CEN') && lastLine.isEmpty) {
      for (int j = 1; j < route.length; j++) {
        if (route[j].stopId != 'CEN') {
          final inferred = _getLineName(route[j].stopId) ?? '';
          if (inferred.isNotEmpty) {
            lastLine = inferred;
          }
          break;
        }
      }
    }
    String effectiveLineFor(int index) {
      final id = route[index].stopId;
      var ln = _getLineName(id) ?? '';
      if (id == 'CEN') {
        // Make Siam adopt the neighboring segment's line to avoid splitting into single-point segments.
        if (lastLine.isNotEmpty) return lastLine;
        // If no previous line, try to infer from the next non-CEN stop.
        for (int j = index + 1; j < route.length; j++) {
          if (route[j].stopId != 'CEN') {
            final inferred = _getLineName(route[j].stopId) ?? '';
            if (inferred.isNotEmpty) return inferred;
            break;
          }
        }
      }
      return ln;
    }

    for (int i = 1; i < route.length; i++) {
      String line = effectiveLineFor(i);
      if (line != lastLine) {
        // Close previous segment
        segments.add(current);
        // Start new segment including the boundary stop to ensure at least 2 points
        current = [route[i - 1], route[i]];
        lastLine = line;
      } else {
        current.add(route[i]);
      }
    }
    if (current.isNotEmpty) segments.add(current);
    return segments;
  }

  @override
  void initState() {
    super.initState();
    _loadRoutesAndStops();
  }

  Future<void> _loadRoutesAndStops() async {
    final routes = await _parseRoutesFromAsset('assets/gtfs_data/routes.txt');
    final stops = await _parseStopsFromAsset('assets/gtfs_data/stops.txt');
    // Load fare mappings used for fare calculation
    await _loadFareMappings();
    // Build linePrefixes and lineColors from routes
    Map<String, List<String>> prefixMap = {};
    Map<String, Color> colorMap = {};
    for (var route in routes) {
      prefixMap[route.longName] = route.linePrefixes;
      if (route.color != null && route.color!.isNotEmpty) {
        colorMap[route.longName] = Color(int.parse('0xFF${route.color!}'));
      }
    }
    setState(() {
      allRoutes = routes;
      allStops = stops;
      linePrefixes = prefixMap;
      lineColors = colorMap;
      stopLookup = {for (final stop in stops) stop.stopId: stop};
    });
  }

  // _loadStops is now replaced by _loadRoutesAndStops

  Future<List<gtfs.Stop>> _parseStopsFromAsset(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return [];
      final stops = <gtfs.Stop>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = _parseCsvLine(line);
        if (row.length < 4) continue;
        try {
          stops.add(
            gtfs.Stop(
              stopId: row[0].trim(),
              name: row[1].trim(),
              lat: double.parse(row[2].trim()),
              lon: double.parse(row[3].trim()),
              code: row.length > 4 ? row[4] : null,
              desc: row.length > 5 ? row[5] : null,
              zoneId: row.length > 6 ? row[6] : null,
            ),
          );
        } catch (_) {}
      }
      return stops;
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadFareMappings() async {
    fareTypeMap.clear();
    fareDataMap.clear();
    try {
      // Faretype mapping: fareId -> status ('m'|'s')
      final content = await rootBundle.loadString(
        'assets/gtfs_data/Faretype.txt',
      );
      final lines = const LineSplitter().convert(content);
      if (lines.length > 1) {
        final header = _parseCsvLine(
          lines[0],
        ).map((s) => s.toLowerCase()).toList();
        int idxFareId = header.indexOf('fareid');
        if (idxFareId < 0) idxFareId = 0;
        int idxStatus = header.indexOf('agencystatus');
        if (idxStatus < 0) idxStatus = header.indexOf('agsscystatus');
        if (idxStatus < 0) idxStatus = 1;
        for (var i = 1; i < lines.length; i++) {
          final line = lines[i].trimRight();
          if (line.isEmpty) continue;
          final row = _parseCsvLine(line);
          if (row.length <= idxFareId) continue;
          final id = row[idxFareId].trim();
          final status = (row.length > idxStatus)
              ? row[idxStatus].trim().toLowerCase()
              : '';
          if (id.isNotEmpty && (status == 'm' || status == 's')) {
            fareTypeMap[id] = status;
          }
        }
      }
    } catch (_) {}

    try {
      // Fare data: fareDataId -> price
      final content = await rootBundle.loadString(
        'assets/gtfs_data/FareData.txt',
      );
      final lines = const LineSplitter().convert(content);
      if (lines.length > 1) {
        final header = _parseCsvLine(
          lines[0],
        ).map((s) => s.toLowerCase()).toList();
        int idxId = header.indexOf('faredataid');
        if (idxId < 0) idxId = header.indexOf('fareid');
        if (idxId < 0) idxId = 0;
        int idxPrice = header.indexOf('price');
        if (idxPrice < 0) idxPrice = 1;
        for (var i = 1; i < lines.length; i++) {
          final line = lines[i].trimRight();
          if (line.isEmpty) continue;
          final row = _parseCsvLine(line);
          if (row.length <= idxId) continue;
          final id = row[idxId].trim();
          final price = (row.length > idxPrice)
              ? int.tryParse(row[idxPrice].trim()) ?? 0
              : 0;
          if (id.isNotEmpty) fareDataMap[id] = price;
        }
      }
    } catch (_) {}
  }

  Map<String, int> _calculateFare(List<gtfs.Stop> routeStops) {
    // Returns map: mCount, sCount, mPrice, sPrice, total
    int mCount = 0;
    int sCount = 0;
    if (routeStops.length <= 1) {
      return {'mCount': 0, 'sCount': 0, 'mPrice': 0, 'sPrice': 0, 'total': 0};
    }
    // SPECIAL PAIR RULES (evaluate before excluding last station):
    // - N5 -> N7  : the occurrence at N5 counts as 2 m units
    // - N7 -> N5  : the occurrence at N7 counts as 2 m units
    // Also evaluate the 'first pair' special rules (4-6) before trimming the last station:
    // - If first==N8 && second==N9 -> first treated as 's'
    // - If first==S8 && second==S9 -> first treated as 's'
    // - If first==E9 && second==E10 -> first treated as 's'
    final Map<int, int> specialIndexExtra =
        {}; // original index -> extra m-count (2)
    final Map<int, String> specialStatusOverride =
        {}; // original index -> overridden status ('s' or 'm')
    for (int i = 0; i < routeStops.length - 1; i++) {
      final a = routeStops[i].stopId.trim();
      final b = routeStops[i + 1].stopId.trim();
      if (a == 'N5' && b == 'N7') {
        specialIndexExtra[i] = (specialIndexExtra[i] ?? 0) + 2;
      } else if (a == 'N7' && b == 'N5') {
        specialIndexExtra[i] = (specialIndexExtra[i] ?? 0) + 2;
      }
      // Apply special status overrides for any matching consecutive pair (not just first pair)
      if (a == 'N8' && b == 'N9') specialStatusOverride[i] = 's';
      if (a == 'S8' && b == 'S9') specialStatusOverride[i] = 's';
      if (a == 'E9' && b == 'E10') specialStatusOverride[i] = 's';
    }

    // Now remove the last station (rule 1) and count through remaining stops.
    final stopsToCount = routeStops.sublist(0, routeStops.length - 1);
    for (int i = 0; i < stopsToCount.length; i++) {
      final currId = stopsToCount[i].stopId.trim();
      // If this original index has a special extra-count, apply it (counts as m) and skip normal counting for this occurrence
      if (specialIndexExtra.containsKey(i)) {
        mCount += specialIndexExtra[i]!;
        continue;
      }
      // If there's a status override for this index (e.g., first-pair rules), use it
      String? status;
      if (specialStatusOverride.containsKey(i)) {
        status = specialStatusOverride[i];
      } else {
        status = fareTypeMap[currId];
      }
      if (status == 'm') {
        mCount++;
      } else if (status == 's') {
        sCount++;
      } else {
        // skip unknown
      }
    }
    // Apply caps
    if (mCount > 8) mCount = 8; // cap for m
    if (sCount > 13) sCount = 13; // cap for s

    final mKey = 'm$mCount';
    final sKey = 's$sCount';
    final mPrice = fareDataMap[mKey] ?? 0;
    final sPrice = fareDataMap[sKey] ?? 0;
    int total = mPrice + sPrice;
    if (total > 65) total = 65;
    return {
      'mCount': mCount,
      'sCount': sCount,
      'mPrice': mPrice,
      'sPrice': sPrice,
      'total': total,
    };
  }

  List<String> _parseCsvLine(String line) {
    // CSV parser supporting quoted fields and commas within quotes
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

  String? _cleanHex(String? hex) {
    if (hex == null) return null;
    var s = hex.trim().replaceAll('\r', '').replaceAll('#', '');
    if (s.isEmpty) return null;
    return s.toUpperCase();
  }

  Future<void> _goToMyLocation() async {
    Location location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }
    final userLocation = await location.getLocation();
    if (userLocation.latitude != null && userLocation.longitude != null) {
      _mapController.move(
        LatLng(userLocation.latitude!, userLocation.longitude!),
        _mapController.camera.zoom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWideLayout = width >= 900;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Show Transport Lines',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransportLinesPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: isWideLayout
            ? _buildWideLayout(context)
            : _buildPhoneLayout(context),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  //
}
