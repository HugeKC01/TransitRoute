import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
// Removed unused import 'dart:io'
import 'package:flutter/services.dart' show rootBundle;
// Removed unused imports
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
      final stopTimesLines = stopTimesContent.split('\n');
      if (stopTimesLines.length <= 1) return;
      // Parse stop_times
      final stopTimes = <String, List<Map<String, dynamic>>>{};
      for (var i = 1; i < stopTimesLines.length; i++) {
        final row = stopTimesLines[i].split(',');
        if (row.length < 5) continue;
        final tripId = row[0];
        final stopId = row[3];
        final stopSequence = int.tryParse(row[4]) ?? i;
        stopTimes.putIfAbsent(tripId, () => []).add({
          'stopId': stopId,
          'stopSequence': stopSequence,
        });
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
      if (selectedTripId == null) {
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
      setState(() {
        directionOptions = foundRoutes;
        selectedDirectionIndex = 0;
      });
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
    for (int i = 1; i < route.length; i++) {
      String line = _getLineName(route[i].stopId) ?? '';
      if (line != lastLine) {
        segments.add(current);
        current = [route[i]];
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
                            setState(() {
                              selectedDirectionIndex = value;
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
