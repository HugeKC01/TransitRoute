import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
// Removed unused import 'dart:io'
import 'package:flutter/services.dart' show rootBundle;
// Removed unused imports
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
    final id = stopId.trim().toUpperCase();
    for (var entry in linePrefixes.entries) {
      for (var prefix in entry.value) {
        final p = prefix.trim().toUpperCase();
        if (p.isNotEmpty && id.startsWith(p)) return entry.key;
      }
    }
    return null;
  }
  Future<List<gtfs.Route>> _parseRoutesFromAsset(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      final lines = content.split(RegExp(r'\r?\n'));
      if (lines.length <= 1) return [];
      final routes = <gtfs.Route>[];
      final header = _parseCsvLine(lines[0]);
      final idxRouteId = header.indexOf('route_id');
      final idxAgencyId = header.indexOf('agency_id');
      final idxShortName = header.indexOf('route_short_name');
      final idxLongName = header.indexOf('route_long_name');
      final idxType = header.indexOf('route_type');
      final idxColor = header.indexOf('route_color');
      final idxTextColor = header.indexOf('route_text_color');
      final idxLinePrefixes = header.indexOf('line_prefixes');
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        final row = _parseCsvLine(lines[i]);
        // ensure we have at least route_id and route_long_name
        if (row.length <= 1) continue;
        // parse prefixes field more robustly (support separators like | or ;)
        List<String> parsedPrefixes = [];
        if (idxLinePrefixes >= 0 && row.length > idxLinePrefixes) {
          final raw = row[idxLinePrefixes];
          // split by common separators, then trim and uppercase
          parsedPrefixes = raw
              .split(RegExp(r'[|;,/]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .map((s) => s.toUpperCase())
              .toList();
        }
        // safe access helper
        String safeAt(int idx) => (idx >= 0 && idx < row.length) ? row[idx].trim() : '';
        routes.add(gtfs.Route(
          routeId: safeAt(idxRouteId),
          agencyId: safeAt(idxAgencyId),
          shortName: safeAt(idxShortName),
          longName: safeAt(idxLongName),
          type: safeAt(idxType),
          color: idxColor >= 0 ? safeAt(idxColor) : null,
          textColor: idxTextColor >= 0 ? safeAt(idxTextColor) : null,
          linePrefixes: parsedPrefixes,
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

    void _findDirection() {
      if (selectedStartStopId == null || selectedDestinationStopId == null) return;
      final allStopsFlat = lineStops.values.expand((l) => l).toList();
      gtfs.Stop? startStop;
      gtfs.Stop? endStop;
      for (var s in allStopsFlat) {
        if (s.stopId == selectedStartStopId) { startStop = s; break; }
      }
      for (var s in allStopsFlat) {
        if (s.stopId == selectedDestinationStopId) { endStop = s; break; }
      }
      if (startStop == null || endStop == null) return;

      // Build adjacency map: stopId -> list of directly connected stopIds (including transfers)
      Map<String, List<String>> adjacency = {};
      // Connect consecutive stops within each line
      for (var stops in lineStops.values) {
        for (int i = 0; i < stops.length; i++) {
          final curr = stops[i].stopId;
          adjacency.putIfAbsent(curr, () => []);
          if (i > 0) adjacency[curr]!.add(stops[i - 1].stopId);
          if (i < stops.length - 1) adjacency[curr]!.add(stops[i + 1].stopId);
        }
      }
      // Add transfer connections: connect stops with the same coordinates (lat/lon) across all lines
      Map<String, List<gtfs.Stop>> stopsByCoord = {};
      for (var stop in allStopsFlat) {
        final key = '${stop.lat.toStringAsFixed(5)},${stop.lon.toStringAsFixed(5)}';
        stopsByCoord.putIfAbsent(key, () => []).add(stop);
      }
      for (var entry in stopsByCoord.entries) {
        final stopsAtCoord = entry.value;
        for (var a in stopsAtCoord) {
          for (var b in stopsAtCoord) {
            if (a.stopId != b.stopId) {
              adjacency[a.stopId] ??= [];
              if (!adjacency[a.stopId]!.contains(b.stopId)) adjacency[a.stopId]!.add(b.stopId);
            }
          }
        }
      }
      // BFS to find shortest path
      Map<String, String?> prev = {};
      Set<String> visited = {};
      List<String> queue = [startStop.stopId];
      visited.add(startStop.stopId);
      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        if (current == endStop.stopId) break;
        for (final neighbor in adjacency[current] ?? []) {
          if (!visited.contains(neighbor)) {
            visited.add(neighbor);
            prev[neighbor] = current;
            queue.add(neighbor);
          }
        }
      }
      // Reconstruct path
      List<String> pathIds = [];
      String? curr = endStop.stopId;
      while (curr != null && curr != startStop.stopId) {
        pathIds.insert(0, curr);
        curr = prev[curr];
      }
      if (curr != null && curr == startStop.stopId) pathIds.insert(0, curr);
      if (pathIds.isEmpty || pathIds.first != startStop.stopId || pathIds.last != endStop.stopId) return;
      // Map stopIds to gtfs.Stop objects
      List<gtfs.Stop> route = [];
      for (var id in pathIds) {
        gtfs.Stop? found;
        for (var s in allStopsFlat) {
          if (s.stopId == id) { found = s; break; }
        }
        if (found != null) route.add(found);
      }
      setState(() {
        directionOptions = [route, List<gtfs.Stop>.from(route.reversed)];
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

  List<gtfs.Stop> get directionStopsView =>
    directionOptions.isNotEmpty ? directionOptions[selectedDirectionIndex] : [];
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
      final lines = content.split(RegExp(r'\r?\n'));
      if (lines.length <= 1) return [];
      final stops = <gtfs.Stop>[];
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        final row = _parseCsvLine(lines[i]);
        if (row.length < 4) continue;
        try {
          stops.add(gtfs.Stop(
            stopId: row[0],
            name: row[1],
            lat: double.parse(row[2]),
            lon: double.parse(row[3]),
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
    // Simple CSV parser that handles quoted fields and commas inside quotes.
    final List<String> parts = [];
    final buffer = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (ch == ',' && !inQuotes) {
        parts.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    parts.add(buffer.toString());
    // Trim whitespace and remove any stray CR/LF
    return parts.map((s) => s.trim().replaceAll('\r', '').replaceAll('\n', '')).toList();
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
}
 
 