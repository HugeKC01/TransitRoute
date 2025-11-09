import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
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

class _MyHomePageState extends State<MyHomePage> {
  final MapController _mapController = MapController();
  List<gtfs.Stop> allStops = [];
  Map<String, List<gtfs.Stop>> lineStops = {};
  String selectedLine = 'Auto';

  Map<String, List<String>> linePrefixes = {};
  Map<String, Color> lineColors = {};
  Map<String, String> lineColorHex = {};
  List<gtfs.Route> allRoutes = [];
  // Fare mappings (loaded from assets)
  Map<String, String> fareTypeMap = {}; // fareId -> 'm'|'s'
  Map<String, int> fareDataMap = {}; // e.g. 'm3' -> 28

  // Time mappings (loaded from assets)
  // Structure: startId -> (endId -> durationMinutes)
  final Map<String, Map<String, int>> _timeMap = {};
  int travelTimeMinutes = 0; // total travel time for current selected route

  // Last-calculated fare breakdown
  int fareMCount = 0;
  int fareSCount = 0;
  int fareMPrice = 0;
  int fareSPrice = 0;
  int calculatedFare = 0;

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
        final linePrefixes = idxLinePrefixes >= 0 && row.length > idxLinePrefixes
          ? row.sublist(idxLinePrefixes).map((s) => s.trim()).where((s) => s.isNotEmpty).toList().cast<String>()
          : <String>[];
        routes.add(gtfs.Route(
          routeId: row[idxRouteId].trim(),
          agencyId: row[idxAgencyId].trim(),
          shortName: row[idxShortName].trim(),
          longName: row[idxLongName].trim(),
          type: row[idxType].trim(),
          color: idxColor >= 0 ? _cleanHex(row[idxColor]) : null,
          textColor: idxTextColor >= 0 ? _cleanHex(row[idxTextColor]) : null,
          linePrefixes: linePrefixes,
        ));
      }
      return routes;
    } catch (_) {
      return [];
    }
  }

    String? selectedStartStopId;
    String? selectedDestinationStopId;
    List<gtfs.Stop> directionStops = [];
    List<List<gtfs.Stop>> directionOptions = [];
    int selectedDirectionIndex = 0;

    void _findDirection() async {
      if (selectedStartStopId == null || selectedDestinationStopId == null) return;
      // Load stop_times.txt
      final stopTimesContent = await rootBundle.loadString('assets/gtfs_data/stop_times.txt');
      final stopTimesLines = const LineSplitter().convert(stopTimesContent);
      if (stopTimesLines.length <= 1) return;
      // Parse stop_times (robust CSV with header indices)
      final stopTimes = <String, List<Map<String, dynamic>>>{};
      final header = _parseCsvLine(stopTimesLines.first).map((s) => s.trim()).toList();
      final idxTripId = header.indexOf('trip_id');
      final idxStopId = header.indexOf('stop_id');
      final idxStopSeq = header.indexOf('stop_sequence');
      for (var i = 1; i < stopTimesLines.length; i++) {
        final line = stopTimesLines[i].trimRight();
        if (line.isEmpty) continue;
        final row = _parseCsvLine(line);
        if (row.isEmpty || idxTripId < 0 || idxStopId < 0 || idxStopSeq < 0) continue;
        if (row.length <= idxTripId || row.length <= idxStopId || row.length <= idxStopSeq) continue;
        final tripId = row[idxTripId].trim();
        final stopId = row[idxStopId].trim();
        final stopSequence = int.tryParse(row[idxStopSeq].trim()) ?? i;
        if (tripId.isEmpty || stopId.isEmpty) continue;
        stopTimes.putIfAbsent(tripId, () => []).add({'stopId': stopId, 'stopSequence': stopSequence});
      }
      // Ensure each trip's stops are sorted by stop_sequence
      for (final entry in stopTimes.entries) {
        entry.value.sort((a, b) => (a['stopSequence'] as int).compareTo(b['stopSequence'] as int));
      }

      // Load trips.txt to map trip_id -> route_id
      final tripsContent = await rootBundle.loadString('assets/gtfs_data/trips.txt');
      final tripsLines = tripsContent.split('\n');
      final Map<String, String> tripToRoute = {}; // trip_id -> route_id
      if (tripsLines.length > 1) {
        final header = tripsLines[0].split(',');
        final idxRouteId = header.indexOf('route_id');
        final idxTripId = header.indexOf('trip_id');
        for (int i = 1; i < tripsLines.length; i++) {
          final row = _parseCsvLine(tripsLines[i]);
          if (row.length <= idxTripId || row.length <= idxRouteId || idxTripId < 0 || idxRouteId < 0) continue;
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
        for (final r in allRoutes) r.routeId: r.linePrefixes
      };

      // Determine candidate routeIds to consider based on prefixes
      Set<String> candidateRouteIds = {};
      final bool prefersSukhumvit = (startPrefix == 'N' || startPrefix == 'E') || (destPrefix == 'N' || destPrefix == 'E');
      final bool prefersSilom = (startPrefix == 'W' || startPrefix == 'S') || (destPrefix == 'W' || destPrefix == 'S');
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
        final startIdx = tripStops.indexWhere((s) => s['stopId'] == selectedStartStopId);
        final destIdx = tripStops.indexWhere((s) => s['stopId'] == selectedDestinationStopId);
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
          final startIdx = tripStops.indexWhere((s) => s['stopId'] == selectedStartStopId);
          final destIdx = tripStops.indexWhere((s) => s['stopId'] == selectedDestinationStopId);
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
        // Attempt a one-transfer route via known interchanges (e.g., Siam (CEN) and Krung Thon Buri (S7/G1))
        // Each hub group lists equivalent stop_ids representing the same place across lines
        final List<List<String>> transferHubs = [
          ['CEN'],
          ['S7', 'G1'],
          ['BL01'],
          ['BL13','N8'],
          ['BL14','N9'],
          ['BL22','E4'],
          ['BL26','S2'],
          ['BL34','S12']
        ];
        // Helper to find a segment on a specific set of routeIds between A and B (inclusive)
        List<Map<String, dynamic>>? findSegmentBetween(String a, String b, Set<String> allowedRouteIds) {
          List<Map<String, dynamic>>? bestSegment;
          int bestSpan = 1 << 30;
          for (final entry in stopTimes.entries) {
            final routeId = tripToRoute[entry.key];
            if (routeId == null || !allowedRouteIds.contains(routeId)) continue;
            final ts = entry.value;
            final ia = ts.indexWhere((s) => s['stopId'] == a);
            final ib = ts.indexWhere((s) => s['stopId'] == b);
            if (ia == -1 || ib == -1) continue;
            final lo = ia < ib ? ia : ib;
            final hi = ia < ib ? ib : ia;
            final span = hi - lo;
            if (span < bestSpan) {
              bestSpan = span;
              final seg = ts.sublist(lo, hi + 1);
              bestSegment = ia <= ib ? seg : seg.reversed.toList();
            }
          }
          return bestSegment;
        }

        // Determine start/dest route sets by prefix
        Set<String> startRouteIds = {};
        Set<String> destRouteIds = {};
        for (final e in routeIdToPrefixes.entries) {
          final prefixes = e.value;
          if (prefixes.contains(startPrefix)) startRouteIds.add(e.key);
          if (prefixes.contains(destPrefix)) destRouteIds.add(e.key);
        }
        // If either set is empty (e.g., prefix not listed), allow all known routeIds as a fallback
        if (startRouteIds.isEmpty || destRouteIds.isEmpty) {
          final allRouteIds = routeIdToPrefixes.keys.toSet();
          if (startRouteIds.isEmpty) startRouteIds = allRouteIds;
          if (destRouteIds.isEmpty) destRouteIds = allRouteIds;
        }

        // Try transfer via any hub group (e.g., CEN or S7/G1)
        for (final hubGroup in transferHubs) {
          for (final hubA in hubGroup) {
            for (final hubB in hubGroup) {
              final seg1 = findSegmentBetween(selectedStartStopId!, hubA, startRouteIds);
              if (seg1 == null) continue;
              final seg2 = findSegmentBetween(hubB, selectedDestinationStopId!, destRouteIds);
              if (seg2 == null) continue;
              // Combine, drop duplicate hub at boundary if identical
              final merged = <Map<String, dynamic>>[...seg1];
              final dropDup = seg2.isNotEmpty && merged.isNotEmpty && seg2.first['stopId'] == merged.last['stopId'];
              merged.addAll(dropDup ? seg2.sublist(1) : seg2);
              final combinedStops = merged
                  .map((s) => allStops.firstWhere(
                        (st) => st.stopId == s['stopId'],
                        orElse: () => gtfs.Stop(stopId: s['stopId'], name: s['stopId'], lat: 0, lon: 0),
                      ))
                  .toList();
              final fare = _calculateFare(combinedStops);
              final timeMinutes = _calculateTravelTime(combinedStops);
              setState(() {
                directionOptions = [combinedStops];
                selectedDirectionIndex = 0;
                fareMCount = fare['mCount']!;
                fareSCount = fare['sCount']!;
                fareMPrice = fare['mPrice']!;
                fareSPrice = fare['sPrice']!;
                calculatedFare = fare['total']!;
                travelTimeMinutes = timeMinutes;
              });
              return;
            }
          }
        }

        // If transfer also failed, clear and exit
        setState(() {
          directionOptions = [];
          selectedDirectionIndex = 0;
        });
        return;
      }
  final tripStops = stopTimes[selectedTripId]!..sort((a, b) => (a['stopSequence'] as int).compareTo(b['stopSequence'] as int));
      final startIdx = tripStops.indexWhere((s) => s['stopId'] == selectedStartStopId);
      final destIdx = tripStops.indexWhere((s) => s['stopId'] == selectedDestinationStopId);
      List<List<gtfs.Stop>> foundRoutes = [];
      if (startIdx < destIdx) {
        final segment = tripStops.sublist(startIdx, destIdx + 1);
        final stopsList = segment.map((s) => allStops.firstWhere((stop) => stop.stopId == s['stopId'], orElse: () => gtfs.Stop(stopId: s['stopId'], name: s['stopId'], lat: 0, lon: 0))).toList();
        foundRoutes.add(stopsList);
      } else if (startIdx > destIdx) {
        final segment = tripStops.sublist(destIdx, startIdx + 1).reversed.toList();
        final stopsList = segment.map((s) => allStops.firstWhere((stop) => stop.stopId == s['stopId'], orElse: () => gtfs.Stop(stopId: s['stopId'], name: s['stopId'], lat: 0, lon: 0))).toList();
        foundRoutes.add(stopsList);
      }
      // Calculate fare for the first found route and update state
      if (foundRoutes.isNotEmpty) {
        final route = foundRoutes.first;
        final fare = _calculateFare(route);
        final timeMinutes = _calculateTravelTime(route);
        setState(() {
          directionOptions = foundRoutes;
          selectedDirectionIndex = 0;
          fareMCount = fare['mCount']!;
          fareSCount = fare['sCount']!;
          fareMPrice = fare['mPrice']!;
          fareSPrice = fare['sPrice']!;
          calculatedFare = fare['total']!;
          travelTimeMinutes = timeMinutes;
        });
      } else {
        setState(() {
          directionOptions = foundRoutes;
          selectedDirectionIndex = 0;
        });
      }
    }
  Color _getLineColor(String stopId) {
    final lineName = _getLineName(stopId);
    if (lineName != null && lineColors.containsKey(lineName)) {
      return lineColors[lineName]!;
    }
    return Colors.purple;
  }

  Color _getPolylineColor(List<gtfs.Stop> stops) {
    if (stops.isEmpty) return Colors.purple;
    final lineName = _getLineName(stops.first.stopId);
    if (lineName != null && lineColors.containsKey(lineName)) {
      return lineColors[lineName]!;
    }
    return Colors.purple;
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

  List<gtfs.Stop> get directionStopsView {
    // Always show the full segment in correct order
    if (directionOptions.isNotEmpty && directionOptions[selectedDirectionIndex].isNotEmpty) {
      final stops = directionOptions[selectedDirectionIndex];
      // Sort by stop_sequence if available in stop_times
      // (Assumes _findDirection already provides correct order)
      return stops;
    }
    return [];
  }
  @override
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
    // Load time mappings used for travel time calculation
    await _loadTimeData();
    // Build linePrefixes and lineColors from routes
    Map<String, List<String>> prefixMap = {};
    Map<String, Color> colorMap = {};
    Map<String, String> colorHexMap = {};
    for (var route in routes) {
      prefixMap[route.longName] = route.linePrefixes;
      if (route.color != null && route.color!.isNotEmpty) {
        colorHexMap[route.longName] = route.color!;
        colorMap[route.longName] = Color(int.parse('0xFF${route.color!}'));
      }
    }
    setState(() {
      allRoutes = routes;
      allStops = stops;
      linePrefixes = prefixMap;
      lineColors = colorMap;
      lineColorHex = colorHexMap;
      lineStops = {};
      for (var stop in stops) {
        final lineName = _getLineName(stop.stopId);
        if (lineName != null) {
          lineStops.putIfAbsent(lineName, () => []).add(stop);
        }
      }
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
          stops.add(gtfs.Stop(
            stopId: row[0].trim(),
            name: row[1].trim(),
            lat: double.parse(row[2].trim()),
            lon: double.parse(row[3].trim()),
            code: row.length > 4 ? row[4] : null,
            desc: row.length > 5 ? row[5] : null,
            zoneId: row.length > 6 ? row[6] : null,
          ));
        } catch (_) {}
      }
      return stops;
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadTimeData() async {
    _timeMap.clear();
    try {
      final content = await rootBundle.loadString('assets/gtfs_data/TimeData.txt');
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return;
      final header = _parseCsvLine(lines[0]).map((s) => s.trim().toLowerCase()).toList();
      final idxStart = header.indexOf('startid');
      final idxEnd = header.indexOf('endid');
      final idxDur = header.indexOf('duration');
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = _parseCsvLine(line);
        if (idxStart < 0 || idxEnd < 0 || idxDur < 0) continue;
        if (row.length <= idxStart || row.length <= idxEnd || row.length <= idxDur) continue;
        final start = row[idxStart].trim();
        final end = row[idxEnd].trim();
        final durStr = row[idxDur].trim();
        // Policy: interpret '0000' or blank as 0; otherwise parse minutes
        int dur = int.tryParse(durStr) ?? 0;
        if (start.isEmpty || end.isEmpty) continue;
        _timeMap.putIfAbsent(start, () => {})[end] = dur;
      }
    } catch (_) {
      // ignore load errors silently
    }
  }

  int _calculateTravelTime(List<gtfs.Stop> routeStops) {
    if (routeStops.length <= 1) return 0;
    int total = 0;
    for (int i = 0; i < routeStops.length - 1; i++) {
      final a = routeStops[i].stopId.trim();
      final b = routeStops[i + 1].stopId.trim();
      final endMap = _timeMap[a];
      if (endMap == null) {
        // Missing-pair policy B: treat as 0 and log for visibility
        // ignore: avoid_print
        print('[Time] Missing start "$a" -> "$b"; using 0 minutes');
        continue;
      }
      final dur = endMap[b];
      if (dur == null) {
        // Missing-pair policy B
        // ignore: avoid_print
        print('[Time] Missing edge $a->$b; using 0 minutes');
        continue;
      }
      // 0 is valid (e.g., transfers not yet valued)
      total += dur;
    }
    return total;
  }

  Future<void> _loadFareMappings() async {
    fareTypeMap.clear();
    fareDataMap.clear();
    try {
      // Faretype mapping: fareId -> status ('m'|'s')
      final content = await rootBundle.loadString('assets/gtfs_data/Faretype.txt');
      final lines = const LineSplitter().convert(content);
      if (lines.length > 1) {
        final header = _parseCsvLine(lines[0]).map((s) => s.toLowerCase()).toList();
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
          final status = (row.length > idxStatus) ? row[idxStatus].trim().toLowerCase() : '';
          if (id.isNotEmpty && (status == 'm' || status == 's')) {
            fareTypeMap[id] = status;
          }
        }
      }
    } catch (_) {}

    try {
      // Fare data: fareDataId -> price
      final content = await rootBundle.loadString('assets/gtfs_data/FareData.txt');
      final lines = const LineSplitter().convert(content);
      if (lines.length > 1) {
        final header = _parseCsvLine(lines[0]).map((s) => s.toLowerCase()).toList();
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
          final price = (row.length > idxPrice) ? int.tryParse(row[idxPrice].trim()) ?? 0 : 0;
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
    final Map<int, int> specialIndexExtra = {}; // original index -> extra m-count (2)
    final Map<int, String> specialStatusOverride = {}; // original index -> overridden status ('s' or 'm')
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
    return {'mCount': mCount, 'sCount': sCount, 'mPrice': mPrice, 'sPrice': sPrice, 'total': total};
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
                MaterialPageRoute(builder: (context) => const TransportLinesPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                const Text('Start:'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedStartStopId,
                    decoration: const InputDecoration(
                      labelText: 'Start',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    items: lineStops.values.expand((l) => l)
                        .map((stop) => DropdownMenuItem(
                              value: stop.stopId,
                              child: Text(stop.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedStartStopId = value;
                      });
                    },
                  ),
                ),
              if (directionOptions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Fare: ฿$calculatedFare', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('m: $fareMCount → ฿$fareMPrice    s: $fareSCount → ฿$fareSPrice', style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 6),
                              Text('เวลาเดินทาง: $travelTimeMinutes นาที', style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {
                              // Optionally re-calculate or show details
                              final route = (directionOptions.isNotEmpty) ? directionOptions[selectedDirectionIndex] : null;
                              final fare = (route != null) ? _calculateFare(route) : null;
                              final time = (route != null) ? _calculateTravelTime(route) : null;
                              if (fare != null) {
                                setState(() {
                                  fareMCount = fare['mCount']!;
                                  fareSCount = fare['sCount']!;
                                  fareMPrice = fare['mPrice']!;
                                  fareSPrice = fare['sPrice']!;
                                  calculatedFare = fare['total']!;
                                  if (time != null) travelTimeMinutes = time;
                                });
                              }
                            },
                            child: const Text('Recalc'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Destination:'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedDestinationStopId,
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flag),
                    ),
                    items: lineStops.values.expand((l) => l)
                        .map((stop) => DropdownMenuItem(
                              value: stop.stopId,
                              child: Text(stop.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDestinationStopId = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _findDirection();
                  },
                  child: const Text('Go'),
                ),
              ],
            ),
              if (directionOptions.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text('Select Direction:'),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: selectedDirectionIndex,
                        items: List.generate(directionOptions.length, (i) => DropdownMenuItem(
                          value: i,
                          child: Text('Option ${i + 1}'),
                        )),
                        onChanged: (value) {
                          if (value != null) {
                            final route = directionOptions[value];
                            final fare = _calculateFare(route);
                            final timeMinutes = _calculateTravelTime(route);
                            setState(() {
                              selectedDirectionIndex = value;
                              fareMCount = fare['mCount']!;
                              fareSCount = fare['sCount']!;
                              fareMPrice = fare['mPrice']!;
                              fareSPrice = fare['sPrice']!;
                              calculatedFare = fare['total']!;
                              travelTimeMinutes = timeMinutes;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(13.7463, 100.5347), // Siam
                  initialZoom: 12.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.route',
                  ),
                  MarkerLayer(
                    markers: lineStops.values.expand((l) => l)
                        .map((stop) => Marker(
                              point: LatLng(stop.lat, stop.lon),
                              width: 15,
                              height: 15,
                              child: Tooltip(
                                message: stop.name,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _getLineColor(stop.stopId),
                                      width: 4,
                                    ),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  if (directionStopsView.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        for (var segment in _splitRouteByLine(directionStopsView))
                          if (segment.length >= 2)
                            Polyline(
                              points: segment.map((stop) => LatLng(stop.lat, stop.lon)).toList(),
                              color: _getPolylineColor(segment),
                              strokeWidth: 6.0,
                            ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
  //
}
