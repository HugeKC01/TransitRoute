import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
// Removed unused import 'dart:io'
import 'package:flutter/services.dart' show rootBundle;
// Removed unused imports
import 'gtfs_models.dart' as gtfs;

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

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    final stops = await _parseStopsFromAsset('assets/gtfs_data/stops.txt');
    setState(() {
      // Filter only BTS Sukhumvit Line stops (E1-E16)
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

  // _parseStopsFromCsv removed, replaced by _parseStopsFromAsset

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
      body: FlutterMap(
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

}

class TransportLinesPage extends StatefulWidget {
  const TransportLinesPage({super.key});

  @override
  State<TransportLinesPage> createState() => _TransportLinesPageState();
}

class _TransportLinesPageState extends State<TransportLinesPage> {
  List<gtfs.Route> routes = [];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final content = await rootBundle.loadString('assets/gtfs_data/routes.txt');
      final lines = content.split('\n');
      if (lines.length <= 1) return;
      final loadedRoutes = <gtfs.Route>[];
      for (var i = 1; i < lines.length; i++) {
        final row = lines[i].split(',');
        if (row.length < 5) continue;
        loadedRoutes.add(gtfs.Route(
          routeId: row[0],
          agencyId: row[1],
          shortName: row[2],
          longName: row[3],
          type: row[4],
          color: row.length > 5 ? row[5] : null,
          textColor: row.length > 6 ? row[6] : null,
        ));
      }
      setState(() {
        routes = loadedRoutes;
      });
    } catch (_) {
      setState(() {
        routes = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Lines'),
      ),
      body: ListView.builder(
        itemCount: routes.length,
        itemBuilder: (context, index) {
          final route = routes[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: route.color != null && route.color!.isNotEmpty
                  ? Color(int.parse('0xFF${route.color}'))
                  : Colors.blue,
              child: Text(route.shortName, style: const TextStyle(color: Colors.white)),
            ),
            title: Text(route.longName),
            subtitle: Text(route.type),
          );
        },
      ),
    );
  }
}
