import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:route/services/direction_service.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;
import 'package:route/services/gtfs_shapes.dart';

import 'transport_lines_page.dart';
import 'widgets/route_details_sheet.dart';
import 'widgets/route_options_panel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
  late final SearchController _stopSearchController;
  List<gtfs.Stop> allStops = [];
  Map<String, gtfs.Stop> stopLookup = {};
  late DirectionService _directionService;

  Map<String, List<String>> linePrefixes = {};
  Map<String, Color> lineColors = {};
  List<gtfs.Route> allRoutes = [];
  bool _didFitRails = false;
  List<ShapeSegment> shapeSegments = [];
  Map<String, String> fareTypeMap = {};
  Map<String, int> fareDataMap = {};

  String routingMode = 'Shortest';

  String? _getLineName(String stopId) {
    for (final entry in linePrefixes.entries) {
      for (final prefix in entry.value) {
        if (stopId.startsWith(prefix)) return entry.key;
      }
    }
    return null;
  }

  bool _hasThaiName(gtfs.Stop stop) {
    final value = stop.thaiName;
    return value != null && value.isNotEmpty;
  }

  String _stopDisplayLabel(gtfs.Stop stop) {
    final thai = stop.thaiName;
    if (thai == null || thai.isEmpty) {
      return stop.name;
    }
    return '${stop.name} • $thai';
  }

  Widget _stopNameLabel(gtfs.Stop stop, TextTheme textTheme) {
    if (!_hasThaiName(stop)) {
      return Text(stop.name);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(stop.name),
        Text(
          stop.thaiName!,
          style: textTheme.bodySmall,
        ),
      ],
    );
  }

  int _stopPrefixScore(gtfs.Stop stop, String query) {
    final english = stop.name.toLowerCase();
    final thai = (stop.thaiName ?? '').toLowerCase();
    return (english.startsWith(query) || thai.startsWith(query)) ? 0 : 1;
  }

  void _adjustMapZoom(double delta) {
    final camera = _mapController.camera;
    final newZoom = (camera.zoom + delta).clamp(3.0, 19.0);
    _mapController.move(camera.center, newZoom);
  }

  Widget _zoomButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      elevation: 3,
      shape: const CircleBorder(),
      color: Colors.white,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.black87),
        ),
      ),
    );
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
      if (currentLine == previousLine) {
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

  void _assignStopSelection(gtfs.Stop stop, {required bool asStart}) {
    setState(() {
      if (asStart) {
        selectedStartStopId = stop.stopId;
      } else {
        selectedDestinationStopId = stop.stopId;
      }
    });
  }

  void _showStopDetails(BuildContext context, gtfs.Stop stop) {
    final lineName = _getLineName(stop.stopId);
    final lineColor = _getLineColor(stop.stopId);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final subtitleStyle = theme.textTheme.bodyMedium;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: lineColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          style: theme.textTheme.titleLarge,
                        ),
                        if (_hasThaiName(stop))
                          Text(
                            stop.thaiName!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Stop ID: ${stop.stopId}', style: subtitleStyle),
              if (lineName != null)
                Text('Line: $lineName', style: subtitleStyle),
              Text(
                'Lat: ${stop.lat.toStringAsFixed(5)}, Lon: ${stop.lon.toStringAsFixed(5)}',
                style: subtitleStyle,
              ),
              if (stop.zoneId != null && stop.zoneId!.isNotEmpty)
                Text('Zone: ${stop.zoneId}', style: subtitleStyle),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _assignStopSelection(stop, asStart: true);
                },
                icon: const Icon(Icons.trip_origin),
                label: const Text('Use as starting point'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _assignStopSelection(stop, asStart: false);
                },
                icon: const Icon(Icons.flag),
                label: const Text('Use as destination'),
              ),
            ],
          ),
        );
      },
    );
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
    if (directionOptions.isEmpty) {
      return const SizedBox.shrink();
    }
    return RouteOptionsPanel(
      options: directionOptions,
      selectedIndex: selectedDirectionIndex,
      onSelectOption: _selectRouteOption,
      onViewDetails: (option) => showRouteDetailsSheet(
        context: context,
        option: option,
        lineNameResolver: _getLineName,
        lineColorResolver: _getLineColor,
        lineColors: lineColors,
      ),
      lineNameResolver: _getLineName,
      lineColors: lineColors,
    );
  }

  Widget _buildMap(BuildContext context) {
    final startId = selectedStartStopId;
    final destId = selectedDestinationStopId;
    final routeStops = directionStopsView;
    final viewPadding = MediaQuery.of(context).padding;
    return Stack(
      children: [
        FlutterMap(
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
            if (shapeSegments.isNotEmpty)
              PolylineLayer(
                polylines: shapeSegments
                    .map(
                      (s) => Polyline(
                        points: s.points,
                        color: s.color,
                        strokeWidth: 6.0,
                      ),
                    )
                    .toList(),
              ),
            if (allStops.isNotEmpty)
              MarkerLayer(
                markers: allStops
                    .map(
                      (stop) => Marker(
                        point: LatLng(stop.lat, stop.lon),
                        width:
                            (stop.stopId == startId || stop.stopId == destId)
                                ? 22
                                : 16,
                        height:
                            (stop.stopId == startId || stop.stopId == destId)
                                ? 22
                                : 16,
                        child: GestureDetector(
                          onTap: () => _showStopDetails(context, stop),
                          child: Tooltip(
                            message: _stopDisplayLabel(stop),
                            child: Container(
                              decoration: BoxDecoration(
                                color: (stop.stopId == startId)
                                    ? Colors.greenAccent
                                        .withValues(alpha: 0.85)
                                    : (stop.stopId == destId)
                                        ? Colors.redAccent
                                            .withValues(alpha: 0.85)
                                        : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _getLineColor(stop.stopId),
                                  width: (stop.stopId == startId ||
                                          stop.stopId == destId)
                                      ? 4
                                      : 3,
                                ),
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
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Positioned(
          right: 16,
          top: viewPadding.top + 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _zoomButton(
                icon: Icons.add,
                onTap: () => _adjustMapZoom(0.75),
              ),
              const SizedBox(height: 12),
              _zoomButton(
                icon: Icons.remove,
                onTap: () => _adjustMapZoom(-0.75),
              ),
            ],
          ),
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
    final textTheme = Theme.of(context).textTheme;
    final dropdownItems = stops
        .map(
          (stop) => DropdownMenuItem<String>(
            value: stop.stopId,
            child: _stopNameLabel(stop, textTheme),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;

              Widget buildRoutingModeSelector() {
                final button = FilledButton.icon(
                  onPressed: (selectedStartStopId != null &&
                          selectedDestinationStopId != null)
                      ? () => _findDirection()
                      : null,
                  icon: const Icon(Icons.route),
                  label: const Text('Plan route'),
                );

                final segmented = SegmentedButton<String>(
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
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      segmented,
                      const SizedBox(height: 12),
                      button,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: segmented),
                    const SizedBox(width: 12),
                    button,
                  ],
                );
              }

              Widget buildDropdown(
                String label,
                IconData icon,
                String? value,
                ValueChanged<String?> onChanged,
              ) {
                return DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: value,
                  decoration: InputDecoration(
                    labelText: label,
                    prefixIcon: Icon(icon),
                    border: const OutlineInputBorder(),
                  ),
                  items: dropdownItems,
                  onChanged: onChanged,
                );
              }

              Widget buildStopSelectors() {
                final swapButton = IconButton(
                  tooltip: 'Swap start and destination',
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: (selectedStartStopId != null ||
                          selectedDestinationStopId != null)
                      ? () => _swapStops()
                      : null,
                );

                final startField = buildDropdown(
                  'Start station',
                  Icons.trip_origin,
                  startValue,
                  (value) {
                    setState(() {
                      selectedStartStopId = value;
                    });
                  },
                );
                final destField = buildDropdown(
                  'Destination',
                  Icons.flag,
                  destValue,
                  (value) {
                    setState(() {
                      selectedDestinationStopId = value;
                    });
                  },
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      startField,
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: swapButton,
                      ),
                      const SizedBox(height: 12),
                      destField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: startField),
                    const SizedBox(width: 12),
                    swapButton,
                    const SizedBox(width: 12),
                    Expanded(child: destField),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildRoutingModeSelector(),
                  const SizedBox(height: 16),
                  buildStopSelectors(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SearchAnchor(
        searchController: _stopSearchController,
        builder: (context, controller) {
          return SearchBar(
            controller: controller,
            hintText: 'Search stations',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll<double>(2),
            onTap: controller.openView,
            onChanged: (value) {
              if (!controller.isOpen) {
                controller.openView();
              }
              setState(() {});
            },
            trailing: [
              if (controller.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear',
                  onPressed: () {
                    controller.text = '';
                    setState(() {});
                  },
                  icon: const Icon(Icons.close),
                ),
            ],
          );
        },
        suggestionsBuilder: (context, controller) {
          final results = _filterStops(controller.text);
          if (results.isEmpty) {
            return [
              const ListTile(
                leading: Icon(Icons.search_off),
                title: Text('No stations found'),
              ),
            ];
          }
          return results.map(
            (stop) => ListTile(
              leading: CircleAvatar(
                radius: 12,
                backgroundColor: _getLineColor(stop.stopId),
              ),
              title: Text(stop.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasThaiName(stop))
                    Text(
                      stop.thaiName!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Text(
                    'ID: ${stop.stopId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              onTap: () {
                controller.closeView(stop.name);
                _handleSearchSelection(stop);
              },
            ),
          );
        },
      ),
    );
  }

  List<gtfs.Stop> _filterStops(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty || allStops.isEmpty) {
      return const [];
    }
    final matches = allStops.where((stop) {
      final name = stop.name.toLowerCase();
      final code = stop.stopId.toLowerCase();
      final thai = (stop.thaiName ?? '').toLowerCase();
      return name.contains(trimmed) ||
          code.contains(trimmed) ||
          thai.contains(trimmed);
    }).toList();
    matches.sort((a, b) {
      final aScore = _stopPrefixScore(a, trimmed);
      final bScore = _stopPrefixScore(b, trimmed);
      if (aScore != bScore) return aScore.compareTo(bScore);
      return _stopDisplayLabel(a).compareTo(_stopDisplayLabel(b));
    });
    return matches.take(8).toList();
  }

  Future<void> _handleSearchSelection(gtfs.Stop stop) async {
    if (!mounted) return;
    String? target;
    if (selectedStartStopId == null) {
      target = 'start';
    } else if (selectedDestinationStopId == null) {
      target = 'destination';
    } else {
      target = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.trip_origin),
                title: const Text('Set as start station'),
                onTap: () => Navigator.pop(context, 'start'),
              ),
              ListTile(
                leading: const Icon(Icons.flag),
                title: const Text('Set as destination'),
                onTap: () => Navigator.pop(context, 'destination'),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context, null),
              ),
            ],
          ),
        ),
      );
    }
    if (target == null) return;
    setState(() {
      if (target == 'start') {
        selectedStartStopId = stop.stopId;
      } else if (target == 'destination') {
        selectedDestinationStopId = stop.stopId;
      }
    });
    final zoom = math.max(_mapController.camera.zoom, 14).toDouble();
    _mapController.move(LatLng(stop.lat, stop.lon), zoom);
    if (selectedStartStopId != null && selectedDestinationStopId != null) {
      await _findDirection();
    }
  }

  List<gtfs.Stop> get directionStopsView {
    if (directionOptions.isNotEmpty &&
        selectedDirectionIndex < directionOptions.length &&
        directionOptions[selectedDirectionIndex].stops.isNotEmpty) {
      return directionOptions[selectedDirectionIndex].stops;
    }
    return const <gtfs.Stop>[];
  }

  @override
  void initState() {
    super.initState();
    _stopSearchController = SearchController();
    _directionService = DirectionService(lineNameResolver: _getLineName);
    _loadRoutesAndStops();
  }

  @override
  void dispose() {
    _stopSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutesAndStops() async {
    final routes = await _parseRoutesFromAsset('assets/gtfs_data/routes.txt');
    final thaiNames = await _loadThaiStopNames();
    final stops = await _parseStopsFromAsset(
      'assets/gtfs_data/stops.txt',
      thaiNames: thaiNames,
    );
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
    // Load GTFS shapes (preferred) — use tripMap loaded from DirectionService to avoid re-parsing
    List<ShapeSegment> shapes = const <ShapeSegment>[];
    try {
      final tripMap = await _directionService.loadTrips();
      shapes = await GtfsShapesService().loadSegments(
        shapesAsset: 'assets/gtfs_data/shapes.txt',
        routeColors: {for (final r in routes) r.routeId: (r.color != null && r.color!.isNotEmpty) ? Color(int.parse('0xFF${r.color!}')) : Colors.purple},
        tripMap: tripMap,
      );
    } catch (_) {}
    setState(() {
      allRoutes = routes;
      allStops = stops;
      linePrefixes = prefixMap;
      lineColors = colorMap;
      stopLookup = stopMap;
      shapeSegments = shapes;
    });
    // Fit camera once on initial load based on shapes
    if (!_didFitRails) {
      final allPts = <LatLng>[];
      for (final seg in shapeSegments) {
        allPts.addAll(seg.points);
      }
      if (allPts.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(allPts);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(24),
          ),
        );
        _didFitRails = true;
      }
    }
  }

  // _loadStops is now replaced by _loadRoutesAndStops

  Future<List<gtfs.Stop>> _parseStopsFromAsset(
    String assetPath, {
    Map<String, String>? thaiNames,
  }) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return [];
      final header = _parseCsvLine(lines.first).map((s) => s.trim()).toList();
      int idxStopId = header.indexOf('stop_id');
      if (idxStopId < 0) idxStopId = 0;
      int idxName = header.indexOf('stop_name');
      if (idxName < 0) idxName = 1;
      final idxThai = header.indexOf('stop_name_th');
      int idxLat = header.indexOf('stop_lat');
      if (idxLat < 0) idxLat = 2;
      int idxLon = header.indexOf('stop_lon');
      if (idxLon < 0) idxLon = 3;
      final idxCode = header.indexOf('stop_code');
      final idxDesc = header.indexOf('stop_desc');
      final idxZone = header.indexOf('zone_id');
      final stops = <gtfs.Stop>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = _parseCsvLine(line);
        if (row.length <= idxStopId || row.length <= idxName) continue;
        if (row.length <= idxLat || row.length <= idxLon) continue;
        final stopId = row[idxStopId].trim();
        if (stopId.isEmpty) continue;
        final name = row[idxName].trim();
        final lat = double.tryParse(row[idxLat].trim());
        final lon = double.tryParse(row[idxLon].trim());
        if (lat == null || lon == null) continue;
        final thaiFromFile = idxThai >= 0 && row.length > idxThai
          ? row[idxThai].trim()
          : '';
        final thaiOverrideRaw = thaiNames?[stopId];
        final thaiOverride = thaiOverrideRaw?.trim();
        final thai = (thaiOverride != null && thaiOverride.isNotEmpty)
          ? thaiOverride
          : (thaiFromFile.isNotEmpty ? thaiFromFile : null);
        stops.add(
          gtfs.Stop(
            stopId: stopId,
            name: name,
            thaiName: thai,
            lat: lat,
            lon: lon,
            code: (idxCode >= 0 && row.length > idxCode)
                ? row[idxCode].trim()
                : null,
            desc: (idxDesc >= 0 && row.length > idxDesc)
                ? row[idxDesc].trim()
                : null,
            zoneId: (idxZone >= 0 && row.length > idxZone)
                ? row[idxZone].trim()
                : null,
          ),
        );
      }
      return stops;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, String>> _loadThaiStopNames() async {
    try {
      final content = await rootBundle.loadString(
        'assets/gtfs_data/station_names_th.csv',
      );
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return const {};
      final header = _parseCsvLine(lines.first).map((s) => s.toLowerCase()).toList();
      int idxId = header.indexOf('stop_id');
      if (idxId < 0) idxId = 0;
      int idxName = header.indexOf('stop_name_th');
      if (idxName < 0) idxName = header.length > 1 ? 1 : 0;
      final map = <String, String>{};
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = _parseCsvLine(line);
        if (row.length <= idxId || row.length <= idxName) continue;
        final id = row[idxId].trim();
        final name = row[idxName].trim();
        if (id.isEmpty || name.isEmpty) continue;
        map[id] = name;
      }
      return map;
    } catch (_) {
      return const {};
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
        child: Column(
          children: [
            _buildSearchBar(context),
            Expanded(
              child: isWideLayout
                  ? _buildWideLayout(context)
                  : _buildPhoneLayout(context),
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
