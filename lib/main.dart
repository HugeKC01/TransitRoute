import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'widgets/station_details_content.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:route/services/direction_service.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;
import 'package:route/services/gtfs_shapes.dart';
import 'package:route/services/route_asset_loader.dart';
import 'package:route/services/transit_update_service.dart';

import 'pages/more_page.dart';
import 'pages/cards_page.dart';
import 'pages/transit_update_page.dart';
import 'pages/transit_updates_list_page.dart';
import 'pages/transport_lines_page.dart';
import 'pages/navigation_page.dart';
import 'pages/graphic_map_page.dart';
import 'widgets/route_details_sheet.dart';
import 'widgets/route_options_panel.dart';

import 'widgets/search_tabs.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Color _accentColor = Colors.blue;

  void _updateAccentColor(Color color) {
    setState(() {
      _accentColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scrollBehavior: AppScrollBehavior(),
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.googleSansTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: _accentColor),
      ),
      home: MyHomePage(
        title: 'Flutter Demo Home Page',
        currentAccentColor: _accentColor,
        onAccentColorChanged: _updateAccentColor,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.currentAccentColor,
    required this.onAccentColorChanged,
  });

  final String title;
  final Color currentAccentColor;
  final ValueChanged<Color> onAccentColorChanged;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _ProjectionResult {
  final LatLng point;
  final double dist;
  _ProjectionResult(this.point, this.dist);
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final SearchController _startSearchController;
  late final SearchController _destSearchController;
  late final SearchController _collapsedSearchController;
  int _selectedNavIndex = 0;
  final Profile _profile = const Profile(
    username: 'hugekc',
    name: 'Kittichai Chaimongkol',
    joinedDate: 'Jan 2024',
    profileImageUrl: 'https://randomuser.me/api/portraits/men/32.jpg',
  );
  // Combined stops used for search/routing (rail + bus)
  List<gtfs.Stop> allStops = [];
  // Rail-only stops for the default rail marker layer
  List<gtfs.Stop> railStops = [];
  Map<String, gtfs.Stop> stopLookup = {};
  late DirectionService _directionService;

  Map<String, List<String>> linePrefixes = {};
  final Map<String, Set<String>> _stopToLinesMap = {};
  Map<String, Color> lineColors = {};
  List<gtfs.Route> allRoutes = [];
  bool _didFitRails = false;
  List<ShapeSegment> shapeSegments = [];
  List<gtfs.Stop> busStops = [];
  List<gtfs.Stop> ferryStops = [];
  Map<String, String> fareTypeMap = {};
  Map<String, gtfs.BusRouteInfo> busRouteInfoMap = {};
  Map<String, int> fareDataMap = {};
  Map<String, int> stopOrderMap = {};
  Map<String, List<int>> fareTableMap = {};
  Map<String, int> ferryFlatFares = {};
  Map<String, int> ferryZoneMatrix = {};
  Map<String, String> ferryZones = {};

  String routingMode = 'Fastest';
  List<String> allowedTransitTypes = ['Metro', 'Train', 'Bus', 'Ferry'];
  final ValueNotifier<bool> _headerCollapsed = ValueNotifier<bool>(false);
  double _currentZoom = 12.0;
  static const double _busStopZoomThreshold = 15.0;

  bool _showTrainPins = true;
  bool _showMetroPins = true;
  bool _showBusPins = true;
  bool _showFerryPins = true;

  LocationData? _userLocation;
  StreamSubscription<LocationData>? _locationSub;

  final GlobalKey _mapKey = GlobalKey();
  LatLng _currentCenter = const LatLng(13.7463, 100.5347);

  List<String> _getLineNames(String stopId) {
    if (stopId.startsWith('ST_') || stopId.startsWith('STOP_')) {
      return ['BMTA Bus'];
    }
    if (_stopToLinesMap.containsKey(stopId) &&
        _stopToLinesMap[stopId]!.isNotEmpty) {
      return _stopToLinesMap[stopId]!.toList()..sort();
    }
    return [];
  }

  String? _getLineName(String stopId) {
    if (stopId.startsWith('ST_') || stopId.startsWith('STOP_')) {
      return 'BMTA Bus';
    }
    if (_stopToLinesMap.containsKey(stopId) &&
        _stopToLinesMap[stopId]!.isNotEmpty) {
      final lines = _stopToLinesMap[stopId]!.toList()..sort();
      return lines.join(', ');
    }
    return null;
  }

  String _stopDisplayLabel(gtfs.Stop stop) {
    final thai = stop.thaiName;
    if (thai == null || thai.isEmpty) {
      return stop.name;
    }
    return '${stop.name} • $thai';
  }

  int _stopPrefixScore(gtfs.Stop stop, String query) {
    final english = stop.name.toLowerCase();
    final thai = (stop.thaiName ?? '').toLowerCase();
    return (english.startsWith(query) || thai.startsWith(query)) ? 0 : 1;
  }

  void _adjustMapZoom(double delta) {
    final camera = _mapController.camera;
    final newZoom = (camera.zoom + delta).clamp(3.0, 19.0);
    _animatedMapMove(
      camera.center,
      newZoom,
      durationMs: 250,
      curve: Curves.easeOutCubic,
    );
  }

  // _zoomButton removed (no longer used)

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
      final idxRouteIcon = header.indexOf('route_icon');
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
            routeIcon: idxRouteIcon >= 0 && idxRouteIcon < row.length
                ? (row[idxRouteIcon].trim().isNotEmpty
                      ? row[idxRouteIcon].trim()
                      : null)
                : null,
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
  LocationPoint? _customStartPoint;
  LocationPoint? _customDestPoint;
  List<DirectionOption> directionOptions = [];
  DirectionOption? _viewingDetailsOption;
  gtfs.Stop? _viewingStop;
  int selectedDirectionIndex = 0;

  Future<void> _findDirection() async {
    final startId = selectedStartStopId;
    final destId = selectedDestinationStopId;

    LocationPoint? startOpt = _customStartPoint;
    if (startOpt == null && startId != null && allStops.isNotEmpty) {
      final startStop = allStops.firstWhere(
        (s) => s.stopId == startId,
        orElse: () => allStops.first,
      );
      if (startStop.stopId == startId) {
        startOpt = LocationPoint.fromStop(startStop);
      }
    }

    LocationPoint? destOpt = _customDestPoint;
    if (destOpt == null && destId != null && allStops.isNotEmpty) {
      final destStop = allStops.firstWhere(
        (s) => s.stopId == destId,
        orElse: () => allStops.first,
      );
      if (destStop.stopId == destId) destOpt = LocationPoint.fromStop(destStop);
    }

    if (startOpt == null || destOpt == null) return;

    final result = await _directionService.findDirections(
      routingMode: routingMode,
      allowedTransitTypes: allowedTransitTypes,
      startPoint: startOpt,
      destPoint: destOpt,
    );
    setState(() {
      directionOptions = List<DirectionOption>.from(result.options);
      if (directionOptions.isEmpty) {
        selectedDirectionIndex = 0;
        _headerCollapsed.value = false;
      } else {
        selectedDirectionIndex = result.selectionIndex.clamp(
          0,
          directionOptions.length - 1,
        );
        _headerCollapsed.value = true;
      }
    });
  }

  Color _getLineColor(String stopId) {
    final lineName = _getLineName(stopId);
    if (lineName != null) {
      if (lineColors.containsKey(lineName)) {
        return lineColors[lineName]!;
      }
      final firstLine = lineName.split(', ').first;
      if (lineColors.containsKey(firstLine)) {
        return lineColors[firstLine]!;
      }
    }
    return Colors.purple;
  }

  Color _getPolylineColor(String lineName) {
    if (lineColors.containsKey(lineName)) {
      return lineColors[lineName]!;
    }
    final firstLine = lineName.split(', ').first;
    if (lineColors.containsKey(firstLine)) {
      return lineColors[firstLine]!;
    }
    return Colors.purple;
  }

  String? _getRouteIcon(String lineName) {
    if (lineName.isEmpty) return null;
    final firstLine = lineName.split(', ').first;
    try {
      final route = allRoutes.firstWhere(
        (r) => r.shortName == firstLine || r.longName == firstLine,
      );
      return route.routeIcon;
    } catch (e) {
      return null;
    }
  }

  Polyline _linePolyline(LatLng from, LatLng to, Color color) {
    return Polyline(points: [from, to], color: color, strokeWidth: 6.0);
  }

  List<Polyline> _buildRoutePolylines(List<RouteSegment> segments) {
    final polylines = <Polyline>[];
    for (final segment in segments) {
      if (segment.mode == TravelMode.walk ||
          segment.mode == TravelMode.bicycle ||
          segment.mode == TravelMode.taxi ||
          (segment.mode == TravelMode.transit &&
              segment.roadPolyline != null)) {
        List<LatLng> points = [];
        if (segment.roadPolyline != null && segment.roadPolyline!.isNotEmpty) {
          points = segment.roadPolyline!
              .map((p) => LatLng(p.lat, p.lon))
              .toList();
        } else {
          points = [
            LatLng(segment.start.lat, segment.start.lon),
            LatLng(segment.end.lat, segment.end.lon),
          ];
        }

        Color lineColor = Colors.grey.shade600;
        double width = 4.0;
        StrokePattern? pattern = const StrokePattern.dotted();

        if (segment.mode == TravelMode.bicycle) {
          lineColor = Colors.green.shade600;
        } else if (segment.mode == TravelMode.taxi) {
          lineColor = Colors.orange.shade600;
        } else if (segment.mode == TravelMode.transit) {
          final lineName = segment.routeShortName ?? '';
          lineColor = _getPolylineColor(lineName);
          width = 6.0;
          pattern = null;
        }

        bool isTrainSegment = false;
        if (segment.mode == TravelMode.transit) {
          final rId = (segment.routeShortName ?? '')
              .split(', ')
              .first
              .replaceAll('\uFEFF', '')
              .toUpperCase();
          final route = allRoutes
              .where(
                (r) =>
                    r.routeId.replaceAll('\uFEFF', '').toUpperCase() == rId ||
                    r.shortName.replaceAll('\uFEFF', '').toUpperCase() == rId ||
                    r.longName.replaceAll('\uFEFF', '').toUpperCase() == rId,
              )
              .firstOrNull;
          if (route?.type == '2') {
            isTrainSegment = true;
          }
        }

        if (isTrainSegment) {
          polylines.add(
            Polyline(
              points: points,
              color: const Color(0xFF6B4226),
              strokeWidth: 7.0,
            ),
          );
          polylines.add(
            Polyline(
              points: points,
              color: Colors.white,
              strokeWidth: 4.0,
              pattern: StrokePattern.dashed(segments: [10.0, 10.0]),
            ),
          );
        } else {
          polylines.add(
            Polyline(
              points: points,
              color: lineColor,
              strokeWidth: width,
              pattern: pattern ?? const StrokePattern.solid(),
            ),
          );
        }

        // Also draw 90 degree offsets for bus stops towards the route line if it is a bus route
        if (segment.mode == TravelMode.transit &&
            segment.intermediateStops != null) {
          for (final stop in segment.intermediateStops!) {
            _addOffsetConnectionLine(
              polylines: polylines,
              stopPoint: LatLng(stop.lat, stop.lon),
              routePoints: points,
              color: lineColor,
            );
          }
        }
      } else {
        final route = segment.intermediateStops;
        if (route == null || route.length < 2) continue;

        final lineName =
            segment.routeShortName ??
            _getLineName(route[0].stopId) ??
            _getLineName(route.last.stopId) ??
            '';
        final lineColor = _getPolylineColor(lineName);

        for (int i = 1; i < route.length; i++) {
          final stopA = route[i - 1].stopId;
          final stopB = route[i].stopId;

          bool foundShape = false;
          // Look for a shape that connects stopA and stopB
          for (final shape in shapeSegments) {
            final aLocs = <int>[];
            final bLocs = <int>[];
            for (int k = 0; k < shape.pointNames.length; k++) {
              if (shape.pointNames[k] == stopA) aLocs.add(k);
              if (shape.pointNames[k] == stopB) bLocs.add(k);
            }

            if (aLocs.isNotEmpty && bLocs.isNotEmpty) {
              int bestGap = 999999;
              int bestA = -1;
              int bestB = -1;
              for (final a in aLocs) {
                for (final b in bLocs) {
                  final gap = (a - b).abs();
                  if (gap < bestGap) {
                    bestGap = gap;
                    bestA = a;
                    bestB = b;
                  }
                }
              }

              final isReversed = bestA > bestB;
              final startIdx = isReversed ? bestB : bestA;
              final endIdx = isReversed ? bestA : bestB;

              var shapePoints = shape.points.sublist(startIdx, endIdx + 1);
              if (isReversed) {
                shapePoints = shapePoints.reversed.toList();
              }
              polylines.add(
                Polyline(
                  points: shapePoints,
                  color: lineColor,
                  strokeWidth: 6.0,
                ),
              );
              foundShape = true;
              break;
            }
          } // Geometric fallback for buses
          if (!foundShape) {
            final targetId = segment.routeId ?? lineName.split(' ').first;
            final exactShapeId = segment.shapeId;
            if (exactShapeId != null && exactShapeId.isNotEmpty) {
              final exactMatch = shapeSegments
                  .where((s) => s.shapeId == exactShapeId)
                  .toList();
              if (exactMatch.isNotEmpty) {
                // If we exactly know the shape_id, force it, avoiding parallel routes
                final shape = exactMatch.first;
                int bestA = -1;
                double bestDistA = 9999999;
                int bestB = -1;
                double bestDistB = 9999999;

                for (int k = 0; k < shape.points.length; k++) {
                  final pt = shape.points[k];
                  final distA = const Distance().as(
                    LengthUnit.Meter,
                    pt,
                    LatLng(route[i - 1].lat, route[i - 1].lon),
                  );
                  if (distA < bestDistA) {
                    bestDistA = distA;
                    bestA = k;
                  }
                  final distB = const Distance().as(
                    LengthUnit.Meter,
                    pt,
                    LatLng(route[i].lat, route[i].lon),
                  );
                  if (distB < bestDistB) {
                    bestDistB = distB;
                    bestB = k;
                  }
                }

                if (bestDistA < 500 &&
                    bestDistB < 500 &&
                    bestA != -1 &&
                    bestB != -1) {
                  final isReversed = bestA > bestB;
                  final startIdx = isReversed ? bestB : bestA;
                  final endIdx = isReversed ? bestA : bestB;

                  var shapePoints = shape.points.sublist(startIdx, endIdx + 1);
                  if (isReversed) {
                    shapePoints = shapePoints.reversed.toList();
                  }

                  polylines.add(
                    Polyline(
                      points: shapePoints,
                      color: lineColor,
                      strokeWidth: 6.0,
                    ),
                  );
                  foundShape = true;
                }
              }
            }

            if (!foundShape && targetId.isNotEmpty) {
              final shapeOptions = shapeSegments.where(
                (s) => s.routeId == targetId || s.shapeId.contains(targetId),
              );
              for (final shape in shapeOptions) {
                int bestA = -1;
                double bestDistA = 9999999;
                int bestB = -1;
                double bestDistB = 9999999;

                for (int k = 0; k < shape.points.length; k++) {
                  final pt = shape.points[k];
                  final distA = const Distance().as(
                    LengthUnit.Meter,
                    pt,
                    LatLng(route[i - 1].lat, route[i - 1].lon),
                  );
                  if (distA < bestDistA) {
                    bestDistA = distA;
                    bestA = k;
                  }
                  final distB = const Distance().as(
                    LengthUnit.Meter,
                    pt,
                    LatLng(route[i].lat, route[i].lon),
                  );
                  if (distB < bestDistB) {
                    bestDistB = distB;
                    bestB = k;
                  }
                }

                if (bestDistA < 500 &&
                    bestDistB < 500 &&
                    bestA != -1 &&
                    bestB != -1) {
                  final isReversed = bestA > bestB;
                  final startIdx = isReversed ? bestB : bestA;
                  final endIdx = isReversed ? bestA : bestB;

                  var shapePoints = shape.points.sublist(startIdx, endIdx + 1);
                  if (isReversed) {
                    shapePoints = shapePoints.reversed.toList();
                  }

                  polylines.add(
                    Polyline(
                      points: shapePoints,
                      color: lineColor,
                      strokeWidth: 6.0,
                    ),
                  );
                  foundShape = true;
                  break;
                }
              }
            }
          }

          if (!foundShape) {
            polylines.add(
              _linePolyline(
                LatLng(route[i - 1].lat, route[i - 1].lon),
                LatLng(route[i].lat, route[i].lon),
                lineColor,
              ),
            );
          }
        }
      }
    }
    return polylines;
  }

  void _addOffsetConnectionLine({
    required List<Polyline> polylines,
    required LatLng stopPoint,
    required List<LatLng> routePoints,
    required Color color,
  }) {
    if (routePoints.isEmpty) return;

    // Find closest segment and its projection
    double bestDist = double.infinity;
    LatLng? bestProj;

    for (int i = 0; i < routePoints.length - 1; i++) {
      final p1 = routePoints[i];
      final p2 = routePoints[i + 1];

      final projInfo = __projectPointToSegment(stopPoint, p1, p2);
      if (projInfo.dist < bestDist) {
        bestDist = projInfo.dist;
        bestProj = projInfo.point;
      }
    }

    if (bestProj != null && bestDist > 0.00005) {
      // Only draw if > ~5 meters
      polylines.add(
        Polyline(
          points: [stopPoint, bestProj],
          color: color.withValues(alpha: 0.5),
          strokeWidth: 3.0,
        ),
      );
    }
  }

  _ProjectionResult __projectPointToSegment(LatLng pt, LatLng v, LatLng w) {
    // Basic flat-earth projection (good enough for small distances)
    double l2 =
        math.pow(v.latitude - w.latitude, 2) +
        math.pow(v.longitude - w.longitude, 2).toDouble();
    if (l2 == 0.0) {
      double dist = math.sqrt(
        math.pow(pt.latitude - v.latitude, 2) +
            math.pow(pt.longitude - v.longitude, 2),
      );
      return _ProjectionResult(v, dist);
    }

    double t =
        ((pt.latitude - v.latitude) * (w.latitude - v.latitude) +
            (pt.longitude - v.longitude) * (w.longitude - v.longitude)) /
        l2;
    t = math.max(0, math.min(1, t));

    final projLat = v.latitude + t * (w.latitude - v.latitude);
    final projLng = v.longitude + t * (w.longitude - v.longitude);
    final proj = LatLng(projLat, projLng);

    double dist = math.sqrt(
      math.pow(pt.latitude - projLat, 2) + math.pow(pt.longitude - projLng, 2),
    );
    return _ProjectionResult(proj, dist);
  }

  void _assignStopSelection(gtfs.Stop stop, {required bool asStart}) {
    setState(() {
      if (asStart) {
        selectedStartStopId = stop.stopId;
        _customStartPoint = null;
        _startSearchController.text = stop.name;
      } else {
        selectedDestinationStopId = stop.stopId;
        _customDestPoint = null;
        _destSearchController.text = stop.name;
      }
      _headerCollapsed.value = false;
    });
  }

  void _showStopDetails(BuildContext context, gtfs.Stop stop) {
    setState(() {
      _viewingStop = stop;
      _viewingDetailsOption = null;
    });
  }

  void _assignCustomPointSelection(LatLng point, {required bool asStart}) {
    setState(() {
      if (asStart) {
        selectedStartStopId = null;
        _customStartPoint = LocationPoint(
          lat: point.latitude,
          lon: point.longitude,
          name: 'Dropped Pin',
        );
        _startSearchController.text = 'Dropped Pin';
      } else {
        selectedDestinationStopId = null;
        _customDestPoint = LocationPoint(
          lat: point.latitude,
          lon: point.longitude,
          name: 'Dropped Pin',
        );
        _destSearchController.text = 'Dropped Pin';
      }
      _headerCollapsed.value = false;
    });

    if ((selectedStartStopId != null || _customStartPoint != null) &&
        (selectedDestinationStopId != null || _customDestPoint != null)) {
      _findDirection();
    }
  }

  void _showDroppedPinDetails(BuildContext context, LatLng point) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        final bottomInset = MediaQuery.of(sheetContext).padding.bottom;

        Widget infoChip(String label, String value) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        Widget quickAction({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
        }) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 12, 24, bottomInset + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.place, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Dropped Pin',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    infoChip(
                      'Coordinates',
                      'Lat ${point.latitude.toStringAsFixed(4)}, Lon ${point.longitude.toStringAsFixed(4)}',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                quickAction(
                  icon: Icons.trip_origin,
                  title: 'Set as origin',
                  subtitle: 'Plan a route starting here',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _assignCustomPointSelection(point, asStart: true);
                  },
                ),
                quickAction(
                  icon: Icons.flag,
                  title: 'Set as destination',
                  subtitle: 'Use this location as your endpoint',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _assignCustomPointSelection(point, asStart: false);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _swapStops() async {
    if (selectedStartStopId == null &&
        selectedDestinationStopId == null &&
        _customStartPoint == null &&
        _customDestPoint == null) {
      return;
    }
    setState(() {
      final tempId = selectedStartStopId;
      selectedStartStopId = selectedDestinationStopId;
      selectedDestinationStopId = tempId;

      final tempCustom = _customStartPoint;
      _customStartPoint = _customDestPoint;
      _customDestPoint = tempCustom;

      final tempText = _startSearchController.text;
      _startSearchController.text = _destSearchController.text;
      _destSearchController.text = tempText;
      if (selectedStartStopId != null ||
          selectedDestinationStopId != null ||
          _customStartPoint != null ||
          _customDestPoint != null) {
        _headerCollapsed.value = false;
      }
    });
    if ((selectedStartStopId != null || _customStartPoint != null) &&
        (selectedDestinationStopId != null || _customDestPoint != null)) {
      await _findDirection();
    }
  }

  void _clearSelections({bool preserveHeaderState = false}) {
    if (selectedStartStopId == null &&
        selectedDestinationStopId == null &&
        _customStartPoint == null &&
        _customDestPoint == null &&
        directionOptions.isEmpty) {
      return;
    }
    setState(() {
      selectedStartStopId = null;
      selectedDestinationStopId = null;
      _customStartPoint = null;
      _customDestPoint = null;
      directionOptions = [];
      selectedDirectionIndex = 0;
      _startSearchController.clear();
      _destSearchController.clear();
      _collapsedSearchController.clear();
      if (!preserveHeaderState) {
        _headerCollapsed.value = false;
      }
    });
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

  Widget _buildPanelContent(BuildContext context) {
    if (_viewingStop != null) {
      final stop = _viewingStop!;
      final lineName = _getLineName(stop.stopId);
      final lineColor = _getLineColor(stop.stopId);
      final transferStops = _directionService.getTransferStations(stop.stopId);

      return Stack(
        key: const ValueKey('station_details'),
        children: [
          StationDetailsContent(
            stop: stop,
            lineColor: lineColor,
            lineName: lineName,
            isBottomSheet: true,
            isSidePanel: true,
            transferStops: transferStops,
            lineNameResolver: (id) => _getLineName(id),
            lineColorResolver: (id) => _getLineColor(id),
            lineColorByName: (name) => _getPolylineColor(name),
            routeIconByName: (name) => _getRouteIcon(name),
            onSelectAsStart: () {
              setState(() {
                _viewingStop = null;
              });
              _assignStopSelection(stop, asStart: true);
            },
            onSelectAsDestination: () {
              setState(() {
                _viewingStop = null;
              });
              _assignStopSelection(stop, asStart: false);
            },
            onTransferStationSelected: (tStop) {
              setState(() {
                _viewingStop = tStop;
              });
              // Fit camera to the transfer station
              final zoom = math.max(_mapController.camera.zoom, 14).toDouble();
              _mapController.move(LatLng(tStop.lat, tStop.lon), zoom);
            },
          ),
          Positioned(
            top: 2,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.8),
              ),
              onPressed: () {
                setState(() => _viewingStop = null);
              },
            ),
          ),
        ],
      );
    }

    if (directionOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget content;
    if (_viewingDetailsOption != null) {
      content = RouteDetailsSheet(
        key: const ValueKey('route_details'),
        option: _viewingDetailsOption!,
        onBack: () {
          setState(() {
            _viewingDetailsOption = null;
          });
        },
        lineNameResolver: _getLineName,
        lineColorResolver: _getLineColor,
        lineColors: lineColors,
      );
    } else {
      content = RouteOptionsPanel(
        key: const ValueKey('route_options'),
        options: directionOptions,
        selectedIndex: selectedDirectionIndex,
        onSelectOption: _selectRouteOption,
        onViewDetails: (option) {
          setState(() {
            _viewingDetailsOption = option;
          });
        },
        onStartNavigation: _openNavigation,
        lineNameResolver: _getLineName,
        lineColors: lineColors,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) {
        final isDetails = child.key == const ValueKey('route_details');
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: isDetails
                  ? const Offset(0.05, 0.0)
                  : const Offset(-0.05, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: content,
    );
  }

  Widget _buildMap(BuildContext context) {
    final startId = selectedStartStopId;
    final destId = selectedDestinationStopId;
    final activeSegments = activeRouteSegments;
    final viewPadding = MediaQuery.of(context).padding;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWide = screenWidth > 600;
    final hasPanelContent = directionOptions.isNotEmpty || _viewingStop != null;

    // Responsive bottom offset that animates up if there are routes
    final zoomBottomOffset = isWide
        ? 24.0
        : (hasPanelContent
              ? screenHeight * 0.45 + 16.0
              : viewPadding.bottom + 120.0);
    final showBusStops =
        _showBusPins &&
        busStops.isNotEmpty &&
        _currentZoom >= _busStopZoomThreshold;
    final showFerryStops =
        _showFerryPins &&
        ferryStops.isNotEmpty &&
        _currentZoom >= _busStopZoomThreshold;

    final filteredRailStops = railStops.where((stop) {
      final isTrain = _isStopTrain(stop);
      final isMetro = _isStopMetro(stop);

      if (isTrain && !_showTrainPins) return false;
      if (isMetro && !_showMetroPins) return false;
      if (!isTrain && !isMetro) {
        // Fallback if type isn't correctly identified, use metro fallback as before
        if (!_showMetroPins) return false;
      }
      return true;
    }).toList();

    final routeStopIds = <String>{};
    for (final seg in activeSegments) {
      if (seg.intermediateStops != null) {
        routeStopIds.addAll(seg.intermediateStops!.map((s) => s.stopId));
      }
      if (seg.start.stopId != null) routeStopIds.add(seg.start.stopId!);
      if (seg.end.stopId != null) routeStopIds.add(seg.end.stopId!);
    }

    // Dynamic marker sizing based on zoom
    final double railBaseSize = math.max(
      6.0,
      (_currentZoom - 10.0) * 3.0 + 8.0,
    );
    final double railSelectedSize = railBaseSize * 1.375;
    final double railBorderWidth = math.max(1.0, railBaseSize / 5.0);
    final double railSelectedBorderWidth = math.max(
      2.0,
      railSelectedSize / 5.0,
    );

    return Stack(
      children: [
        FlutterMap(
          key: _mapKey,
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentCenter,
            initialZoom: _currentZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
              scrollWheelVelocity: 0.015,
            ),
            onMapEvent: (event) {
              final newZoom = event.camera.zoom;
              _currentCenter = event.camera.center;
              if ((newZoom - _currentZoom).abs() > 0.05) {
                setState(() => _currentZoom = newZoom);
              }
            },
            onLongPress: (tapPosition, point) {
              _showDroppedPinDetails(context, point);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.route',
            ),
            if (shapeSegments.isNotEmpty)
              PolylineLayer(
                polylines: shapeSegments
                    .where((s) {
                      final isTrain = _isShapeTrain(s);
                      final isMetro = _isShapeMetro(s);
                      // If it matches a known shape type, check the toggle
                      if (isTrain && !_showTrainPins) return false;
                      if (isMetro && !_showMetroPins) return false;
                      // Fallback: if it's not strictly known, still show it unless we hide all maybe?
                      // Actually shapes in shapes.txt are just trains/metros.
                      // If we consider them "Metro" when not train:
                      if (!isTrain && !isMetro) return false;
                      return true;
                    })
                    .expand((s) {
                      final isTrain = _isShapeTrain(s);

                      if (activeSegments.isNotEmpty) {
                        return [
                          Polyline(
                            points: s.points,
                            color: Colors.grey.withValues(alpha: 0.5),
                            strokeWidth: 4.0,
                          ),
                        ];
                      }

                      if (isTrain) {
                        return [
                          // Base thick brown line
                          Polyline(
                            points: s.points,
                            color: const Color(0xFF6B4226), // Dark Brown
                            strokeWidth: 7.0,
                          ),
                          // Top dashed white line
                          Polyline(
                            points: s.points,
                            color: Colors.white,
                            strokeWidth: 4.0,
                            pattern: StrokePattern.dashed(
                              segments: [10.0, 10.0],
                            ),
                          ),
                        ];
                      }

                      return [
                        Polyline(
                          points: s.points,
                          color: s.color,
                          strokeWidth: 6.0,
                        ),
                      ];
                    })
                    .toList(),
              ),
            if (showBusStops)
              MarkerLayer(
                markers: busStops
                    .map(
                      (stop) => Marker(
                        point: LatLng(stop.lat, stop.lon),
                        width: 18,
                        height: 22,
                        child: GestureDetector(
                          onTap: () => _showStopDetails(context, stop),
                          child: Tooltip(
                            message: stop.name,
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    (activeSegments.isNotEmpty &&
                                        !routeStopIds.contains(stop.stopId))
                                    ? Colors.grey.shade400
                                    : const Color.fromARGB(255, 38, 62, 199),
                                border: Border.all(
                                  color:
                                      (activeSegments.isNotEmpty &&
                                          !routeStopIds.contains(stop.stopId))
                                      ? Colors.grey.shade600
                                      : Colors.black.withValues(alpha: 0.18),
                                  width: 1,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.directions_bus,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (showFerryStops)
              MarkerLayer(
                markers: ferryStops
                    .map(
                      (stop) => Marker(
                        point: LatLng(stop.lat, stop.lon),
                        width: 18,
                        height: 22,
                        child: GestureDetector(
                          onTap: () => _showStopDetails(context, stop),
                          child: Tooltip(
                            message: stop.name,
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    (activeSegments.isNotEmpty &&
                                        !routeStopIds.contains(stop.stopId))
                                    ? Colors.grey.shade400
                                    : Colors.cyan.shade600,
                                border: Border.all(
                                  color:
                                      (activeSegments.isNotEmpty &&
                                          !routeStopIds.contains(stop.stopId))
                                      ? Colors.grey.shade600
                                      : Colors.black.withValues(alpha: 0.18),
                                  width: 1,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.directions_boat,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (filteredRailStops.isNotEmpty)
              MarkerLayer(
                markers: filteredRailStops
                    .map(
                      (stop) => Marker(
                        point: LatLng(stop.lat, stop.lon),
                        width: (stop.stopId == startId || stop.stopId == destId)
                            ? railSelectedSize
                            : railBaseSize,
                        height:
                            (stop.stopId == startId || stop.stopId == destId)
                            ? railSelectedSize
                            : railBaseSize,
                        child: GestureDetector(
                          onTap: () => _showStopDetails(context, stop),
                          child: Tooltip(
                            message: _stopDisplayLabel(stop),
                            child: Container(
                              decoration: BoxDecoration(
                                color: (stop.stopId == startId)
                                    ? Colors.greenAccent.withValues(alpha: 0.85)
                                    : (stop.stopId == destId)
                                    ? Colors.redAccent.withValues(alpha: 0.85)
                                    : (activeSegments.isNotEmpty &&
                                          !routeStopIds.contains(stop.stopId))
                                    ? Colors.grey.shade300
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      (activeSegments.isNotEmpty &&
                                          !routeStopIds.contains(stop.stopId) &&
                                          stop.stopId != startId &&
                                          stop.stopId != destId)
                                      ? Colors.grey.shade500
                                      : _getLineColor(stop.stopId),
                                  width:
                                      (stop.stopId == startId ||
                                          stop.stopId == destId)
                                      ? railSelectedBorderWidth
                                      : railBorderWidth,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (_customStartPoint != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      _customStartPoint!.lat,
                      _customStartPoint!.lon,
                    ),
                    width: 30,
                    height: 30,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.green,
                      size: 30,
                    ),
                  ),
                ],
              ),
            if (_customDestPoint != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_customDestPoint!.lat, _customDestPoint!.lon),
                    width: 30,
                    height: 30,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                ],
              ),
            if (_userLocation?.latitude != null &&
                _userLocation?.longitude != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      _userLocation!.latitude!,
                      _userLocation!.longitude!,
                    ),
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (activeSegments.isNotEmpty)
              PolylineLayer(polylines: _buildRoutePolylines(activeSegments)),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          right: isWide ? 24 : 16,
          bottom: zoomBottomOffset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildFilterMenu(isWide),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.surface.withValues(
                              alpha:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.4
                                  : 0.6,
                            ),
                            Theme.of(context).colorScheme.surface.withValues(
                              alpha:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.2
                                  : 0.4,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.dark
                                ? 0.15
                                : 0.4,
                          ),
                          width: 1.2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add),
                              tooltip: 'Zoom in',
                              onPressed: () => _adjustMapZoom(0.75),
                              iconSize: 28,
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(
                                minWidth: 56,
                                minHeight: 48,
                              ),
                            ),
                            Container(
                              width: 36,
                              height: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove),
                              tooltip: 'Zoom out',
                              onPressed: () => _adjustMapZoom(-0.75),
                              iconSize: 28,
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(
                                minWidth: 56,
                                minHeight: 48,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.surface.withValues(
                              alpha:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.4
                                  : 0.6,
                            ),
                            Theme.of(context).colorScheme.surface.withValues(
                              alpha:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.2
                                  : 0.4,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.dark
                                ? 0.15
                                : 0.4,
                          ),
                          width: 1.2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          icon: const Icon(Icons.my_location),
                          tooltip: 'Current Location',
                          onPressed: _goToMyLocation,
                          iconSize: 28,
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(
                            minWidth: 56,
                            minHeight: 56,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterMenu(bool isWide) {
    final theme = Theme.of(context);
    final items = [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          'Map Layers',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const Divider(),
      _buildFilterMenuItem(
        'Train Station',
        Icons.train,
        Colors.orange,
        _showTrainPins,
        (val) => setState(() => _showTrainPins = val),
      ),
      _buildFilterMenuItem(
        'Metro Station',
        Icons.subway,
        Colors.blue,
        _showMetroPins,
        (val) => setState(() => _showMetroPins = val),
      ),
      _buildFilterMenuItem(
        'Bus Stop',
        Icons.directions_bus,
        Colors.green,
        _showBusPins,
        (val) => setState(() => _showBusPins = val),
      ),
      _buildFilterMenuItem(
        'Ferry Pier',
        Icons.directions_boat,
        Colors.teal,
        _showFerryPins,
        (val) => setState(() => _showFerryPins = val),
      ),
    ];

    Widget buildButton(bool isOpen, VoidCallback onPressed) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.surface.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.4 : 0.6,
                    ),
                    theme.colorScheme.surface.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.2 : 0.4,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.15 : 0.4,
                  ),
                  width: 1.2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: Icon(
                    Icons.layers_outlined,
                    color: isOpen
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  tooltip: 'Map Layers',
                  onPressed: onPressed,
                  iconSize: 28,
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(
                    minWidth: 56,
                    minHeight: 56,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!isWide) {
      return buildButton(false, () {
        showModalBottomSheet(
          context: context,
          backgroundColor: theme.colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (bottomSheetContext) {
            return StatefulBuilder(
              builder: (ctx, setSheetState) {
                // Rebuild sheet using the latest map states.
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Map Layers',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Divider(),
                        _buildFilterMenuItem(
                          'Train Station',
                          Icons.train,
                          Colors.orange,
                          _showTrainPins,
                          (val) {
                            setState(() => _showTrainPins = val);
                            setSheetState(() {});
                          },
                          fullWidth: true,
                        ),
                        _buildFilterMenuItem(
                          'Metro Station',
                          Icons.subway,
                          Colors.blue,
                          _showMetroPins,
                          (val) {
                            setState(() => _showMetroPins = val);
                            setSheetState(() {});
                          },
                          fullWidth: true,
                        ),
                        _buildFilterMenuItem(
                          'Bus Stop',
                          Icons.directions_bus,
                          Colors.green,
                          _showBusPins,
                          (val) {
                            setState(() => _showBusPins = val);
                            setSheetState(() {});
                          },
                          fullWidth: true,
                        ),
                        _buildFilterMenuItem(
                          'Ferry Pier',
                          Icons.directions_boat,
                          Colors.teal,
                          _showFerryPins,
                          (val) {
                            setState(() => _showFerryPins = val);
                            setSheetState(() {});
                          },
                          fullWidth: true,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      });
    }

    return MenuAnchor(
      alignmentOffset: const Offset(-180, 0),
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      menuChildren: items,
      builder: (context, controller, child) {
        return buildButton(controller.isOpen, () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        });
      },
    );
  }

  Widget _buildFilterMenuItem(
    String title,
    IconData icon,
    Color color,
    bool value,
    ValueChanged<bool> onChanged, {
    bool fullWidth = false,
  }) {
    final theme = Theme.of(context);
    final content = Container(
      width: fullWidth ? double.infinity : 200,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );

    if (fullWidth) {
      return InkWell(onTap: () => onChanged(!value), child: content);
    }

    return MenuItemButton(onPressed: () => onChanged(!value), child: content);
  }

  Widget _buildWideLayout(BuildContext context, Widget headerOverlay) {
    final width = MediaQuery.of(context).size.width;
    final hasPanelContent = directionOptions.isNotEmpty || _viewingStop != null;
    // ensure the side panel is at least 320px wide so route options text does not overflow
    final panelWidth = math.max(340.0, math.min(400.0, width * 0.3));
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Map fills the entire background
        Positioned.fill(child: _buildMap(context)),

        // Content on the left side
        Positioned(
          top: topInset + 12.0,
          bottom: 24,
          left: 24,
          width: panelWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The header
              _buildHomeHeader(context, true),

              // The floating options panel underneath
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(
                          -1.2,
                          0.0,
                        ), // slide from left out of view
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: hasPanelContent
                      ? Padding(
                          key: const ValueKey('panel_content'),
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 20,
                                  sigmaY: 20,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.colorScheme.surface.withValues(
                                          alpha:
                                              theme.brightness ==
                                                  Brightness.dark
                                              ? 0.75
                                              : 0.90,
                                        ),
                                        theme.colorScheme.surface.withValues(
                                          alpha:
                                              theme.brightness ==
                                                  Brightness.dark
                                              ? 0.60
                                              : 0.80,
                                        ),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha:
                                            theme.brightness == Brightness.dark
                                            ? 0.2
                                            : 0.5,
                                      ),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ListView(
                                      padding: const EdgeInsets.only(
                                        bottom: 24,
                                        top: 12,
                                      ),
                                      children: [_buildPanelContent(context)],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('no_content')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneLayout(BuildContext context, Widget headerOverlay) {
    final hasPanelContent = directionOptions.isNotEmpty || _viewingStop != null;
    final theme = Theme.of(context);

    // Dynamic initial sheet height when content exist
    final sheetInitialSize = hasPanelContent ? 0.45 : 0.0;

    return Stack(
      children: [
        Positioned.fill(child: _buildMap(context)),
        headerOverlay,

        // Drag sheet spanning full height but starting at initialSize
        if (hasPanelContent)
          DraggableScrollableSheet(
            initialChildSize: sheetInitialSize,
            minChildSize: 0.25,
            maxChildSize: 0.95,
            builder: (context, controller) {
              final bottomPadding = MediaQuery.of(context).padding.bottom;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.surface.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.75
                                  : 0.90,
                            ),
                            theme.colorScheme.surface.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.60
                                  : 0.80,
                            ),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? 0.2
                                : 0.5,
                          ),
                          width: 1.2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListView(
                          controller: controller,
                          padding: EdgeInsets.only(bottom: bottomPadding + 24),
                          children: [
                            const SizedBox(height: 12),
                            Center(
                              child: Container(
                                width: 48,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.3,
                                  ),
                                  borderRadius: BorderRadius.circular(2.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildPanelContent(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildHomeHeader(BuildContext context, bool isWideLayout) {
    final theme = Theme.of(context);
    final start = selectedStartStopId != null
        ? stopLookup[selectedStartStopId!]
        : null;
    final dest = selectedDestinationStopId != null
        ? stopLookup[selectedDestinationStopId!]
        : null;
    final startLabel =
        _customStartPoint?.name ??
        (start != null ? _stopDisplayLabel(start) : null);
    final destLabel =
        _customDestPoint?.name ??
        (dest != null ? _stopDisplayLabel(dest) : null);
    return ValueListenableBuilder<bool>(
      valueListenable: _headerCollapsed,
      builder: (context, isCollapsed, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.surface.withValues(
                        alpha: theme.brightness == Brightness.dark
                            ? 0.75
                            : 0.90,
                      ),
                      theme.colorScheme.surface.withValues(
                        alpha: theme.brightness == Brightness.dark
                            ? 0.60
                            : 0.80,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.2 : 0.5,
                    ),
                    width: 1.2,
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: isCollapsed
                            ? KeyedSubtree(
                                key: const ValueKey('collapsed_header'),
                                child: _buildCollapsedHeaderContent(
                                  context,
                                  startLabel,
                                  destLabel,
                                ),
                              )
                            : KeyedSubtree(
                                key: const ValueKey('expanded_header'),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildSelectionSummaryCard(
                                      context,
                                      start,
                                      dest,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderOverlay(BuildContext context, bool isWideLayout) {
    final horizontal = isWideLayout ? 24.0 : 16.0;
    final topInset = MediaQuery.of(context).padding.top;
    final top = topInset + 12.0;
    final maxWidth = isWideLayout ? 400.0 : 600.0;
    return Align(
      alignment: isWideLayout ? Alignment.topLeft : Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: top, left: horizontal, right: horizontal),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: _buildHomeHeader(context, isWideLayout),
        ),
      ),
    );
  }

  Widget _buildCollapsedHeaderContent(
    BuildContext context,
    String? startLabel,
    String? destLabel,
  ) {
    if (startLabel != null && destLabel != null) {
      return _buildCollapsedSelectionSummary(context, startLabel, destLabel);
    }
    return _buildCollapsedSearchBar(context);
  }

  Widget _collapseHeaderButton() {
    return IconButton(
      tooltip: 'Hide planner',
      icon: const Icon(Icons.unfold_less),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      onPressed: () {
        _headerCollapsed.value = true;
      },
    );
  }

  Widget _expandHeaderButton() {
    return IconButton(
      tooltip: 'Show planner',
      icon: const Icon(Icons.unfold_more),
      onPressed: () {
        _headerCollapsed.value = false;
      },
    );
  }

  Widget _buildSearchSuggestionTile(gtfs.Stop stop, VoidCallback onTap) {
    final theme = Theme.of(context);
    final lineColor = _getLineColor(stop.stopId);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lineColor,
          border: Border.all(color: theme.colorScheme.surface, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          stop.code ?? '',
          style: TextStyle(
            color: (lineColor.computeLuminance() > 0.5)
                ? Colors.black
                : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      title: Text(stop.name),
      subtitle: Text(
        (stop.thaiName != null && stop.thaiName!.isNotEmpty)
            ? stop.thaiName!
            : 'Thai Station provide later',
        style: theme.textTheme.bodySmall,
      ),
      onTap: onTap,
    );
  }

  Widget _buildCollapsedSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: SearchAnchor(
            searchController: _collapsedSearchController,
            viewHintText: 'Where to?',
            builder: (context, controller) {
              return SearchBar(
                controller: controller,
                constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
                leading: Icon(Icons.search, color: theme.colorScheme.primary),
                hintText: 'Where to?',
                hintStyle: WidgetStatePropertyAll(
                  TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    fontSize: 15,
                  ),
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 16),
                ),
                elevation: const WidgetStatePropertyAll<double>(0),
                backgroundColor: WidgetStatePropertyAll(
                  theme.colorScheme.surface.withValues(alpha: 0.75),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
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
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        setState(controller.clear);
                      },
                    ),
                ],
              );
            },
            suggestionsBuilder: (context, controller) {
              if (controller.text.isEmpty) {
                return [
                  ServiceTabs(
                    allStops: allStops,
                    busStops: busStops,
                    linePrefixes: linePrefixes,
                    lineColors: lineColors,
                    getLineName: _getLineName,
                    getLineNames: _getLineNames,
                    getServicePriority: _getServicePriority,
                    onSelect: (stop) {
                      controller.closeView(stop.name);
                      _handleCollapsedStopSelection(stop);
                    },
                  ),
                ];
              }

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
                (stop) => _buildSearchSuggestionTile(stop, () {
                  controller.closeView(stop.name);
                  _handleCollapsedStopSelection(stop);
                }),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        _expandHeaderButton(),
      ],
    );
  }

  Widget _buildCollapsedSelectionSummary(
    BuildContext context,
    String startLabel,
    String destLabel,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.trip_origin,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          startLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Icon(
                        Icons.flag,
                        size: 16,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          destLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Clear selections',
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  onPressed: () => _clearSelections(preserveHeaderState: true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _expandHeaderButton(),
      ],
    );
  }

  Future<void> _handleCollapsedStopSelection(gtfs.Stop stop) async {
    final assignStart = selectedStartStopId == null;
    await _selectStopFromSearch(
      stop,
      asStart: assignStart,
      preserveHeaderState: true,
    );
    setState(() {
      _collapsedSearchController.clear();
    });
  }

  Widget _buildSelectionSummaryCard(
    BuildContext context,
    gtfs.Stop? start,
    gtfs.Stop? dest,
  ) {
    final theme = Theme.of(context);
    final hasStart = start != null || _customStartPoint != null;
    final hasDest = dest != null || _customDestPoint != null;
    final hasBoth = hasStart && hasDest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildStopSearchField(
                      context,
                      label: 'Origin',
                      icon: Icons.trip_origin,
                      iconColor: theme.colorScheme.primary,
                      asStart: true,
                    ),
                    const SizedBox(height: 8),
                    _buildStopSearchField(
                      context,
                      label: 'Destination',
                      icon: Icons.flag,
                      iconColor: theme.colorScheme.secondary,
                      asStart: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  _collapseHeaderButton(),
                  if (hasStart || hasDest)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: IconButton(
                        icon: const Icon(Icons.swap_vert, size: 22),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondaryContainer
                              .withValues(alpha: 0.5),
                          shape: const CircleBorder(),
                        ),
                        onPressed: _swapStops,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildTransitPreferenceChooser(context)),
              if (selectedStartStopId != null ||
                  selectedDestinationStopId != null)
                IconButton(
                  onPressed: _clearSelections,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Clear',
                ),
            ],
          ),
          if (hasBoth)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.85,
                  ),
                ),
                onPressed: () => _findDirection(),
                icon: const Icon(Icons.route),
                label: const Text(
                  'Find Routes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransitPreferenceChooser(BuildContext context) {
    final theme = Theme.of(context);
    final options = [
      {'type': 'Metro', 'icon': Icons.subway},
      {'type': 'Train', 'icon': Icons.directions_railway},
      {'type': 'Bus', 'icon': Icons.directions_bus},
      {'type': 'Ferry', 'icon': Icons.directions_boat},
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: options.map((opt) {
        final type = opt['type'] as String;
        final icon = opt['icon'] as IconData;
        final isSelected = allowedTransitTypes.contains(type);
        return FilterChip(
          label: Icon(icon, size: 18),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          showCheckmark: false,
          selected: isSelected,
          backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.6),
          selectedColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                allowedTransitTypes.add(type);
              } else {
                allowedTransitTypes.remove(type);
              }
            });
            if (selectedStartStopId != null &&
                selectedDestinationStopId != null) {
              _findDirection();
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildStopSearchField(
    BuildContext context, {
    required String label,
    required IconData icon,
    Color? iconColor,
    required bool asStart,
    Widget? trailingAction,
  }) {
    final theme = Theme.of(context);
    final controller = asStart ? _startSearchController : _destSearchController;

    return SearchAnchor(
      searchController: controller,
      viewHintText: 'Search $label',
      builder: (context, ctrl) {
        final trailingWidgets = <Widget>[];
        if (ctrl.text.isNotEmpty) {
          trailingWidgets.add(
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Clear $label',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() {
                  ctrl.clear();
                  if (asStart) {
                    selectedStartStopId = null;
                    _customStartPoint = null;
                  } else {
                    selectedDestinationStopId = null;
                    _customDestPoint = null;
                  }
                  directionOptions = [];
                  selectedDirectionIndex = 0;
                  _headerCollapsed.value = false;
                });
              },
            ),
          );
        }
        if (trailingAction != null) {
          trailingWidgets.add(trailingAction);
        }
        return SizedBox(
          height: 48,
          child: SearchBar(
            controller: ctrl,
            constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
            leading: Icon(
              icon,
              size: 20,
              color: iconColor ?? theme.colorScheme.onSurfaceVariant,
            ),
            hintText: 'Search $label',
            hintStyle: WidgetStatePropertyAll(
              TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            textStyle: WidgetStatePropertyAll(
              TextStyle(color: theme.colorScheme.onSurface, fontSize: 15),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12),
            ),
            elevation: const WidgetStatePropertyAll<double>(0),
            backgroundColor: WidgetStatePropertyAll(
              theme.colorScheme.surface.withValues(alpha: 0.75),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
            ),
            onTap: ctrl.openView,
            onChanged: (value) {
              if (!ctrl.isOpen) {
                ctrl.openView();
              }
              setState(() {});
            },
            trailing: trailingWidgets,
          ),
        );
      },
      suggestionsBuilder: (context, ctrl) {
        if (ctrl.text.isEmpty) {
          return [
            ServiceTabs(
              allStops: allStops,
              busStops: busStops,
              linePrefixes: linePrefixes,
              lineColors: lineColors,
              getLineName: _getLineName,
              getLineNames: _getLineNames,
              getServicePriority: _getServicePriority,
              onSelect: (stop) {
                ctrl.closeView(stop.name);
                _selectStopFromSearch(stop, asStart: asStart);
              },
            ),
          ];
        }

        final results = _filterStops(ctrl.text);
        if (results.isEmpty) {
          return [
            const ListTile(
              leading: Icon(Icons.search_off),
              title: Text('No stations found'),
            ),
          ];
        }
        return results.map(
          (stop) => _buildSearchSuggestionTile(stop, () {
            ctrl.closeView(stop.name);
            _selectStopFromSearch(stop, asStart: asStart);
          }),
        );
      },
    );
  }

  bool _isStopMetro(gtfs.Stop stop) {
    final lineNames = _stopToLinesMap[stop.stopId];
    if (lineNames != null) {
      for (final lName in lineNames) {
        final route = allRoutes
            .where(
              (r) =>
                  r.longName.toUpperCase() == lName.toUpperCase() ||
                  r.routeId.toUpperCase() == lName.toUpperCase(),
            )
            .firstOrNull;
        if (route?.type == '1') {
          return true;
        }
      }
    }
    return false;
  }

  bool _isStopTrain(gtfs.Stop stop) {
    final lineNames = _stopToLinesMap[stop.stopId];
    if (lineNames != null) {
      for (final lName in lineNames) {
        final route = allRoutes
            .where(
              (r) =>
                  r.longName.toUpperCase() == lName.toUpperCase() ||
                  r.routeId.toUpperCase() == lName.toUpperCase(),
            )
            .firstOrNull;
        if (route?.type == '2') {
          return true;
        }
      }
    }
    return false;
  }

  bool _isShapeTrain(ShapeSegment shape) {
    if (shape.routeId == null) return false;
    final rId = shape.routeId!
        .replaceAll('\uFEFF', '')
        .toUpperCase(); // Avoid BOM issues
    final route = allRoutes
        .where((r) => r.routeId.replaceAll('\uFEFF', '').toUpperCase() == rId)
        .firstOrNull;
    return route?.type == '2';
  }

  bool _isShapeMetro(ShapeSegment shape) {
    if (shape.routeId == null) return false;
    final rId = shape.routeId!.replaceAll('\uFEFF', '').toUpperCase();
    final route = allRoutes
        .where((r) => r.routeId.replaceAll('\uFEFF', '').toUpperCase() == rId)
        .firstOrNull;
    return route?.type == '1';
  }

  int _getServicePriority(gtfs.Stop stop) {
    if (stop.stopId.startsWith('F')) return 4;
    if (busStops.any((s) => s.stopId == stop.stopId)) return 3;
    if (_isStopTrain(stop)) return 2;
    return 1;
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
      // 1. Sort by service priority
      final aPriority = _getServicePriority(a);
      final bPriority = _getServicePriority(b);
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);

      // 2. Sort by prefix score
      final aScore = _stopPrefixScore(a, trimmed);
      final bScore = _stopPrefixScore(b, trimmed);
      if (aScore != bScore) return aScore.compareTo(bScore);

      // 3. Sort alphabetically
      return _stopDisplayLabel(a).compareTo(_stopDisplayLabel(b));
    });
    return matches.take(20).toList();
  }

  Future<void> _selectStopFromSearch(
    gtfs.Stop stop, {
    required bool asStart,
    bool preserveHeaderState = false,
  }) async {
    setState(() {
      if (asStart) {
        selectedStartStopId = stop.stopId;
        _startSearchController.text = stop.name;
      } else {
        selectedDestinationStopId = stop.stopId;
        _destSearchController.text = stop.name;
      }
      if (!preserveHeaderState) {
        _headerCollapsed.value = false;
      }
    });

    final zoom = math.max(_mapController.camera.zoom, 14).toDouble();
    _mapController.move(LatLng(stop.lat, stop.lon), zoom);
    if (selectedStartStopId != null && selectedDestinationStopId != null) {
      await _findDirection();
    }
  }

  List<RouteSegment> get activeRouteSegments {
    if (directionOptions.isNotEmpty &&
        selectedDirectionIndex < directionOptions.length) {
      return directionOptions[selectedDirectionIndex].segments;
    }
    return const <RouteSegment>[];
  }

  List<gtfs.Stop> get directionStopsView {
    if (directionOptions.isNotEmpty &&
        selectedDirectionIndex < directionOptions.length &&
        directionOptions[selectedDirectionIndex].allStops.isNotEmpty) {
      return directionOptions[selectedDirectionIndex].allStops;
    }
    return const <gtfs.Stop>[];
  }

  @override
  void initState() {
    super.initState();
    _startSearchController = SearchController();
    _destSearchController = SearchController();
    _collapsedSearchController = SearchController();
    _directionService = DirectionService(lineNameResolver: _getLineName);
    _loadRoutesAndStops();
    _initLocationTracking();
  }

  Future<void> _initLocationTracking() async {
    final location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) return;
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted != PermissionStatus.granted &&
        permissionGranted != PermissionStatus.grantedLimited) {
      return;
    }
    _locationSub = location.onLocationChanged.listen((
      LocationData currentLocation,
    ) {
      if (mounted) {
        setState(() {
          _userLocation = currentLocation;
        });
      }
    });
  }

  @override
  void dispose() {
    _headerCollapsed.dispose();
    _startSearchController.dispose();
    _destSearchController.dispose();
    _collapsedSearchController.dispose();
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRoutesAndStops() async {
    final routes = await _parseRoutesFromAsset('assets/gtfs_data/routes.txt');
    final busRoutes = await RouteAssetLoader.loadRoutes(
      'assets/gtfs_data/bus_route.txt',
    );
    final ferryRoutes = await RouteAssetLoader.loadRoutes(
      'assets/gtfs_data/ferry_route.txt',
    );
    routes.addAll(busRoutes);
    routes.addAll(ferryRoutes);

    final thaiNames = await _loadThaiStopNames();
    final stops = await _parseStopsFromAsset(
      'assets/gtfs_data/stops.txt',
      thaiNames: thaiNames,
    );
    final ferryStops = await RouteAssetLoader.loadStops(
      'assets/gtfs_data/ferry_stop.txt',
      thaiNames: thaiNames,
    );
    final busStopList = await _parseBusStopsFromAsset(
      'assets/gtfs_data/bus_stop.txt',
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
    colorMap['BMTA Bus'] = Colors.blueAccent;
    final combinedStops = <gtfs.Stop>[...stops, ...busStopList, ...ferryStops];
    final stopMap = {for (final stop in combinedStops) stop.stopId: stop};

    await _buildStopToLinesMap(routes);

    _directionService.updateData(
      allStops: combinedStops,
      stopLookup: stopMap,
      routes: routes,
      fareTypeMap: fareTypeMap,
      fareDataMap: fareDataMap,
      stopOrderMap: stopOrderMap,
      fareTableMap: fareTableMap,
      ferryFlatFares: ferryFlatFares,
      ferryZoneMatrix: ferryZoneMatrix,
      ferryZones: ferryZones,
      busRouteInfoMap: busRouteInfoMap,
    );
    // Load GTFS shapes (preferred) — use tripMap loaded from DirectionService to avoid re-parsing
    List<ShapeSegment> shapes = const <ShapeSegment>[];
    try {
      final tripMap = await _directionService.loadTrips();
      final loadedShapes = await GtfsShapesService().loadSegments(
        shapesAssets: ['assets/gtfs_data/shapes.txt'],
        routeColors: {
          for (final r in routes)
            r.routeId: (r.color != null && r.color!.isNotEmpty)
                ? Color(int.parse('0xFF${r.color!}'))
                : Colors.purple,
        },
        tripMap: tripMap,
      );
      final mutableShapes = List<ShapeSegment>.from(loadedShapes);
      mutableShapes.sort((a, b) {
        final topZ = ['RN', 'RW', 'Air', 'AIR'];
        final aTop = topZ.contains(a.routeId) ? 1 : 0;
        final bTop = topZ.contains(b.routeId) ? 1 : 0;
        return aTop.compareTo(bTop);
      });
      shapes = mutableShapes;

      // Load heavy shapes asynchronously so it doesn't block initial launch
      // or zoom out the map too far.
      Future.microtask(() async {
        try {
          final heavyShapes = await GtfsShapesService().loadSegments(
            shapesAssets: ['assets/gtfs_data/shapes_source.txt'],
            routeColors: {
              for (final r in routes)
                r.routeId: (r.color != null && r.color!.isNotEmpty)
                    ? Color(int.parse('0xFF${r.color!}'))
                    : Colors.purple,
            },
            tripMap: tripMap,
          );
          if (mounted) {
            setState(() {
              shapeSegments.addAll(heavyShapes);
            });
          }
        } catch (_) {}
      });
    } catch (_) {}

    stops.sort((a, b) {
      final topZ = ['RN', 'RW', 'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8'];
      bool aTop = topZ.any((p) => a.stopId.startsWith(p));
      bool bTop = topZ.any((p) => b.stopId.startsWith(p));
      if (aTop && !bTop) return 1;
      if (!aTop && bTop) return -1;
      return 0;
    });

    setState(() {
      allRoutes = routes;
      railStops = stops;
      allStops = combinedStops;
      busStops = busStopList;
      this.ferryStops = ferryStops;
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
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(24)),
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

  Future<List<gtfs.Stop>> _parseBusStopsFromAsset(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return [];
      final header = _parseCsvLine(lines.first).map((s) => s.trim()).toList();
      int idxStopId = header.indexOf('stop_id');
      if (idxStopId < 0) idxStopId = 0;
      int idxName = header.indexOf('stop_name');
      if (idxName < 0) idxName = 1;
      int idxLat = header.indexOf('stop_lat');
      if (idxLat < 0) idxLat = 2;
      int idxLon = header.indexOf('stop_lon');
      if (idxLon < 0) idxLon = 3;
      final idxCode = header.indexOf('stop_code');
      final idxDesc = header.indexOf('stop_desc');
      final stops = <gtfs.Stop>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = _parseCsvLine(line);
        if (row.length <= idxStopId || row.length <= idxName) continue;
        if (row.length <= idxLat || row.length <= idxLon) continue;
        final baseId = row[idxStopId].trim().isEmpty
            ? 'BUS_$i'
            : row[idxStopId].trim();
        final stopId = baseId;
        final name = row[idxName].trim();
        final lat = double.tryParse(row[idxLat].trim());
        final lon = double.tryParse(row[idxLon].trim());
        if (name.isEmpty || lat == null || lon == null) continue;
        stops.add(
          gtfs.Stop(
            stopId: stopId,
            name: name,
            lat: lat,
            lon: lon,
            code: (idxCode >= 0 && row.length > idxCode)
                ? row[idxCode].trim()
                : null,
            desc: (idxDesc >= 0 && row.length > idxDesc)
                ? row[idxDesc].trim()
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
      final header = _parseCsvLine(
        lines.first,
      ).map((s) => s.toLowerCase()).toList();
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
    stopOrderMap.clear();
    fareTableMap.clear();
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

    // stopOrderMap: stopId → ลำดับสถานีบนสาย (เฉพาะ non-BTS ที่เป็นตัวเลข)
    try {
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
          final raw = (row.length > idxStatus) ? row[idxStatus].trim() : '';
          final order = int.tryParse(raw);
          if (id.isNotEmpty && order != null) stopOrderMap[id] = order;
        }
      }
    } catch (_) {}

    // fareTableMap: rowKey → List<int> จาก fare_table.txt
    try {
      final content = await rootBundle.loadString(
        'assets/gtfs_data/fare_table.txt',
      );
      final lines = const LineSplitter().convert(content);
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = _parseCsvLine(line);
        if (row.isEmpty) continue;
        final rowKey = row[0].trim();
        if (rowKey.isEmpty) continue;
        final fares = <int>[];
        for (int j = 1; j < row.length; j++) {
          fares.add(int.tryParse(row[j].trim()) ?? 0);
        }
        fareTableMap[rowKey] = fares;
      }
    } catch (_) {}

    try {
      ferryFlatFares = await RouteAssetLoader.loadFerryFlatFares(
        'assets/gtfs_data/ferry_flat_fares.txt',
      );
    } catch (_) {}
    try {
      ferryZoneMatrix = await RouteAssetLoader.loadFerryZoneMatrix(
        'assets/gtfs_data/ferry_zone_matrix.txt',
      );
    } catch (_) {}
    try {
      ferryZones = await RouteAssetLoader.loadFerryZones(
        'assets/gtfs_data/ferry_zones.txt',
      );
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

  Future<void> _buildStopToLinesMap(List<gtfs.Route> routes) async {
    final routeMap = {for (final r in routes) r.routeId: r};
    final tripToLine = <String, String>{};
    try {
      final tripContent = await rootBundle.loadString(
        'assets/gtfs_data/trips.txt',
      );
      final lines = const LineSplitter().convert(tripContent);
      if (lines.length > 1) {
        final header = _parseCsvLine(lines[0]);
        final routeIdx = header.indexOf('route_id');
        final tripIdx = header.indexOf('trip_id');
        if (routeIdx != -1 && tripIdx != -1) {
          for (int i = 1; i < lines.length; i++) {
            if (lines[i].trim().isEmpty) continue;
            final row = _parseCsvLine(lines[i]);
            if (row.length > math.max(routeIdx, tripIdx)) {
              final rId = row[routeIdx].trim();
              final tId = row[tripIdx].trim();
              final route = routeMap[rId];
              if (route != null) {
                final lineName = route.longName.isNotEmpty
                    ? route.longName
                    : route.routeId;
                tripToLine[tId] = lineName;
              }
            }
          }
        }
      }
    } catch (_) {}

    final stopTimesFiles = [
      'assets/gtfs_data/stop_times.txt',
      'assets/gtfs_data/bus_stop_times.txt',
      'assets/gtfs_data/ferry_stop_times.txt',
    ];

    for (final file in stopTimesFiles) {
      try {
        final stContent = await rootBundle.loadString(file);
        final lines = const LineSplitter().convert(stContent);
        if (lines.length <= 1) continue;
        final header = _parseCsvLine(lines[0]);
        final tripIdx = header.indexOf('trip_id');
        final stopIdx = header.indexOf('stop_id');
        if (tripIdx == -1 || stopIdx == -1) continue;

        for (int i = 1; i < lines.length; i++) {
          if (lines[i].trim().isEmpty) continue;
          final row = _parseCsvLine(lines[i]);
          if (row.length > math.max(tripIdx, stopIdx)) {
            final tId = row[tripIdx].trim();
            final sId = row[stopIdx].trim();
            final lineName = tripToLine[tId];
            if (lineName != null) {
              _stopToLinesMap.putIfAbsent(sId, () => {}).add(lineName);
            } else if (file.contains('ferry_stop_times') &&
                tId.startsWith('F_')) {
              final routeId = tId.split('_TRIP')[0];
              final route = routeMap[routeId];
              if (route != null) {
                final lName = route.longName.isNotEmpty
                    ? route.longName
                    : route.routeId;
                _stopToLinesMap.putIfAbsent(sId, () => {}).add(lName);
              }
            }
          }
        }
      } catch (_) {}
    }

    // Also parse bus_route_stop.txt for _stopToLinesMap
    try {
      final content = await rootBundle.loadString(
        'assets/gtfs_data/bus_route_stop.txt',
      );
      final lines = const LineSplitter().convert(content);
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        final row = _parseCsvLine(lines[i]);
        if (row.length > 5) {
          final routeShortName = row[1].trim();
          final routeId = routeShortName.split(' ').first;
          final route = routeMap[routeId];
          final lineName = route != null && route.longName.isNotEmpty
              ? route.longName
              : routeShortName;
          final descriptionBus = row[2].trim();
          final typeId = row[3].trim();
          // final agencyId = row[4].trim(); // skip parsing unused column for now
          final isExpressway =
              descriptionBus.contains('ทางด่วน') ||
              routeShortName.contains('E') ||
              routeShortName.contains('ทางด่วน');
          busRouteInfoMap[lineName] = gtfs.BusRouteInfo(
            routeShortName: lineName,
            typeId: typeId,
            isExpressway: isExpressway,
          );
          for (int j = 6; j < row.length; j++) {
            final sId = row[j].trim();
            if (sId.isNotEmpty) {
              _stopToLinesMap.putIfAbsent(sId, () => {}).add(lineName);
            }
          }
        }
      }
    } catch (_) {}
  }

  String? _cleanHex(String? hex) {
    if (hex == null) return null;
    var s = hex.trim().replaceAll('\r', '').replaceAll('#', '');
    if (s.isEmpty) return null;
    return s.toUpperCase();
  }

  void _animatedMapMove(
    LatLng destLocation,
    double destZoom, {
    int durationMs = 500,
    Curve curve = Curves.fastOutSlowIn,
  }) {
    // Create some tweens. These serve to split up the transition from one location to another.
    // In our case, we want to split the transition be<tween> our current map center and the destination.
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    // Create a animation controller that has a duration and a TickerProvider.
    final controller = AnimationController(
      duration: Duration(milliseconds: durationMs),
      vsync: this,
    );
    // The animation determines what path the animation will take. You can try different Curves values, although I found
    // fastOutSlowIn to be my favorite.
    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: curve,
    );

    // Note this method of encoding the target destination is a workaround.
    // When proper gradients are available we can directly use a generic Vector2.
    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  Future<void> _goToMyLocation() async {
    if (_userLocation?.latitude != null && _userLocation?.longitude != null) {
      _animatedMapMove(
        LatLng(_userLocation!.latitude!, _userLocation!.longitude!),
        math.max(_mapController.camera.zoom, 15.0),
      );
      // Still allow it to fall through to refresh location just in case? Or return?
      // Better to return for instant response, location stream is updating it anyway.
      return;
    }

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

    _locationSub ??= location.onLocationChanged.listen((
      LocationData currentLocation,
    ) {
      if (mounted) {
        setState(() {
          _userLocation = currentLocation;
        });
      }
    });

    final userLocation = await location.getLocation();
    if (userLocation.latitude != null && userLocation.longitude != null) {
      if (mounted) {
        setState(() {
          _userLocation = userLocation;
        });
      }
      _animatedMapMove(
        LatLng(userLocation.latitude!, userLocation.longitude!),
        math.max(_mapController.camera.zoom, 15.0),
      );
    }
  }

  void _openTransportLines() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const TransportLinesPage()));
  }

  void _openTransitUpdatePage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const TransitUpdatePage()));
  }

  void _openGraphicMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            GraphicMapPage(railStops: railStops, shapeSegments: shapeSegments),
      ),
    );
  }

  void _openCardsPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const CardsPage()));
  }

  void _openNavigation(DirectionOption option) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationPage(
          option: option,
          lineNameResolver: _getLineName,
          lineColorResolver: _getLineColor,
          lineColors: lineColors,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showNav = directionOptions.isEmpty;
    if (!showNav && _selectedNavIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedNavIndex = 0);
        }
      });
    }
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;

    // Breakpoint for foldables, tablets, and landscape phones
    final isWideLayout = width >= 600 || (width > height && height < 500);

    final bool showHome = !showNav || _selectedNavIndex == 0;
    late final Widget body;
    if (showHome) {
      body = _buildHomeContent(context, isWideLayout);
    } else if (_selectedNavIndex == 1) {
      body = TransitUpdatesListPage(
        initialReports: TransitUpdateService().activeReports,
        loadReports: () async => TransitUpdateService().activeReports,
      );
    } else {
      body = MorePage(
        onOpenTransportLines: _openTransportLines,
        onOpenTransitUpdates: _openTransitUpdatePage,
        onOpenGraphicMap: _openGraphicMap,
        onOpenCards: _openCardsPage,
        profile: _profile,
        currentAccentColor: widget.currentAccentColor,
        onAccentColorChanged: widget.onAccentColorChanged,
      );
    }

    final bodyContent = SafeArea(
      top: false,
      bottom: false, // map and other pages handle bottom insets natively
      child: body,
    );

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.colorScheme.surface,
      body: (isWideLayout && showNav)
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedNavIndex,
                  onDestinationSelected: (index) {
                    setState(() => _selectedNavIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.campaign_outlined),
                      selectedIcon: Icon(Icons.campaign),
                      label: Text('Updates'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.more_horiz),
                      selectedIcon: Icon(Icons.more),
                      label: Text('More'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: bodyContent),
              ],
            )
          : bodyContent,
      bottomNavigationBar: (!isWideLayout && showNav)
          ? _buildNavigationBar()
          : null,
    );
  }

  Widget _buildHomeContent(BuildContext context, bool isWideLayout) {
    final headerOverlay = _buildHeaderOverlay(context, isWideLayout);
    return SizedBox.expand(
      child: isWideLayout
          ? _buildWideLayout(context, headerOverlay)
          : _buildPhoneLayout(context, headerOverlay),
    );
  }

  Widget _buildNavigationBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: math.max(16.0, bottomPadding + 8.0),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.surface.withValues(
                      alpha: isDark ? 0.4 : 0.6,
                    ),
                    theme.colorScheme.surface.withValues(
                      alpha: isDark ? 0.2 : 0.4,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      0,
                      Icons.home_outlined,
                      Icons.home_rounded,
                      'Home',
                    ),
                    _buildNavItem(
                      1,
                      Icons.campaign_outlined,
                      Icons.campaign,
                      'Updates',
                    ),
                    _buildNavItem(2, Icons.more_horiz, Icons.more, 'More'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData outlineIcon,
    IconData filledIcon,
    String label,
  ) {
    final isSelected = _selectedNavIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedNavIndex = index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 20 : 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.surface.withValues(
                        alpha: isDark ? 0.3 : 0.8,
                      )
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha: isDark ? 0.15 : 0.6)
                      : Colors.transparent,
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                isSelected ? filledIcon : outlineIcon,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  //
}
