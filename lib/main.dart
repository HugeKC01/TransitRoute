import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

void main() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: OSMFlutter(
        controller: MapController(
          initPosition: GeoPoint(latitude: 13.74, longitude: 100.53), // Example: Bangkok
        ),
        osmOption: OSMOption(
          zoomOption: ZoomOption(
            initZoom: 12,
            minZoomLevel: 2,
            maxZoomLevel: 18,
            stepZoom: 1.0,
          ),
          userTrackingOption: UserTrackingOption(
            enableTracking: false,
            unFollowUser: false,
          ),
        ),
      ),
    );
  }
}
