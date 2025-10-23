// ...existing code...
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

    String? selectedStartStopId;
    String? selectedDestinationStopId;
    List<gtfs.Stop> directionStops = [];
    List<List<gtfs.Stop>> directionOptions = [];
    int selectedDirectionIndex = 0;

    void _findDirection() {
      if (selectedStartStopId == null || selectedDestinationStopId == null) return;
      // Find indices in BTS Sukhumvit Line
      final stops = btsStops;
      final startIdx = stops.indexWhere((s) => s.stopId == selectedStartStopId);
      final endIdx = stops.indexWhere((s) => s.stopId == selectedDestinationStopId);
      if (startIdx == -1 || endIdx == -1) return;
      final range = startIdx <= endIdx
          ? stops.sublist(startIdx, endIdx + 1)
          : stops.sublist(endIdx, startIdx + 1).reversed.toList();
      setState(() {
          directionOptions = [range, List<gtfs.Stop>.from(range.reversed)];
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedStartStopId,
                      decoration: const InputDecoration(
                        labelText: 'Start',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      items: btsStops.map((stop) => DropdownMenuItem(
                        value: stop.stopId,
                        child: Text(stop.name),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedStartStopId = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedDestinationStopId,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag),
                      ),
                      items: btsStops.map((stop) => DropdownMenuItem(
                        value: stop.stopId,
                        child: Text(stop.name),
                      )).toList(),
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
                  initialCenter: LatLng(13.7563, 100.5018), // Bangkok
                  initialZoom: 12.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.route',
                  ),
                  MarkerLayer(
                    markers: btsStops.map((stop) => Marker(
                      point: LatLng(stop.lat, stop.lon),
                      width: 40,
                      height: 40,
                      child: Tooltip(
                        message: stop.name,
                        child: const Icon(Icons.location_on, color: Colors.green, size: 32),
                      ),
                    )).toList(),
                  ),
                  if (directionStopsView.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: directionStopsView.map((stop) => LatLng(stop.lat, stop.lon)).toList(),
                          color: Colors.blue,
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
