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
  List<gtfs.Stop> btsStops = [];
  List<gtfs.Stop> allStops = [];
  List<gtfs.Stop> destinationResults = [];
  List<gtfs.Stop> silomStops = [];
  String selectedLine = 'Auto';

    String? selectedStartStopId;
    String? selectedDestinationStopId;
    List<gtfs.Stop> directionStops = [];
    List<List<gtfs.Stop>> directionOptions = [];
    int selectedDirectionIndex = 0;

    void _findDirection() {
      if (selectedStartStopId == null || selectedDestinationStopId == null) return;
      // Cross-line navigation: find route across Sukhumvit and Silom, transfer at Siam if needed
    final allBtsStops = [...btsStops, ...silomStops];
    final startStop = allBtsStops.where((s) => s.stopId == selectedStartStopId).isNotEmpty
      ? allBtsStops.firstWhere((s) => s.stopId == selectedStartStopId)
      : null;
    final endStop = allBtsStops.where((s) => s.stopId == selectedDestinationStopId).isNotEmpty
      ? allBtsStops.firstWhere((s) => s.stopId == selectedDestinationStopId)
      : null;
    if (startStop == null || endStop == null) return;

      bool startIsSukhumvit = btsStops.any((s) => s.stopId == startStop.stopId);
      bool endIsSukhumvit = btsStops.any((s) => s.stopId == endStop.stopId);
      bool startIsSilom = silomStops.any((s) => s.stopId == startStop.stopId);
      bool endIsSilom = silomStops.any((s) => s.stopId == endStop.stopId);

      List<gtfs.Stop> route = [];
      if ((startIsSukhumvit && endIsSukhumvit) || (startIsSilom && endIsSilom)) {
        // Same line navigation
        final stops = startIsSukhumvit ? btsStops : silomStops;
        final startIdx = stops.indexWhere((s) => s.stopId == startStop.stopId);
        final endIdx = stops.indexWhere((s) => s.stopId == endStop.stopId);
        if (startIdx == -1 || endIdx == -1) return;
        route = startIdx <= endIdx
            ? stops.sublist(startIdx, endIdx + 1)
            : stops.sublist(endIdx, startIdx + 1).reversed.toList();
      } else {
        // Cross-line navigation, transfer at Siam (E16/S2)
        final siamSukhumvitIdx = btsStops.indexWhere((s) => s.stopId == 'E16');
        final siamSilomIdx = silomStops.indexWhere((s) => s.stopId == 'S2');
        if (siamSukhumvitIdx == -1 || siamSilomIdx == -1) return;
        if (startIsSukhumvit && endIsSilom) {
          final startIdx = btsStops.indexWhere((s) => s.stopId == startStop.stopId);
          final siamIdx = siamSukhumvitIdx;
          final endIdx = silomStops.indexWhere((s) => s.stopId == endStop.stopId);
          if (startIdx == -1 || endIdx == -1) return;
          final seg1 = startIdx <= siamIdx
              ? btsStops.sublist(startIdx, siamIdx + 1)
              : btsStops.sublist(siamIdx, startIdx + 1).reversed.toList();
          final seg2 = siamSilomIdx <= endIdx
              ? silomStops.sublist(siamSilomIdx, endIdx + 1)
              : silomStops.sublist(endIdx, siamSilomIdx + 1).reversed.toList();
          route = [...seg1, ...seg2];
        } else if (startIsSilom && endIsSukhumvit) {
          final startIdx = silomStops.indexWhere((s) => s.stopId == startStop.stopId);
          final siamIdx = siamSilomIdx;
          final endIdx = btsStops.indexWhere((s) => s.stopId == endStop.stopId);
          if (startIdx == -1 || endIdx == -1) return;
          final seg1 = startIdx <= siamIdx
              ? silomStops.sublist(startIdx, siamIdx + 1)
              : silomStops.sublist(siamIdx, startIdx + 1).reversed.toList();
          final seg2 = siamSukhumvitIdx <= endIdx
              ? btsStops.sublist(siamSukhumvitIdx, endIdx + 1)
              : btsStops.sublist(endIdx, siamSukhumvitIdx + 1).reversed.toList();
          route = [...seg1, ...seg2];
        }
      }
      setState(() {
        directionOptions = [route, List<gtfs.Stop>.from(route.reversed)];
        selectedDirectionIndex = 0;
      });
    }

  List<gtfs.Stop> get directionStopsView =>
    directionOptions.isNotEmpty ? directionOptions[selectedDirectionIndex] : [];
  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    final stops = await _parseStopsFromAsset('assets/gtfs_data/stops.txt');
    setState(() {
      allStops = stops;
      btsStops = stops.where((s) => s.stopId.startsWith('E')).toList();
      silomStops = stops.where((s) => s.stopId.startsWith('S')).toList();
    });
  }

  Future<List<gtfs.Stop>> _parseStopsFromAsset(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      final lines = content.split('\n');
      if (lines.length <= 1) return [];
      final stops = <gtfs.Stop>[];
      for (var i = 1; i < lines.length; i++) {
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
    // Simple CSV parser (no quoted fields)
    return line.split(',');
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
                    items: [...btsStops, ...silomStops]
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
                    items: [...btsStops, ...silomStops]
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
                    markers: [...btsStops, ...silomStops]
                        .map((stop) => Marker(
                              point: LatLng(stop.lat, stop.lon),
                              width: 40,
                              height: 40,
                              child: Tooltip(
                                message: stop.name,
                                child: Icon(
                                  Icons.location_on,
                                  color: btsStops.any((s) => s.stopId == stop.stopId)
                                      ? Colors.green
                                      : Colors.orange,
                                  size: 32,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  if (directionStopsView.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: directionStopsView.map((stop) => LatLng(stop.lat, stop.lon)).toList(),
                          color: directionStopsView.every((s) => btsStops.any((b) => b.stopId == s.stopId))
                              ? Colors.green
                              : directionStopsView.every((s) => silomStops.any((b) => b.stopId == s.stopId))
                                  ? Colors.orange
                                  : Colors.purple,
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
