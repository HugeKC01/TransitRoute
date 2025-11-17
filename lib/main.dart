import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:math' as math;
import 'package:route/services/direction_service.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;

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
  Map<String, gtfs.Stop> stopLookup = {};
  late DirectionService _directionService;

  Map<String, List<String>> linePrefixes = {};
  Map<String, Color> lineColors = {};
  List<gtfs.Route> allRoutes = [];
  // Fare mappings (loaded from assets)
  Map<String, String> fareTypeMap = {}; // fareId -> 'm'|'s'
  Map<String, int> fareDataMap = {}; // e.g. 'm3' -> 28

  // Routing preference: 'Shortest', 'Fastest', 'Cheapest'
  String routingMode = 'Shortest';

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
  List<DirectionOption> directionOptions = [];
  int selectedDirectionIndex = 0;

  Future<void> _findDirection() async {
    if (allStops.isEmpty) {
      return;
    }
    final startId = selectedStartStopId;
    final destId = selectedDestinationStopId;
    if (startId == null || destId == null) {
      return;
    }
    final result = await _directionService.findDirections(
      routingMode: routingMode,
      startStopId: startId,
      destStopId: destId,
    );
    setState(() {
      directionOptions = List<DirectionOption>.from(result.options);
      if (directionOptions.isEmpty) {
        selectedDirectionIndex = 0;
      } else {
        selectedDirectionIndex = result.selectionIndex.clamp(
          0,
          directionOptions.length - 1,
        );
      }
    });
  }

  Color _getLineColor(String stopId) {
    final lineName = _getLineName(stopId);
    if (lineName != null && lineColors.containsKey(lineName)) {
      return lineColors[lineName]!;
    }
    return Colors.purple;
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

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
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
    final selectedOption = directionOptions[index];
    String? nextMode;
    for (final candidate in order) {
      if (selectedOption.tags.contains(candidate)) {
        nextMode = candidate;
        break;
      }
    }
    final reordered = <DirectionOption>[selectedOption];
    for (int i = 0; i < directionOptions.length; i++) {
      if (i == index) continue;
      reordered.add(directionOptions[i]);
    }
    setState(() {
      directionOptions = reordered;
      selectedDirectionIndex = 0;
      if (nextMode != null) {
        routingMode = nextMode;
      }
    });
  }

  Widget _buildRouteOptionsSection(BuildContext context) {
    if (directionOptions.isEmpty) return const SizedBox.shrink();
    final optionWidgets = <Widget>[
      Text(
        'Route options',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
    ];
    optionWidgets.addAll(
      List.generate(
        directionOptions.length,
        (index) => _buildRouteOptionCard(context, index),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: optionWidgets,
      ),
    );
  }

  Widget _buildRouteOptionCard(BuildContext context, int index) {
    if (index < 0 || index >= directionOptions.length) {
      return const SizedBox.shrink();
    }
    final option = directionOptions[index];
    final stops = option.stops;
    if (stops.isEmpty) return const SizedBox.shrink();
    final label = option.label.isNotEmpty
        ? option.label
        : 'Option ${index + 1}';
    final tags = option.tags;
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
    final distanceText = _formatDistance(option.distanceMeters);
    final minutes = option.minutes;
    final fare = option.fareBreakdown;
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
        directionOptions[selectedDirectionIndex].stops.isNotEmpty) {
      return directionOptions[selectedDirectionIndex].stops;
    }
    return const <gtfs.Stop>[];
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
    _directionService = DirectionService(lineNameResolver: _getLineName);
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
    final stopMap = {for (final stop in stops) stop.stopId: stop};
    _directionService.updateData(
      allStops: stops,
      stopLookup: stopMap,
      routes: routes,
      fareTypeMap: fareTypeMap,
      fareDataMap: fareDataMap,
    );
    setState(() {
      allRoutes = routes;
      allStops = stops;
      linePrefixes = prefixMap;
      lineColors = colorMap;
      stopLookup = stopMap;
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
