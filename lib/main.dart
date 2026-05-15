import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/station_details_content.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:route/services/gtfs_sync_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:route/services/direction_service.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;
import 'package:route/services/gtfs_shapes.dart';
import 'package:route/services/route_asset_loader.dart';
import 'package:route/services/transit_update_service.dart';

import 'pages/more_page.dart';
import 'pages/cards_page.dart';
import 'pages/about_page.dart';
import 'pages/transit_updates_list_page.dart';
import 'pages/transport_lines_page.dart';
import 'pages/navigation_page.dart';
import 'pages/graphic_map_page.dart';
import 'widgets/route_details_sheet.dart';
import 'widgets/route_options_panel.dart';

import 'widgets/search_tabs.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (make sure to run `flutterfire configure`!)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
  ThemeMode _themeMode = ThemeMode.system;
  bool _isReady = false;
  bool _showConsole = false;
  void _handleTap() {
    setState(() {
      _showConsole = !_showConsole;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _initializeApp();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    if (mounted) {
      setState(() {
        _themeMode = ThemeMode.values[themeIndex];
      });
    }
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  Future<void> _initializeApp() async {
    // Wait for the GTFS packages to download or verify before showing the app
    try {
      // 5-second timeout to ensure the app still launches when completely offline
      await gtfsSyncService.initAndSync().timeout(const Duration(seconds: 5));
    } catch (e) {
      // Proceed gracefully: we are either offline or it timed out,
      // the app will just fall back to the last downloaded files or the bundled assets.
    }

    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  void _updateAccentColor(Color color) {
    setState(() {
      _accentColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scrollBehavior: AppScrollBehavior(),
      title: 'Route Transit',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.googleSansTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: _accentColor),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.googleSansTextTheme(ThemeData.dark().textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accentColor,
          brightness: Brightness.dark,
        ),
      ),
      home: _isReady
          ? MyHomePage(
              title: 'Route Transit',
              currentAccentColor: _accentColor,
              onAccentColorChanged: _updateAccentColor,
              currentThemeMode: _themeMode,
              onThemeModeChanged: _saveThemeMode,
            )
          : Scaffold(
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleTap,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: _accentColor),
                      const SizedBox(height: 24),
                      Text(
                        'Loading Transit Data...',
                        style: GoogleFonts.googleSans(
                          textStyle: TextStyle(
                            color: _accentColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_showConsole)
                        Container(
                          margin: const EdgeInsets.only(top: 24),
                          padding: const EdgeInsets.all(16),
                          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ValueListenableBuilder<List<String>>(
                            valueListenable: gtfsSyncService.consoleLogs,
                            builder: (context, logs, child) {
                              return ListView.builder(
                                itemCount: logs.length,
                                itemBuilder: (context, index) {
                                  return Text(
                                    '> ${logs[index]}',
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
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
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  final String title;
  final Color currentAccentColor;
  final ValueChanged<Color> onAccentColorChanged;
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _ProjectionResult {
  final LatLng point;
  final double dist;
  _ProjectionResult(this.point, this.dist);
}

class FavoritePin {
  final String label;
  final LatLng point;
  FavoritePin(this.label, this.point);
  Map<String, dynamic> toJson() => {
    'label': label,
    'lat': point.latitude,
    'lng': point.longitude,
  };
  factory FavoritePin.fromJson(Map<String, dynamic> json) => FavoritePin(
    json['label'] as String,
    LatLng(json['lat'] as double, json['lng'] as double),
  );
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final LayerHitNotifier<int> _routeHitNotifier = ValueNotifier(null);

  final GlobalKey _headerGlobalKey = GlobalKey();

  List<FavoritePin> _favoritePins = [];
  bool _isGtfsDataLoaded = false;
  List<LatLng> _initialCameraPts = [];

  Future<void> _loadFavoritePins() async {
    if (_profile.favoritePins != null) {
      try {
        setState(() {
          _favoritePins = _profile.favoritePins!
              .map((e) => FavoritePin.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      } catch (e) {
        debugPrint('Failed to load favorite pins from profile: $e');
      }
    } else {
      // Fallback or migration
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('favorite_pins');
      if (jsonStr != null) {
        try {
          final List<dynamic> decoded = jsonDecode(jsonStr);
          setState(() {
            _favoritePins = decoded
                .map((e) => FavoritePin.fromJson(e as Map<String, dynamic>))
                .toList();
          });
          // Migrate
          _saveFavoritePins();
        } catch (e) {
          debugPrint('Failed to load favorite pins: $e');
        }
      }
    }
  }

  Future<void> _saveFavoritePins() async {
    final serialized = _favoritePins.map((e) => e.toJson()).toList();
    final newProfile = _profile.copyWith(favoritePins: serialized);
    _saveProfile(newProfile);
  }

  late final SearchController _startSearchController;
  late final FocusNode _startSearchFocus;
  static bool _hasShownWelcome = false;
  late final SearchController _destSearchController;
  late final FocusNode _destSearchFocus;
  late final SearchController _collapsedSearchController;
  late final FocusNode _collapsedSearchFocus;
  int _selectedNavIndex = 0;
  Profile _profile = const Profile(
    username: 'User',
    name: 'John Doe',
    joinedDate: '',
    profileImageUrl: '',
  );

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString('user_profile');
    if (profileJson != null) {
      try {
        final decoded = jsonDecode(profileJson);
        setState(() {
          _profile = Profile.fromJson(decoded);
        });
      } catch (e) {
        debugPrint('Failed to load profile: $e');
      }
    } else {
      final now = DateTime.now();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final joined = '${months[now.month - 1]} ${now.year}';
      _profile = _profile.copyWith(joinedDate: joined);
      _saveProfile(_profile);
    }

    _loadFavoritePins();
  }

  Future<void> _saveProfile(Profile newProfile) async {
    setState(() {
      _profile = newProfile;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(newProfile.toJson()));
  }

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
  List<gtfs.Pinpoint> pinpoints = [];
  Map<String, String> fareTypeMap = {};
  Map<String, gtfs.BusRouteInfo> busRouteInfoMap = {};
  Map<String, int> fareDataMap = {};
  Map<String, int> stopOrderMap = {};
  Map<String, List<int>> fareTableMap = {};
  Map<String, int> ferryFlatFares = {};
  Map<String, int> ferryZoneMatrix = {};
  Map<String, String> ferryZones = {};

  String routingMode = 'Fastest';
  String _selectedSortMode = 'Default';
  List<String> allowedTransitTypes = ['Metro', 'Train', 'Bus', 'Ferry'];
  final ValueNotifier<bool> _headerCollapsed = ValueNotifier<bool>(true);
  double _currentZoom = 12.0;
  static const double _busStopZoomThreshold = 15.0;

  bool _showTrainPins = true;
  bool _showMetroPins = true;
  bool _showBusPins = true;
  bool _showFerryPins = true;
  bool _showPinpoints = true;
  final Map<String, bool> _pinpointCategoryToggles = {
    'Education': true,
    'Healthcare': true,
    'Shopping': true,
    'Government': true,
    'Worship': true,
    'Hospitality': true,
    'Parks & Recreation': true,
    'Other': true,
  };

  List<Marker> _cachedBusMarkers = [];
  List<Marker> _cachedFerryMarkers = [];
  List<Marker> _cachedPinpointMarkers = [];
  List<Marker> _cachedFavoritePinMarkers = []; // non-stop favorite pins
  List<Polyline<int>> _cachedShapePolylines = [];
  Set<String> _routeStopIds = {};

  List<Polyline<int>> _cachedActiveDirectionPolylines = [];
  final Map<int, List<Polyline<int>>> _cachedInactiveDirectionPolylines = {};

  final Map<String, bool> _isTrainCache = {};
  final Map<String, bool> _isMetroCache = {};
  final Map<String, String?> _routeIconCache = {};

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

  final Map<String, String?> _lineNameCache = {};
  String? _getLineName(String stopId) {
    if (_lineNameCache.containsKey(stopId)) return _lineNameCache[stopId];
    if (stopId.startsWith('ST_') || stopId.startsWith('STOP_')) {
      _lineNameCache[stopId] = 'BMTA Bus';
      return 'BMTA Bus';
    }
    if (_stopToLinesMap.containsKey(stopId) &&
        _stopToLinesMap[stopId]!.isNotEmpty) {
      final lines = _stopToLinesMap[stopId]!.toList()..sort();
      final name = lines.join(', ');
      _lineNameCache[stopId] = name;
      return name;
    }
    _lineNameCache[stopId] = null;
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
      final content = await gtfsSyncService.getGtfsFile(assetPath);
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
  bool _isLoadingRoute = false;
  List<DirectionOption> directionOptions = [];
  DirectionOption? _viewingDetailsOption;
  gtfs.Stop? _viewingStop;
  LatLng? _viewingDroppedPin;
  gtfs.Pinpoint? _viewingPinpoint;
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

    setState(() {
      _isLoadingRoute = true;
      directionOptions.clear();
      _viewingStop = null;
      _viewingDroppedPin = null;
      _viewingPinpoint = null;
      _recalculateMapLayers();
    });

    // Yield a microtask so the loading indicator paints before heavy work.
    await Future.microtask(() {});

    try {
      final result = await _directionService.findDirections(
        routingMode: routingMode,
        allowedTransitTypes: allowedTransitTypes,
        startPoint: startOpt,
        destPoint: destOpt,
      );

      if (!mounted) return;

      setState(() {
        _isLoadingRoute = false;
        directionOptions = List<DirectionOption>.from(result.options);
        if (directionOptions.isEmpty) {
          selectedDirectionIndex = 0;
          _headerCollapsed.value = false;
        } else {
          _sortDirectionOptions();
          selectedDirectionIndex = 0;
          _headerCollapsed.value = true;
        }
        _recalculateMapLayers();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  final Map<String, Color> _lineColorCache = {};
  Color _getLineColor(String stopId) {
    if (_lineColorCache.containsKey(stopId)) return _lineColorCache[stopId]!;
    final lineName = _getLineName(stopId);
    if (lineName != null) {
      if (lineColors.containsKey(lineName)) {
        final col = lineColors[lineName]!;
        _lineColorCache[stopId] = col;
        return col;
      }
      final firstLine = lineName.split(', ').first;
      if (lineColors.containsKey(firstLine)) {
        final col = lineColors[firstLine]!;
        _lineColorCache[stopId] = col;
        return col;
      }

      final type = _directionService.getRouteTypeForLine(firstLine);
      if (type == '3') {
        _lineColorCache[stopId] = Colors.blue;
        return Colors.blue;
      }
      if (type == '4') {
        _lineColorCache[stopId] = Colors.orange;
        return Colors.orange;
      }
    }

    // Also check the stop itself if lineName didn't yield a type
    final stopType = _directionService.getRouteTypeForStop(stopId);
    if (stopType == '3' ||
        stopId.startsWith('ST_') ||
        stopId.startsWith('STOP_') ||
        int.tryParse(stopId) != null ||
        stopId.startsWith('B') ||
        stopId.startsWith('BUS_')) {
      _lineColorCache[stopId] = Colors.blue;
      return Colors.blue;
    }
    if (stopType == '4' ||
        stopId.startsWith('F_') ||
        stopId.startsWith('CRF_')) {
      _lineColorCache[stopId] = Colors.orange;
      return Colors.orange;
    }

    _lineColorCache[stopId] = Colors.purple;
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
    final type = _directionService.getRouteTypeForLine(firstLine);
    if (type == '3') return Colors.blue;
    if (type == '4') return Colors.orange;
    return Colors.purple;
  }

  String? _getRouteIcon(String lineName) {
    if (lineName.isEmpty) return null;
    if (_routeIconCache.containsKey(lineName)) return _routeIconCache[lineName];
    final firstLine = lineName.split(', ').first;

    if (firstLine.toUpperCase() == 'BRT') {
      _routeIconCache[lineName] = 'assets/icons/BRT.svg';
      return 'assets/icons/BRT.svg';
    }

    try {
      final route = allRoutes.firstWhere(
        (r) => r.shortName == firstLine || r.longName == firstLine,
      );
      final icon = route.routeIcon;
      _routeIconCache[lineName] = icon;
      return icon;
    } catch (e) {
      _routeIconCache[lineName] = null;
      return null;
    }
  }

  Polyline<int> _linePolyline(
    LatLng from,
    LatLng to,
    Color color, {
    int? hitValue,
    bool isActive = true,
    Color? borderColor,
  }) {
    return Polyline<int>(
      hitValue: hitValue,
      points: [from, to],
      color: color,
      borderStrokeWidth: isActive ? 0.0 : 2.0,
      borderColor: isActive
          ? Colors.transparent
          : borderColor ?? Colors.transparent,
      strokeWidth: isActive ? 6.0 : 4.0,
    );
  }

  List<Polyline<int>> _buildRoutePolylines(
    List<RouteSegment> segments, {
    int? hitValue,
    bool isActive = true,
  }) {
    final polylines = <Polyline<int>>[];
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
            Polyline<int>(
              hitValue: hitValue,
              points: points,
              color: isActive ? const Color(0xFF6B4226) : Colors.grey,
              borderStrokeWidth: isActive ? 0.0 : 2.0,
              borderColor: isActive
                  ? Colors.transparent
                  : const Color(0xFF6B4226),
              strokeWidth: 7.0,
            ),
          );
          polylines.add(
            Polyline<int>(
              hitValue: hitValue,
              points: points,
              color: isActive ? Colors.white : Colors.grey.shade300,
              strokeWidth: 4.0,
              pattern: StrokePattern.dashed(segments: [10.0, 10.0]),
            ),
          );
        } else {
          polylines.add(
            Polyline<int>(
              hitValue: hitValue,
              points: points,
              color: isActive ? lineColor : Colors.grey,
              borderStrokeWidth: isActive ? 0.0 : 2.0,
              borderColor: isActive ? Colors.transparent : lineColor,
              strokeWidth: isActive ? width : 4.0,
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
              color: isActive ? lineColor : lineColor.withValues(alpha: 0.2),
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

          final targetId = segment.routeId ?? lineName.split(' ').first;
          final exactShapeId = segment.shapeId;

          List<ShapeSegment> validShapes = [];
          if (exactShapeId != null && exactShapeId.isNotEmpty) {
            validShapes = shapeSegments
                .where((s) => s.shapeId == exactShapeId)
                .toList();
          }
          if (validShapes.isEmpty && targetId.isNotEmpty) {
            validShapes = shapeSegments
                .where(
                  (s) => s.routeId == targetId || s.shapeId.contains(targetId),
                )
                .toList();
          }
          if (validShapes.isEmpty) {
            validShapes = shapeSegments;
          }

          bool foundShape = false;
          // Look for a shape that connects stopA and stopB
          for (final shape in validShapes) {
            final aLocs = <int>[];
            final bLocs = <int>[];
            for (int k = 0; k < shape.pointNames.length; k++) {
              if (shape.pointNames[k] == stopA) aLocs.add(k);
              if (shape.pointNames[k] == stopB) bLocs.add(k);
            }

            if (aLocs.isNotEmpty && bLocs.isNotEmpty) {
              final N = shape.points.length;
              final isLoop = N > 2 && const Distance().as(
                LengthUnit.Meter,
                shape.points.first,
                shape.points.last,
              ) < 100;

              int bestGap = 999999;
              int bestA = -1;
              int bestB = -1;
              for (final a in aLocs) {
                for (final b in bLocs) {
                  int gap = (a - b).abs();
                  if (isLoop && gap > N / 2) {
                    gap = N - gap;
                  }
                  if (gap < bestGap) {
                    bestGap = gap;
                    bestA = a;
                    bestB = b;
                  }
                }
              }

              List<LatLng> shapePoints;
              if (isLoop && (bestA - bestB).abs() > N / 2) {
                if (bestA > bestB) {
                  shapePoints = shape.points.sublist(bestA, N);
                  shapePoints.addAll(shape.points.sublist(0, bestB + 1));
                } else {
                  shapePoints = shape.points.sublist(0, bestA + 1).reversed.toList();
                  shapePoints.addAll(shape.points.sublist(bestB, N).reversed.toList());
                }
              } else {
                final isReversed = bestA > bestB;
                final startIdx = isReversed ? bestB : bestA;
                final endIdx = isReversed ? bestA : bestB;
                shapePoints = shape.points.sublist(startIdx, endIdx + 1);
                if (isReversed) {
                  shapePoints = shapePoints.reversed.toList();
                }
              }
              polylines.add(
                Polyline<int>(
                  hitValue: hitValue,
                  points: shapePoints,
                  color: isActive ? lineColor : Colors.grey,
                  borderStrokeWidth: isActive ? 0.0 : 2.0,
                  borderColor: isActive ? Colors.transparent : lineColor,
                  strokeWidth: isActive ? 6.0 : 4.0,
                ),
              );
              foundShape = true;
              break;
            }
          } // Geometric fallback for buses
          if (!foundShape) {
            // targetId and exactShapeId already computed
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
                  final N = shape.points.length;
                  final isLoop = N > 2 && const Distance().as(
                    LengthUnit.Meter,
                    shape.points.first,
                    shape.points.last,
                  ) < 100;

                  List<LatLng> shapePoints;
                  if (isLoop && (bestA - bestB).abs() > N / 2) {
                    if (bestA > bestB) {
                      shapePoints = shape.points.sublist(bestA, N);
                      shapePoints.addAll(shape.points.sublist(0, bestB + 1));
                    } else {
                      shapePoints = shape.points.sublist(0, bestA + 1).reversed.toList();
                      shapePoints.addAll(shape.points.sublist(bestB, N).reversed.toList());
                    }
                  } else {
                    final isReversed = bestA > bestB;
                    final startIdx = isReversed ? bestB : bestA;
                    final endIdx = isReversed ? bestA : bestB;
                    shapePoints = shape.points.sublist(startIdx, endIdx + 1);
                    if (isReversed) {
                      shapePoints = shapePoints.reversed.toList();
                    }
                  }

                  polylines.add(
                    Polyline<int>(
                      hitValue: hitValue,
                      points: shapePoints,
                      color: isActive ? lineColor : Colors.grey,
                      borderStrokeWidth: isActive ? 0.0 : 2.0,
                      borderColor: isActive ? Colors.transparent : lineColor,
                      strokeWidth: isActive ? 6.0 : 4.0,
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
                  final N = shape.points.length;
                  final isLoop = N > 2 && const Distance().as(
                    LengthUnit.Meter,
                    shape.points.first,
                    shape.points.last,
                  ) < 100;

                  List<LatLng> shapePoints;
                  if (isLoop && (bestA - bestB).abs() > N / 2) {
                    if (bestA > bestB) {
                      shapePoints = shape.points.sublist(bestA, N);
                      shapePoints.addAll(shape.points.sublist(0, bestB + 1));
                    } else {
                      shapePoints = shape.points.sublist(0, bestA + 1).reversed.toList();
                      shapePoints.addAll(shape.points.sublist(bestB, N).reversed.toList());
                    }
                  } else {
                    final isReversed = bestA > bestB;
                    final startIdx = isReversed ? bestB : bestA;
                    final endIdx = isReversed ? bestA : bestB;
                    shapePoints = shape.points.sublist(startIdx, endIdx + 1);
                    if (isReversed) {
                      shapePoints = shapePoints.reversed.toList();
                    }
                  }

                  polylines.add(
                    Polyline<int>(
                      hitValue: hitValue,
                      points: shapePoints,
                      color: isActive ? lineColor : Colors.grey,
                      borderStrokeWidth: isActive ? 0.0 : 2.0,
                      borderColor: isActive ? Colors.transparent : lineColor,
                      strokeWidth: isActive ? 6.0 : 4.0,
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
                isActive ? lineColor : Colors.grey,
                hitValue: hitValue,
                isActive: isActive,
                borderColor: lineColor,
              ),
            );
          }
        }
      }
    }
    return polylines;
  }

  void _addOffsetConnectionLine({
    required List<Polyline<int>> polylines,
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
          color: color.withValues(
            alpha: color.a == 0.2 ? 1.0 : 0.5,
          ), // Retain original offset trace
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
      _viewingDroppedPin = null;
      _viewingPinpoint = null;
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

  void _promptSaveFavorite(LatLng point) {
    String label = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save Favorite Pin'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Label'),
            onChanged: (val) => label = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (label.isNotEmpty) {
                  setState(() {
                    _favoritePins.add(FavoritePin(label, point));
                  });
                  _saveFavoritePins();
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDroppedPinDetails(BuildContext context, LatLng point) {
    try {
      final stop = allStops.firstWhere(
        (s) => s.lat == point.latitude && s.lon == point.longitude,
      );
      _showStopDetails(context, stop);
      return;
    } catch (_) {}

    setState(() {
      _viewingDroppedPin = point;
      _viewingStop = null;
      _viewingPinpoint = null;
      _viewingDetailsOption = null;
    });
  }

  // ── Pinpoint helpers ──

  static const Map<String, List<String>> _pinpointCategoryTypes = {
    'Education': [
      'university', 'school', 'college', 'kindergarten', 'cram_school',
      'language_school', 'music_school', 'dancing_school', 'cooking_school',
      'sport_school', 'prep_school',
    ],
    'Healthcare': ['hospital', 'clinic'],
    'Shopping': [
      'mall', 'department_store', 'marketplace', 'convenience',
      'department_store;wholesale', 'mall;supermarket',
    ],
    'Government': ['government', 'courthouse', 'townhall', 'police', 'diplomatic'],
    'Worship': ['place_of_worship'],
    'Hospitality': ['hotel', 'hostel', 'guest_house', 'resort', 'hotel;guest_house'],
    'Parks & Recreation': ['park', 'garden', 'dog_park', 'water_park', 'sports_centre'],
  };

  String _pinpointCategory(String placeType) {
    for (final entry in _pinpointCategoryTypes.entries) {
      if (entry.value.contains(placeType)) return entry.key;
    }
    return 'Other';
  }

  IconData _pinpointIcon(String placeType) {
    switch (_pinpointCategory(placeType)) {
      case 'Education':         return Icons.school;
      case 'Healthcare':        return Icons.local_hospital;
      case 'Shopping':          return Icons.shopping_bag;
      case 'Government':        return Icons.account_balance;
      case 'Worship':           return Icons.temple_buddhist;
      case 'Hospitality':       return Icons.hotel;
      case 'Parks & Recreation': return Icons.park;
      default:                  return Icons.place;
    }
  }

  Color _pinpointColor(String placeType) {
    switch (_pinpointCategory(placeType)) {
      case 'Education':         return Colors.indigo;
      case 'Healthcare':        return Colors.red.shade700;
      case 'Shopping':          return Colors.pink;
      case 'Government':        return Colors.blueGrey;
      case 'Worship':           return Colors.amber.shade800;
      case 'Hospitality':       return Colors.deepPurple;
      case 'Parks & Recreation': return Colors.green.shade700;
      default:                  return Colors.grey.shade700;
    }
  }

  IconData _pinpointCategoryIcon(String category) {
    switch (category) {
      case 'Education':         return Icons.school;
      case 'Healthcare':        return Icons.local_hospital;
      case 'Shopping':          return Icons.shopping_bag;
      case 'Government':        return Icons.account_balance;
      case 'Worship':           return Icons.temple_buddhist;
      case 'Hospitality':       return Icons.hotel;
      case 'Parks & Recreation': return Icons.park;
      default:                  return Icons.place;
    }
  }

  Color _pinpointCategoryColor(String category) {
    switch (category) {
      case 'Education':         return Colors.indigo;
      case 'Healthcare':        return Colors.red.shade700;
      case 'Shopping':          return Colors.pink;
      case 'Government':        return Colors.blueGrey;
      case 'Worship':           return Colors.amber.shade800;
      case 'Hospitality':       return Colors.deepPurple;
      case 'Parks & Recreation': return Colors.green.shade700;
      default:                  return Colors.grey.shade700;
    }
  }

  void _showPinpointDetails(BuildContext context, gtfs.Pinpoint pinpoint) {
    setState(() {
      _viewingPinpoint = pinpoint;
      _viewingStop = null;
      _viewingDroppedPin = null;
      _viewingDetailsOption = null;
    });
  }

  Widget _buildPinpointPanelContent(
    BuildContext context,
    gtfs.Pinpoint pinpoint,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final placeColor = _pinpointColor(pinpoint.placeType);
    final placeIcon = _pinpointIcon(pinpoint.placeType);
    final category = _pinpointCategory(pinpoint.placeType);

    final bool isFavorite = _favoritePins.any(
      (p) =>
          p.point.latitude == pinpoint.lat &&
          p.point.longitude == pinpoint.lon,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero card — same style as StationDetailsContent._buildHeroCard
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category icon circle
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: placeColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(placeIcon, size: 24, color: placeColor),
                    ),
                    const SizedBox(width: 14),
                    // Name column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pinpoint.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (pinpoint.nameEn != null &&
                              pinpoint.nameEn!.isNotEmpty &&
                              pinpoint.nameEn != pinpoint.name)
                            Text(
                              pinpoint.nameEn!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Favorite button
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                      ),
                      color: isFavorite ? Colors.red : scheme.onSurfaceVariant,
                      onPressed: () {
                        setState(() {
                          final point = LatLng(pinpoint.lat, pinpoint.lon);
                          if (isFavorite) {
                            _favoritePins.removeWhere(
                              (p) =>
                                  p.point.latitude == point.latitude &&
                                  p.point.longitude == point.longitude,
                            );
                          } else {
                            _favoritePins.add(
                              FavoritePin(pinpoint.name, point),
                            );
                          }
                          _saveFavoritePins();
                          _recalculateMapLayers();
                        });
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surface.withValues(alpha: 0.8),
                        padding: const EdgeInsets.all(8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    // Close button
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _viewingPinpoint = null),
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surface.withValues(alpha: 0.8),
                        padding: const EdgeInsets.all(8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Category badge — own row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: placeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(placeIcon, size: 14, color: placeColor),
                          const SizedBox(width: 5),
                          Text(
                            category,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: placeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Coordinates & type chips — new row below category
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'COORDINATES',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${pinpoint.lat.toStringAsFixed(4)}, ${pinpoint.lon.toStringAsFixed(4)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (pinpoint.placeType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'TYPE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 0.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pinpoint.placeType.replaceAll('_', ' '),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

              ],
            ),
          ),
          const SizedBox(height: 16),
          // Action buttons — matching StationDetailsContent._buildQuickActionButtons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    setState(() => _viewingPinpoint = null);
                    _assignCustomPointSelection(
                      LatLng(pinpoint.lat, pinpoint.lon),
                      asStart: true,
                    );
                  },
                  icon: const Icon(Icons.trip_origin),
                  label: const Text('Origin'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    setState(() => _viewingPinpoint = null);
                    _assignCustomPointSelection(
                      LatLng(pinpoint.lat, pinpoint.lon),
                      asStart: false,
                    );
                  },
                  icon: const Icon(Icons.flag),
                  label: const Text('Destination'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDroppedPinPanelContent(BuildContext context, LatLng point) {
    FavoritePin? matchingPin;
    try {
      matchingPin = _favoritePins.firstWhere(
        (p) =>
            p.point.latitude == point.latitude &&
            p.point.longitude == point.longitude,
      );
    } catch (_) {}

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final bool isFavorite = matchingPin != null;
    final label = matchingPin?.label ?? 'Dropped Pin';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero card matching StationDetailsContent
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.place,
                        color: Colors.redAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Custom location',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                      ),
                      color: isFavorite ? Colors.red : scheme.onSurfaceVariant,
                      onPressed: () {
                        if (isFavorite) {
                          setState(() {
                            _favoritePins.removeWhere(
                              (p) =>
                                  p.point.latitude == point.latitude &&
                                  p.point.longitude == point.longitude,
                            );
                          });
                          _saveFavoritePins();
                        } else {
                          _promptSaveFavorite(point);
                        }
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surface.withValues(alpha: 0.8),
                        padding: const EdgeInsets.all(8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _viewingDroppedPin = null),
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surface.withValues(alpha: 0.8),
                        padding: const EdgeInsets.all(8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Coordinate chip
                Wrap(
                  spacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'COORDINATES',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Action buttons matching StationDetailsContent
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    _assignCustomPointSelection(point, asStart: true);
                    setState(() => _viewingDroppedPin = null);
                  },
                  icon: const Icon(Icons.trip_origin),
                  label: const Text('Origin'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    _assignCustomPointSelection(point, asStart: false);
                    setState(() => _viewingDroppedPin = null);
                  },
                  icon: const Icon(Icons.flag),
                  label: const Text('Destination'),
                ),
              ),
            ],
          ),
        ],
      ),
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

      directionOptions = [];
      selectedDirectionIndex = 0;
      _recalculateMapLayers();

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
      _recalculateMapLayers();
    });
  }

  void _sortDirectionOptions() {
    if (directionOptions.isEmpty) return;

    directionOptions.sort((a, b) {
      if (_selectedSortMode == 'Price') {
        final aFare = a.fareBreakdown['total'] ?? 0;
        final bFare = b.fareBreakdown['total'] ?? 0;
        if (aFare != bFare) return aFare.compareTo(bFare);
        return a.minutes.compareTo(b.minutes);
      } else if (_selectedSortMode == 'Distance') {
        if (a.distanceMeters != b.distanceMeters) {
          return a.distanceMeters.compareTo(b.distanceMeters);
        }
        return a.minutes.compareTo(b.minutes);
      } else if (_selectedSortMode == 'Fastest') {
        if (a.minutes != b.minutes) {
          return a.minutes.compareTo(b.minutes);
        }
        return a.distanceMeters.compareTo(b.distanceMeters);
      } else {
        // Default: Fewest Transfer > Rail Priority > cheapest > fastest > other
        final aTransfers = a.segments
            .where((s) => s.mode == TravelMode.transit)
            .length;
        final bTransfers = b.segments
            .where((s) => s.mode == TravelMode.transit)
            .length;

        // Lower is better for transfers
        if (aTransfers != bTransfers) return aTransfers.compareTo(bTransfers);

        // Rail Priority
        final aHasRail = a.tags.contains('Rail priority') ? 0 : 1;
        final bHasRail = b.tags.contains('Rail priority') ? 0 : 1;
        if (aHasRail != bHasRail) return aHasRail.compareTo(bHasRail);

        // Cheapest
        final aFare = a.fareBreakdown['total'] ?? 0;
        final bFare = b.fareBreakdown['total'] ?? 0;
        if (aFare != bFare) return aFare.compareTo(bFare);

        // Fastest
        if (a.minutes != b.minutes) return a.minutes.compareTo(b.minutes);

        return a.distanceMeters.compareTo(b.distanceMeters);
      }
    });
  }

  void _selectRouteOption(int index) {
    if (index < 0 || index >= directionOptions.length) return;
    setState(() {
      selectedDirectionIndex = index;
      _recalculateMapLayers();
    });
  }

  static const List<List<String>> _mergedStopGroups = [
    ['BL10', 'PP16'],
    ['S12', 'BL34'],
    ['S7', 'G1'],
    ['BKK', 'BKK01', 'BKK02'],
    ['TCJ', 'TCJ01', 'RW06'],
    ['PTM', 'PTM01'],
    ['YMR', 'YMR01'],
    ['RMD', 'RMD01'],
    ['SAM', 'SAM01'],
    ['BSJ', 'BSJ01'],
    ['STS', 'STS01'],
    ['KTW', 'KTW01'],
    ['BGB', 'BGB01'],
    ['DMU', 'DMU01'],
    ['RSI', 'RSI01'],
    ['RW01', 'RN01', 'KTW', 'KTW01'],
  ];

  List<gtfs.Stop> _getActualMergedStops(gtfs.Stop stop) {
    for (final group in _mergedStopGroups) {
      if (group.contains(stop.stopId)) {
        final matches = allStops.where((s) => group.contains(s.stopId)).toList();
        matches.sort((a, b) => a.stopId.compareTo(b.stopId));
        return matches;
      }
    }
    return const <gtfs.Stop>[];
  }

  Widget _buildPanelContent(BuildContext context) {
    if (_viewingDroppedPin != null) {
      return _buildDroppedPinPanelContent(context, _viewingDroppedPin!);
    }
    if (_viewingPinpoint != null) {
      return _buildPinpointPanelContent(context, _viewingPinpoint!);
    }
    if (_viewingStop != null) {
      final stop = _viewingStop!;
      final lineName = _getLineName(stop.stopId);
      final lineColor = _getLineColor(stop.stopId);
      final transferStops = _directionService.getTransferStations(stop.stopId);
      final bool isFavorite = _favoritePins.any(
        (p) => p.point.latitude == stop.lat && p.point.longitude == stop.lon,
      );
      final actualMergedStops = _getActualMergedStops(stop);

      return Stack(
        key: const ValueKey('station_details'),
        children: [
          StationDetailsContent(
            stop: stop,
            lineColor: lineColor,
            lineName: lineName,
            isBottomSheet: true,
            isSidePanel: true,
            isFavorite: isFavorite,
            mergedGroupStops: actualMergedStops,
            onToggleFavorite: () {
              setState(() {
                if (isFavorite) {
                  _favoritePins.removeWhere(
                    (p) =>
                        p.point.latitude == stop.lat &&
                        p.point.longitude == stop.lon,
                  );
                } else {
                  _favoritePins.add(
                    FavoritePin(stop.name, LatLng(stop.lat, stop.lon)),
                  );
                }
                _saveFavoritePins();
                _recalculateMapLayers();
              });
            },
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
            onClose: () {
              setState(() => _viewingStop = null);
            },
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
        routeIconResolver: _getRouteIcon,
      );
    } else {
      content = RouteOptionsPanel(
        key: const ValueKey('route_options'),
        options: directionOptions,
        selectedIndex: selectedDirectionIndex,
        onSelectOption: _selectRouteOption,
        selectedSortMode: _selectedSortMode,
        onSortModeChanged: (newMode) {
          if (newMode != null) {
            setState(() {
              _selectedSortMode = newMode;
              _sortDirectionOptions();
              selectedDirectionIndex = 0;
              _recalculateMapLayers();
            });
          }
        },
        onViewDetails: (option) {
          setState(() {
            _viewingDetailsOption = option;
          });
        },
        onStartNavigation: _openNavigation,
        lineNameResolver: _getLineName,
        lineColors: lineColors,
        routeIconResolver: _getRouteIcon,
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
    final hasPanelContent =
        directionOptions.isNotEmpty ||
        _viewingStop != null ||
        _viewingDroppedPin != null ||
        _viewingPinpoint != null;

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
    final showPinpoints =
        _showPinpoints &&
        pinpoints.isNotEmpty &&
        _currentZoom >= _busStopZoomThreshold;

    final rawFilteredRailStops = railStops.where((stop) {
      final isTrain = _isStopTrain(stop);
      final isMetro = _isStopMetro(stop);

      if (activeSegments.isNotEmpty &&
          !_routeStopIds.contains(stop.stopId) &&
          stop.stopId != startId &&
          stop.stopId != destId) {
        return false;
      }

      if (isTrain && !_showTrainPins) return false;
      if (isMetro && !_showMetroPins) return false;
      if (!isTrain && !isMetro) {
        // Fallback if type isn't correctly identified, use metro fallback as before
        if (!_showMetroPins) return false;
      }
      return true;
    }).toList();

    // Deduplicate rail stops by user groups explicit manual list
    int getMarkerPriority(gtfs.Stop s) {
      if (activeSegments.isNotEmpty && _routeStopIds.contains(s.stopId)) return 0;
      if (s.stopId == startId || s.stopId == destId) return 0;
      
      if (_isStopMetro(s)) return 1;
      
      if (_isStopTrain(s)) {
        final lineName = _getLineName(s.stopId) ?? '';
        if (lineName.contains('SRT Red') || lineName.contains('SRT Light Red')) {
          return 2;
        }
        return 3;
      }
      return 4;
    }

    final mergedMap = <String, gtfs.Stop>{};
    for (final stop in rawFilteredRailStops) {
      String key = stop.stopId;
      for (final group in _mergedStopGroups) {
        if (group.contains(stop.stopId)) {
          key = group.join('_');
          break;
        }
      }

      if (!mergedMap.containsKey(key)) {
        mergedMap[key] = stop;
      } else {
        // If current stop has higher priority (lower number), prefer it
        if (getMarkerPriority(stop) < getMarkerPriority(mergedMap[key]!)) {
          mergedMap[key] = stop;
        }
      }
    }
    final filteredRailStops = mergedMap.values.toList();

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
              final newCenter = event.camera.center;
              final wasShowingBus = _currentZoom >= _busStopZoomThreshold;
              final nowShowingBus = newZoom >= _busStopZoomThreshold;

              // Always track current center (used by _isInViewport).
              _currentCenter = newCenter;

              // Rebuild markers when a gesture ends or zoom changes tier,
              // so the viewport-culling bounding box reflects the new position.
              final isGestureEnd =
                  event is MapEventMoveEnd ||
                  event is MapEventDoubleTapZoom ||
                  event is MapEventScrollWheelZoom ||
                  event is MapEventFlingAnimation;

              if (wasShowingBus != nowShowingBus ||
                  (newZoom.round() - _currentZoom.round()).abs() >= 1 ||
                  isGestureEnd) {
                // Compute new marker lists BEFORE setState so the rebuild
                // immediately has the correct data — avoids a second pass.
                _recalculateMapLayers();
                setState(() {
                  _currentZoom = newZoom;
                });
              }
            },
            onTap: (tapPosition, point) {
              setState(() {
                if (_collapsedSearchFocus.hasFocus) {
                  _collapsedSearchFocus.unfocus();
                }
                if (_collapsedSearchController.text.isNotEmpty) {
                  _collapsedSearchController.clear();
                }
                if (_startSearchFocus.hasFocus) {
                  _startSearchFocus.unfocus();
                }
                if (_startSearchController.text.isNotEmpty &&
                    selectedStartStopId == null &&
                    _customStartPoint == null) {
                  _startSearchController.clear();
                }
                if (_destSearchFocus.hasFocus) {
                  _destSearchFocus.unfocus();
                }
                if (_destSearchController.text.isNotEmpty &&
                    selectedDestinationStopId == null &&
                    _customDestPoint == null) {
                  _destSearchController.clear();
                }
              });
            },
            onLongPress: (tapPosition, point) {
              if (directionOptions.isEmpty) {
                _showDroppedPinDetails(context, point);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.route',
              maxNativeZoom: 19,
              keepBuffer: 5,
              panBuffer: 2,
            ),
            if (shapeSegments.isNotEmpty)
              PolylineLayer(polylines: _cachedShapePolylines),

            if (_cachedInactiveDirectionPolylines.isNotEmpty)
              for (final entry in _cachedInactiveDirectionPolylines.entries)
                PolylineLayer<int>(
                  hitNotifier: _routeHitNotifier,
                  polylines: entry.value,
                ),

            if (_cachedActiveDirectionPolylines.isNotEmpty)
              PolylineLayer<int>(
                hitNotifier: _routeHitNotifier,
                polylines: _cachedActiveDirectionPolylines,
              ),

            if (showPinpoints) MarkerLayer(markers: _cachedPinpointMarkers),
            if (showBusStops) MarkerLayer(markers: _cachedBusMarkers),
            if (showFerryStops) MarkerLayer(markers: _cachedFerryMarkers),
            if (_cachedFavoritePinMarkers.isNotEmpty)
              MarkerLayer(markers: _cachedFavoritePinMarkers),
            if (filteredRailStops.isNotEmpty)
              MarkerLayer(
                markers: filteredRailStops.map((stop) {
                  final lineName = _getLineName(stop.stopId);
                  final routeIcon = lineName != null
                      ? _getRouteIcon(lineName)
                      : null;
                  final isSelected =
                      stop.stopId == startId || stop.stopId == destId;
                  final dim =
                      activeSegments.isNotEmpty &&
                      !_routeStopIds.contains(stop.stopId) &&
                      !isSelected;

                  return Marker(
                    point: LatLng(stop.lat, stop.lon),
                    width: isSelected
                        ? railSelectedSize * 1.5
                        : railBaseSize * 1.5,
                    height: isSelected
                        ? railSelectedSize * 1.5
                        : railBaseSize * 1.5,
                    child: GestureDetector(
                      onTap: () => _showStopDetails(context, stop),
                      child: Tooltip(
                        message: _stopDisplayLabel(stop),
                        child:
                            routeIcon != null &&
                                routeIcon.isNotEmpty &&
                                _currentZoom >= 12
                            ? Container(
                                decoration: BoxDecoration(
                                  color: stop.stopId == startId
                                      ? Colors.greenAccent.withValues(
                                          alpha: 0.85,
                                        )
                                      : stop.stopId == destId
                                      ? Colors.redAccent.withValues(alpha: 0.85)
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: dim
                                        ? Colors.grey.shade500
                                        : _getLineColor(stop.stopId),
                                    width: isSelected
                                        ? railSelectedBorderWidth
                                        : railBorderWidth,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Opacity(
                                    opacity: dim ? 0.4 : 1.0,
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                        isSelected ? 3.0 : 2.0,
                                      ),
                                      child: SvgPicture.asset(
                                        routeIcon,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: (stop.stopId == startId)
                                      ? Colors.greenAccent.withValues(
                                          alpha: 0.85,
                                        )
                                      : (stop.stopId == destId)
                                      ? Colors.redAccent.withValues(alpha: 0.85)
                                      : (activeSegments.isNotEmpty &&
                                            !_routeStopIds.contains(
                                              stop.stopId,
                                            ))
                                      ? Colors.grey.shade300
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        (activeSegments.isNotEmpty &&
                                            !_routeStopIds.contains(
                                              stop.stopId,
                                            ) &&
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
                  );
                }).toList(),
              ),
            if (_customStartPoint != null || selectedStartStopId != null)
              Builder(
                builder: (context) {
                  double? lat, lon;
                  if (_customStartPoint != null) {
                    lat = _customStartPoint!.lat;
                    lon = _customStartPoint!.lon;
                  } else if (selectedStartStopId != null) {
                    try {
                      final stop = allStops.firstWhere(
                        (s) => s.stopId == selectedStartStopId,
                      );
                      lat = stop.lat;
                      lon = stop.lon;
                    } catch (_) {}
                  }
                  if (lat != null && lon != null) {
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lon),
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 4,
                              ),
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
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            if (_customDestPoint != null || selectedDestinationStopId != null)
              Builder(
                builder: (context) {
                  double? lat, lon;
                  if (_customDestPoint != null) {
                    lat = _customDestPoint!.lat;
                    lon = _customDestPoint!.lon;
                  } else if (selectedDestinationStopId != null) {
                    try {
                      final stop = allStops.firstWhere(
                        (s) => s.stopId == selectedDestinationStopId,
                      );
                      lat = stop.lat;
                      lon = stop.lon;
                    } catch (_) {}
                  }
                  if (lat != null && lon != null) {
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lon),
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.secondary,
                                width: 4,
                              ),
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
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
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
              if (directionOptions.isEmpty) ...[
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
                                    alpha: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? 0.4
                                        : 0.6,
                                  ),
                              Theme.of(context).colorScheme.surface.withValues(
                                    alpha: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? 0.2
                                        : 0.4,
                                  ),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.15
                                  : 0.4,
                            ),
                            width: 1.2,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: IconButton(
                            icon: const Icon(Icons.info_outline),
                            tooltip: 'About',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AboutPage(),
                                ),
                              );
                            },
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
                const SizedBox(height: 16),
              ],
              if (directionOptions.isEmpty) _buildFilterMenu(isWide),
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
        (val) => setState(() {
          _showTrainPins = val;
          _recalculateMapLayers();
        }),
      ),
      _buildFilterMenuItem(
        'Metro Station',
        Icons.subway,
        Colors.blue,
        _showMetroPins,
        (val) => setState(() {
          _showMetroPins = val;
          _recalculateMapLayers();
        }),
      ),
      _buildFilterMenuItem(
        'Bus Stop',
        Icons.directions_bus,
        Colors.green,
        _showBusPins,
        (val) => setState(() {
          _showBusPins = val;
          _recalculateMapLayers();
        }),
      ),
      _buildFilterMenuItem(
        'Ferry Pier',
        Icons.directions_boat,
        Colors.teal,
        _showFerryPins,
        (val) => setState(() {
          _showFerryPins = val;
          _recalculateMapLayers();
        }),
      ),
      const Divider(),
      _buildFilterMenuItem(
        'Important Places',
        Icons.location_city,
        Colors.deepOrange,
        _showPinpoints,
        (val) => setState(() {
          _showPinpoints = val;
          _recalculateMapLayers();
        }),
      ),
      if (_showPinpoints) ...[
        for (final category in _pinpointCategoryToggles.keys)
          _buildFilterMenuItem(
            '  $category',
            _pinpointCategoryIcon(category),
            _pinpointCategoryColor(category),
            _pinpointCategoryToggles[category]!,
            (val) => setState(() {
              _pinpointCategoryToggles[category] = val;
              _recalculateMapLayers();
            }),
          ),
      ],
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
                  child: SingleChildScrollView(
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
                            setState(() {
                              _showTrainPins = val;
                              _recalculateMapLayers();
                            });
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
                            setState(() {
                              _showMetroPins = val;
                              _recalculateMapLayers();
                            });
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
                            setState(() {
                              _showBusPins = val;
                              _recalculateMapLayers();
                            });
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
                            setState(() {
                              _showFerryPins = val;
                              _recalculateMapLayers();
                            });
                            setSheetState(() {});
                          },
                          fullWidth: true,
                        ),
                        const Divider(),
                        _buildFilterMenuItem(
                          'Important Places',
                          Icons.location_city,
                          Colors.deepOrange,
                          _showPinpoints,
                          (val) {
                            setState(() {
                              _showPinpoints = val;
                              _recalculateMapLayers();
                            });
                            setSheetState(() {});
                          },
                          fullWidth: true,
                        ),
                        if (_showPinpoints) ...[
                          for (final category in _pinpointCategoryToggles.keys)
                            _buildFilterMenuItem(
                              '  $category',
                              _pinpointCategoryIcon(category),
                              _pinpointCategoryColor(category),
                              _pinpointCategoryToggles[category]!,
                              (val) {
                                setState(() {
                                  _pinpointCategoryToggles[category] = val;
                                  _recalculateMapLayers();
                                });
                                setSheetState(() {});
                              },
                              fullWidth: true,
                            ),
                        ],
                        ],
                      ),
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

  Widget _buildWideLayout(BuildContext context, Widget headerOverlay, Widget headerWidget) {
    final width = MediaQuery.of(context).size.width;

    // ensure the side panel is at least 320px wide so route options text does not overflow
    final panelWidth = math.max(340.0, math.min(400.0, width * 0.3));
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Map fills the entire background — RepaintBoundary lets the
        // compositor cache the map raster independently from UI overlays.
        Positioned.fill(
          child: RepaintBoundary(child: _buildMap(context)),
        ),

        // Map blur when search is active
        Positioned.fill(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              _collapsedSearchController,
              _startSearchController,
              _destSearchController,
              _collapsedSearchFocus,
              _startSearchFocus,
              _destSearchFocus,
            ]),
            builder: (context, _) {
              final isWide = MediaQuery.of(context).size.width > 600;
              if ((!isWide &&
                      _collapsedSearchController.isAttached &&
                      _collapsedSearchController.isOpen) ||
                  (!isWide &&
                      _startSearchController.isAttached &&
                      _startSearchController.isOpen) ||
                  (!isWide &&
                      _destSearchController.isAttached &&
                      _destSearchController.isOpen) ||
                  (isWide &&
                      (_collapsedSearchFocus.hasFocus ||
                          _collapsedSearchController.text.isNotEmpty ||
                          _startSearchFocus.hasFocus ||
                          (_startSearchController.text.isNotEmpty &&
                              selectedStartStopId == null &&
                              _customStartPoint == null) ||
                          _destSearchFocus.hasFocus ||
                          (_destSearchController.text.isNotEmpty &&
                              selectedDestinationStopId == null &&
                              _customDestPoint == null)))) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_collapsedSearchFocus.hasFocus) {
                        _collapsedSearchFocus.unfocus();
                      }
                      if (_collapsedSearchController.text.isNotEmpty) {
                        _collapsedSearchController.clear();
                      }
                      if (_startSearchFocus.hasFocus) {
                        _startSearchFocus.unfocus();
                      }
                      if (_startSearchController.text.isNotEmpty &&
                          selectedStartStopId == null &&
                          _customStartPoint == null) {
                        _startSearchController.clear();
                      }
                      if (_destSearchFocus.hasFocus) {
                        _destSearchFocus.unfocus();
                      }
                      if (_destSearchController.text.isNotEmpty &&
                          selectedDestinationStopId == null &&
                          _customDestPoint == null) {
                        _destSearchController.clear();
                      }
                    });
                  },
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.1),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),

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
              headerWidget, // <-- Replace _buildHomeHeader(context, true) with this

              // The floating options panel underneath
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _headerCollapsed,
                  builder: (context, isHeaderCollapsed, child) {
                    return ListenableBuilder(
                      listenable: Listenable.merge([
                        _collapsedSearchController,
                        _startSearchController,
                        _destSearchController,
                        _collapsedSearchFocus,
                        _startSearchFocus,
                        _destSearchFocus,
                      ]),
                      builder: (context, _) {
                        final isWideSearching =
                            isHeaderCollapsed &&
                            (_collapsedSearchFocus.hasFocus ||
                                _collapsedSearchController.text.isNotEmpty);
                        final isWideStartSearching =
                            !isHeaderCollapsed &&
                            (_startSearchFocus.hasFocus ||
                                (_startSearchController.text.isNotEmpty &&
                                    selectedStartStopId == null &&
                                    _customStartPoint == null));
                        final isWideDestSearching =
                            !isHeaderCollapsed &&
                            (_destSearchFocus.hasFocus ||
                                (_destSearchController.text.isNotEmpty &&
                                    selectedDestinationStopId == null &&
                                    _customDestPoint == null));
                        final isAnyWideSearching =
                            isWideSearching ||
                            isWideStartSearching ||
                            isWideDestSearching;

                        // If we have search results from the side panel, we want to show it. Wait, if viewingStop != null, the route planner obscures it. We switch between them.
                        final hasPanelContent =
                            directionOptions.isNotEmpty ||
                            _viewingStop != null ||
                            _viewingDroppedPin != null ||
                            _viewingPinpoint != null ||
                            isAnyWideSearching;
                        return AnimatedSwitcher(
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
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: hasPanelContent
                              ? Padding(
                                  key: ValueKey(
                                    'panel_content_${isAnyWideSearching ? "search" : "route"}',
                                  ),
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.15,
                                          ),
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
                                                theme.colorScheme.surface
                                                    .withValues(
                                                      alpha:
                                                          theme.brightness ==
                                                              Brightness.dark
                                                          ? 0.75
                                                          : 0.90,
                                                    ),
                                                theme.colorScheme.surface
                                                    .withValues(
                                                      alpha:
                                                          theme.brightness ==
                                                              Brightness.dark
                                                          ? 0.60
                                                          : 0.80,
                                                    ),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha:
                                                    theme.brightness ==
                                                        Brightness.dark
                                                    ? 0.2
                                                    : 0.5,
                                              ),
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: isAnyWideSearching
                                                ? (isWideSearching
                                                      ? _buildWideSearchResults(
                                                          context,
                                                        )
                                                      : _buildWideDirectionSearchResults(
                                                          context,
                                                        ))
                                                : ListView(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 24,
                                                          top: 12,
                                                        ),
                                                    children: [
                                                      _buildPanelContent(
                                                        context,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('no_content'),
                                ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneLayout(BuildContext context, Widget headerOverlay, Widget headerWidget) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: _headerCollapsed,
      builder: (context, isHeaderCollapsed, child) {
        return ListenableBuilder(
          listenable: Listenable.merge([
            _collapsedSearchController,
            _startSearchController,
            _destSearchController,
            _collapsedSearchFocus,
            _startSearchFocus,
            _destSearchFocus,
          ]),
          builder: (context, _) {
            final isSearching =
                isHeaderCollapsed &&
                (_collapsedSearchFocus.hasFocus ||
                    _collapsedSearchController.text.isNotEmpty);
            final isStartSearching =
                !isHeaderCollapsed &&
                (_startSearchFocus.hasFocus ||
                    (_startSearchController.text.isNotEmpty &&
                        selectedStartStopId == null &&
                        _customStartPoint == null));
            final isDestSearching =
                !isHeaderCollapsed &&
                (_destSearchFocus.hasFocus ||
                    (_destSearchController.text.isNotEmpty &&
                        selectedDestinationStopId == null &&
                        _customDestPoint == null));
            final isAnySearching =
                isSearching || isStartSearching || isDestSearching;

            final hasPanelContent =
                directionOptions.isNotEmpty ||
                _viewingStop != null ||
                _viewingDroppedPin != null ||
                _viewingPinpoint != null;
            // Dynamic initial sheet height when content exist
            final sheetInitialSize = hasPanelContent ? 0.45 : 0.0;

            return Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(child: _buildMap(context)),
                ),

                // Map blur when search is active
                if (isAnySearching)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_collapsedSearchFocus.hasFocus) {
                            _collapsedSearchFocus.unfocus();
                          }
                          if (_collapsedSearchController.text.isNotEmpty) {
                            _collapsedSearchController.clear();
                          }
                          if (_startSearchFocus.hasFocus) {
                            _startSearchFocus.unfocus();
                          }
                          if (_startSearchController.text.isNotEmpty &&
                              selectedStartStopId == null &&
                              _customStartPoint == null) {
                            _startSearchController.clear();
                          }
                          if (_destSearchFocus.hasFocus) {
                            _destSearchFocus.unfocus();
                          }
                          if (_destSearchController.text.isNotEmpty &&
                              selectedDestinationStopId == null &&
                              _customDestPoint == null) {
                            _destSearchController.clear();
                          }
                        });
                      },
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ),

                if (!isAnySearching)
                  headerOverlay
                else
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12.0,
                    left: 16.0,
                    right: 16.0,
                    bottom: 24.0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        headerWidget, // <-- Replace _buildHomeHeader(context, false) with this
                        Flexible(
                          child: Padding(
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
                                              theme.brightness ==
                                                  Brightness.dark
                                              ? 0.2
                                              : 0.5,
                                        ),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: isSearching
                                          ? _buildWideSearchResults(context)
                                          : _buildWideDirectionSearchResults(
                                              context,
                                            ),
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

                // Drag sheet spanning full height but starting at initialSize
                if (hasPanelContent)
                  DraggableScrollableSheet(
                    initialChildSize: sheetInitialSize,
                    minChildSize: 0.25,
                    maxChildSize: 0.95,
                    builder: (context, controller) {
                      final bottomPadding = MediaQuery.of(
                        context,
                      ).padding.bottom;
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
                                  padding: EdgeInsets.only(
                                    bottom: bottomPadding + 24,
                                  ),
                                  children: [
                                    const SizedBox(height: 12),
                                    Center(
                                      child: Container(
                                        width: 48,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(
                                            2.5,
                                          ),
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
          },
        );
      },
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

  Widget _buildHeaderOverlay(BuildContext context, bool isWideLayout, Widget headerWidget) {
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
          child: headerWidget, // <-- Use headerWidget here
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
    final int serviceType = _getServicePriority(stop);
    final lineName = _getLineName(stop.stopId) ?? '';

    IconData getIconForType(int type) {
      switch (type) {
        case 1:
          return Icons.subway;
        case 2:
          return Icons.train;
        case 3:
          return Icons.directions_bus;
        case 4:
          return Icons.directions_boat;
        default:
          return Icons.directions_transit;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: 0.9),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      bool isBusNotBRT = serviceType == 3 &&
                          !(stop.stopId.startsWith('BRT') || lineName.toUpperCase().contains('BRT'));
                      String? routeIcon;
                      if (serviceType == 1 || lineName.toUpperCase() == 'BRT') {
                        routeIcon = _getRouteIcon(lineName);
                      }
                      if (routeIcon != null && routeIcon.isNotEmpty) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? Colors.white
                                    : lineColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: SvgPicture.asset(
                                routeIcon,
                                width: 24,
                                height: 24,
                              ),
                            ),
                            if (!isBusNotBRT && stop.code != null && stop.code!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: lineColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  stop.code!,
                                  style: TextStyle(
                                    color: (lineColor.computeLuminance() > 0.5)
                                        ? Colors.black87
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: lineColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              getIconForType(serviceType),
                              color: (lineColor.computeLuminance() > 0.5)
                                  ? Colors.black87
                                  : Colors.white,
                              size: 16,
                            ),
                            if (!isBusNotBRT && stop.code != null && stop.code!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                stop.code!,
                                style: TextStyle(
                                  color: (lineColor.computeLuminance() > 0.5)
                                      ? Colors.black87
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (stop.thaiName != null &&
                            stop.thaiName!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            stop.thaiName!,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  theme.textTheme.bodySmall?.color ??
                                  Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<gtfs.Pinpoint> _filterPinpoints(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty || pinpoints.isEmpty) return const [];
    return pinpoints
        .where((pp) {
          final name = pp.name.toLowerCase();
          final nameEn = (pp.nameEn ?? '').toLowerCase();
          final type = pp.placeType.toLowerCase();
          return name.contains(trimmed) ||
              nameEn.contains(trimmed) ||
              type.contains(trimmed);
        })
        .take(10)
        .toList();
  }

  Widget _buildPinpointSuggestionTile(gtfs.Pinpoint pp, VoidCallback onTap) {
    final theme = Theme.of(context);
    final color = _pinpointColor(pp.placeType);
    final icon = _pinpointIcon(pp.placeType);
    final category = _pinpointCategory(pp.placeType);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: 0.9),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pp.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (pp.nameEn != null && pp.nameEn!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            pp.nameEn!,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideDirectionSearchResults(BuildContext context) {
    var isStart = true;
    if (_destSearchFocus.hasFocus) {
      isStart = false;
    } else if (_startSearchFocus.hasFocus) {
      isStart = true;
    } else if (_startSearchController.text.isNotEmpty &&
        selectedStartStopId == null &&
        _customStartPoint == null) {
      isStart = true;
    } else if (_destSearchController.text.isNotEmpty &&
        selectedDestinationStopId == null &&
        _customDestPoint == null) {
      isStart = false;
    }

    final ctrl = isStart ? _startSearchController : _destSearchController;
    final text = ctrl.text;

    closeAndSelect(stop) {
      if (isStart) _startSearchFocus.unfocus();
      if (!isStart) _destSearchFocus.unfocus();
      _selectStopFromSearch(stop, asStart: isStart);
    }

    if (text.isEmpty) {
      return ServiceTabs(
        allStops: allStops,
        busStops: busStops,
        linePrefixes: linePrefixes,
        lineColors: lineColors,
        getLineName: _getLineName,
        getLineNames: _getLineNames,
        getServicePriority: _getServicePriority,
        routeIconByName: _getRouteIcon,
        onSelect: closeAndSelect,
      );
    }

    final results = _filterStops(text);
    final ppResults = _filterPinpoints(text);
    if (results.isEmpty && ppResults.isEmpty) {
      return ListView(
        shrinkWrap: true,
        children: const [
          ListTile(
            leading: Icon(Icons.search_off),
            title: Text('No stations found'),
          ),
        ],
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        ...results
            .map(
              (stop) =>
                  _buildSearchSuggestionTile(stop, () => closeAndSelect(stop)),
            ),
        if (ppResults.isNotEmpty) ...[
          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 4, 16, 4),
            child: Text(
              'Important Places',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...ppResults
              .map(
                (pp) => _buildPinpointSuggestionTile(pp, () {
                  if (isStart) _startSearchFocus.unfocus();
                  if (!isStart) _destSearchFocus.unfocus();
                  setState(() {
                    _viewingPinpoint = pp;
                    _viewingStop = null;
                    _viewingDroppedPin = null;
                    _viewingDetailsOption = null;
                  });
                  final zoom = math.max(_mapController.camera.zoom, 14).toDouble();
                  _mapController.move(LatLng(pp.lat, pp.lon), zoom);
                }),
              ),
        ],
      ],
    );
  }

  Widget _buildWideSearchResults(BuildContext context) {
    final text = _collapsedSearchController.text;
    if (text.isEmpty) {
      return ServiceTabs(
        allStops: allStops,
        busStops: busStops,
        linePrefixes: linePrefixes,
        lineColors: lineColors,
        getLineName: _getLineName,
        getLineNames: _getLineNames,
        getServicePriority: _getServicePriority,
        routeIconByName: _getRouteIcon,
        onSelect: (stop) {
          _collapsedSearchFocus.unfocus();
          _handleCollapsedStopSelection(stop);
        },
      );
    }

    final results = _filterStops(text);
    final ppResults = _filterPinpoints(text);
    if (results.isEmpty && ppResults.isEmpty) {
      return ListView(
        shrinkWrap: true,
        children: const [
          ListTile(
            leading: Icon(Icons.search_off),
            title: Text('No stations found'),
          ),
        ],
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        ...results
            .map(
              (stop) => _buildSearchSuggestionTile(stop, () {
                _collapsedSearchFocus.unfocus();
                _handleCollapsedStopSelection(stop);
              }),
            ),
        if (ppResults.isNotEmpty) ...[
          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 4, 16, 4),
            child: Text(
              'Important Places',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...ppResults
              .map(
                (pp) => _buildPinpointSuggestionTile(pp, () {
                  _collapsedSearchFocus.unfocus();
                  _collapsedSearchController.clear();
                  setState(() {
                    _viewingPinpoint = pp;
                    _viewingStop = null;
                    _viewingDroppedPin = null;
                    _viewingDetailsOption = null;
                  });
                  final zoom = math.max(_mapController.camera.zoom, 14).toDouble();
                  _mapController.move(LatLng(pp.lat, pp.lon), zoom);
                }),
              ),
        ],
      ],
    );
  }

  Widget _buildCollapsedSearchBar(BuildContext context) {
    final theme = Theme.of(context);

    final searchBar = SearchBar(
      controller: _collapsedSearchController,
      focusNode: _collapsedSearchFocus,

      onTap: () {
        if (!_collapsedSearchFocus.hasFocus) {
          _collapsedSearchFocus.requestFocus();
        }
      },

      constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
      leading: ListenableBuilder(
        listenable: Listenable.merge([
          _collapsedSearchController,
          _collapsedSearchFocus,
        ]),
        builder: (context, _) {
          final isActive =
              _collapsedSearchController.text.isNotEmpty ||
              _collapsedSearchFocus.hasFocus;

          if (isActive) {
            return IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _collapsedSearchController.clear();
                  _collapsedSearchFocus.unfocus();
                });
              },
            );
          }
          return Icon(Icons.search, color: theme.colorScheme.primary);
        },
      ),
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
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
      ),
      onChanged: (value) {
        // UI updates handled by ListenableBuilder now
      },
      trailing: [
        ListenableBuilder(
          listenable: _collapsedSearchController,
          builder: (context, _) {
            if (_collapsedSearchController.text.isNotEmpty) {
              return IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Clear search',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  _collapsedSearchController.clear();
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    return Row(
      children: [
        Expanded(child: searchBar),
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
    setState(() {
      _viewingStop = stop;
      _viewingDetailsOption = null;
      _collapsedSearchController.clear();
      _collapsedSearchFocus.unfocus();
      _recalculateMapLayers();
    });

    final zoom = math.max(_mapController.camera.zoom, 14).toDouble();
    _mapController.move(LatLng(stop.lat, stop.lon), zoom);
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
                onPressed: _isLoadingRoute ? null : () => _findDirection(),
                icon: _isLoadingRoute
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.route),
                label: Text(
                  _isLoadingRoute ? 'Finding Routes...' : 'Find Routes',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
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
    final focusNode = asStart ? _startSearchFocus : _destSearchFocus;

    final trailingWidgets = <Widget>[
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.text.isNotEmpty) {
            return IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Clear $label',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() {
                  controller.clear();
                  if (asStart) {
                    selectedStartStopId = null;
                    _customStartPoint = null;
                  } else {
                    selectedDestinationStopId = null;
                    _customDestPoint = null;
                  }
                  directionOptions = [];
                  selectedDirectionIndex = 0;
                  _recalculateMapLayers();
                });
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
      if (trailingAction != null) trailingAction,
    ];

    final searchBar = SearchBar(
      controller: controller,
      focusNode: focusNode,

      onTap: () {
        if (!focusNode.hasFocus) {
          focusNode.requestFocus();
        }
      },

      constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
      leading: ListenableBuilder(
        listenable: Listenable.merge([controller, focusNode]),
        builder: (context, _) {
          final isSelected = asStart
              ? (selectedStartStopId != null || _customStartPoint != null)
              : (selectedDestinationStopId != null || _customDestPoint != null);
          final isActive =
              focusNode.hasFocus || (controller.text.isNotEmpty && !isSelected);

          if (isActive) {
            return IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  focusNode.unfocus();
                  if (isSelected) {
                    if (asStart) {
                      if (selectedStartStopId != null) {
                        for (final s in allStops) {
                          if (s.stopId == selectedStartStopId) {
                            controller.text = s.name;
                            break;
                          }
                        }
                      } else if (_customStartPoint != null) {
                        controller.text = 'Dropped Pin';
                      }
                    } else {
                      if (selectedDestinationStopId != null) {
                        for (final s in allStops) {
                          if (s.stopId == selectedDestinationStopId) {
                            controller.text = s.name;
                            break;
                          }
                        }
                      } else if (_customDestPoint != null) {
                        controller.text = 'Dropped Pin';
                      }
                    }
                  } else {
                    controller.clear();
                  }
                });
              },
            );
          }
          return Icon(
            icon,
            size: 20,
            color: iconColor ?? theme.colorScheme.primary,
          );
        },
      ),
      hintText: 'Search $label',
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
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
      ),
      onChanged: (value) {
        // UI updates handled by ListenableBuilder now
      },
      trailing: trailingWidgets,
    );

    return SizedBox(height: 48, child: searchBar);
  }

  bool _isStopMetro(gtfs.Stop stop) {
    if (_isMetroCache.containsKey(stop.stopId)) {
      return _isMetroCache[stop.stopId]!;
    }
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
          _isMetroCache[stop.stopId] = true;
          return true;
        }
      }
    }
    _isMetroCache[stop.stopId] = false;
    return false;
  }

  bool _isStopTrain(gtfs.Stop stop) {
    if (_isTrainCache.containsKey(stop.stopId)) {
      return _isTrainCache[stop.stopId]!;
    }
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
          _isTrainCache[stop.stopId] = true;
          return true;
        }
      }
    }
    _isTrainCache[stop.stopId] = false;
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

  Set<String>? _busStopIdSetCache;
  int _getServicePriority(gtfs.Stop stop) {
    if (stop.stopId.startsWith('F')) return 4;

    _busStopIdSetCache ??= busStops.map((s) => s.stopId).toSet();
    if (_busStopIdSetCache!.contains(stop.stopId)) return 3;

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
    _routeHitNotifier.addListener(() {
      final val = _routeHitNotifier.value;
      if (val != null && val.hitValues.isNotEmpty) {
        if (val.hitValues.first < directionOptions.length) {
          _selectRouteOption(val.hitValues.first);
        }
      }
    });
    _loadProfile();
    _startSearchController = SearchController();
    _startSearchFocus = FocusNode();
    _destSearchController = SearchController();
    _destSearchFocus = FocusNode();
    _collapsedSearchController = SearchController();
    _collapsedSearchFocus = FocusNode();
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
      if (!mounted) return;
      // Throttle: only trigger a rebuild when the device has moved >~20 m
      // (avoids 1-Hz full-widget-tree rebuilds while standing still).
      final prev = _userLocation;
      if (prev != null &&
          currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        final dlat = (currentLocation.latitude! - (prev.latitude ?? 0)).abs();
        final dlon = (currentLocation.longitude! - (prev.longitude ?? 0)).abs();
        if (dlat < 0.0002 && dlon < 0.0002) {
          // Position hasn't changed meaningfully — update silently without rebuild
          _userLocation = currentLocation;
          return;
        }
      }
      setState(() {
        _userLocation = currentLocation;
      });
    });
  }

  @override
  void dispose() {
    _routeHitNotifier.dispose();
    _headerCollapsed.dispose();
    _startSearchController.dispose();
    _startSearchFocus.dispose();
    _destSearchController.dispose();
    _destSearchFocus.dispose();
    _collapsedSearchController.dispose();
    _collapsedSearchFocus.dispose();
    _collapsedSearchFocus.dispose();
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRoutesAndStops() async {
    // Parallelise all independent asset loads — total time = slowest file
    // instead of the sum of all files.
    final results = await Future.wait([
      _parseRoutesFromAsset('assets/gtfs_data/routes.txt'),          // 0
      RouteAssetLoader.loadRoutes('assets/gtfs_data/bus_route.txt'), // 1
      RouteAssetLoader.loadRoutes('assets/gtfs_data/ferry_route.txt'),// 2
      _loadThaiStopNames(),                                          // 3
    ]);

    final routes = [
      ...(results[0] as List<gtfs.Route>),
      ...(results[1] as List<gtfs.Route>),
      ...(results[2] as List<gtfs.Route>),
    ];
    final thaiNames = results[3] as Map<String, String>;

    // Second parallel batch — depends on routes/thaiNames from above
    final results2 = await Future.wait([
      _parseStopsFromAsset('assets/gtfs_data/stops.txt', thaiNames: thaiNames), // 0
      RouteAssetLoader.loadStops('assets/gtfs_data/ferry_stop.txt', thaiNames: thaiNames), // 1
      _parseBusStopsFromAsset('assets/gtfs_data/bus_stop.txt'),     // 2
      _parsePinpointsFromAsset('assets/gtfs_data/pinpoint.txt'),    // 3
      _loadFareMappings(),                                           // 4
    ]);

    final stops        = results2[0] as List<gtfs.Stop>;
    final ferryStops   = results2[1] as List<gtfs.Stop>;
    final busStopList  = results2[2] as List<gtfs.Stop>;
    final pinpointList = results2[3] as List<gtfs.Pinpoint>;
    // _loadFareMappings populates instance fields directly (result[4] is void)
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
    colorMap['BRT'] = Colors.yellow.shade700; // More readable than raw FFFF00
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
      // Calculate initial camera bounds based only on rail/BRT to avoid zooming out too far
      final initialPts = <LatLng>[];
      if (!_didFitRails) {
        for (final seg in mutableShapes) {
          initialPts.addAll(seg.points);
        }
      }

      // Load heavy shapes directly here to keep the loading screen active until everything is done
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
        mutableShapes.addAll(heavyShapes);
      } catch (_) {}

      shapes = mutableShapes;

      if (initialPts.isNotEmpty) {
        _initialCameraPts = initialPts;
      }
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
      _busStopIdSetCache = null; // Clear cache on update
      this.ferryStops = ferryStops;
      pinpoints = pinpointList;
      linePrefixes = prefixMap;
      lineColors = colorMap;
      stopLookup = stopMap;
      shapeSegments = shapes;
      _recalculateMapLayers();
      _isGtfsDataLoaded = true;
    });

    // Fit camera once on initial load based on the limited shapes we calculated earlier
    if (!_didFitRails && _initialCameraPts.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(_initialCameraPts);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(24)),
          );
        }
      });
      _didFitRails = true;
    }

    if (!_hasShownWelcome) {
      _hasShownWelcome = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showWelcomeDialog();
        }
      });
    }
  }

  void _showWelcomeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Welcome / ยินดีต้อนรับ'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'TransitRoute is an independent prototype developed as part of a senior project by students at King Mongkut\'s University of Technology Thonburi (KMUTT). This app does not represent, nor is it affiliated with, endorsed by, or officially connected to the Thai government, or any government agency.\n\n'
                  'The data in this app covers only the Bangkok metropolitan area and may contain inaccuracies or incomplete information. For example, travel time and fare data are partially estimated and may be outdated. Users should verify with official staff for the most accurate information.\n\n'
                  '---\n\n'
                  'TransitRoute เป็นเพียงต้นแบบที่พัฒนาขึ้นเพื่อเป็นส่วนหนึ่งของโครงงานก่อนจบการศึกษาของนักศึกษามหาวิทยาลัยเทคโนโลยีพระจอมเกล้าธนบุรี (KMUTT) แอปนี้ไม่ได้เป็นตัวแทน และไม่มีความเกี่ยวข้อง ไม่ได้รับการรับรอง หรือมีความเชื่อมโยงอย่างเป็นทางการกับรัฐบาลไทยหรือหน่วยงานรัฐบาล\n\n'
                  'ข้อมูลในแอปนี้ครอบคลุมเฉพาะพื้นที่กรุงเทพมหานครเท่านั้น และอาจมีความคลาดเคลื่อนหรือไม่สมบูรณ์ของข้อมูล อาทิ ข้อมูลเวลาเดินทางและค่าโดยสารมีการใช้ประมาณเป็นบางส่วนอาจมีความคลาดเคลื่อนและไม่เป็นปัจจุบัน ผู้ใช้ควรสอบถามกับเจ้าหน้าที่อีกครั้งเพื่อความถูกต้องของข้อมูล',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Acknowledge / รับทราบ'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // _loadStops is now replaced by _loadRoutesAndStops

  Future<List<gtfs.Stop>> _parseStopsFromAsset(
    String assetPath, {
    Map<String, String>? thaiNames,
  }) async {
    try {
      final content = await gtfsSyncService.getGtfsFile(assetPath);
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
      final content = await gtfsSyncService.getGtfsFile(assetPath);
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return [];
      final header = _parseCsvLine(lines.first).map((s) => s.trim()).toList();
      int idxStopId = header.indexOf('stop_id');
      if (idxStopId < 0) idxStopId = 0;
      int idxName = header.indexOf('stop_name');
      if (idxName < 0) idxName = 1;
      int idxThai = header.indexOf('stop_name_th');
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

        String? thaiName;
        if (idxThai >= 0 && row.length > idxThai) {
          final th = row[idxThai].trim();
          if (th.isNotEmpty) thaiName = th;
        }

        stops.add(
          gtfs.Stop(
            stopId: stopId,
            name: name,
            thaiName: thaiName,
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

  Future<List<gtfs.Pinpoint>> _parsePinpointsFromAsset(String assetPath) async {
    try {
      final content = await gtfsSyncService.getGtfsFile(assetPath);
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return [];
      final header = _parseCsvLine(lines.first).map((s) => s.trim()).toList();
      int idxId = header.indexOf('stop_id');
      if (idxId < 0) idxId = 0;
      int idxName = header.indexOf('stop_name');
      if (idxName < 0) idxName = 1;
      int idxNameEn = header.indexOf('stop_name_en');
      if (idxNameEn < 0) idxNameEn = 2;
      int idxLat = header.indexOf('stop_lat');
      if (idxLat < 0) idxLat = 3;
      int idxLon = header.indexOf('stop_lon');
      if (idxLon < 0) idxLon = 4;
      int idxDesc = header.indexOf('stop_desc');
      if (idxDesc < 0) idxDesc = 5;
      final result = <gtfs.Pinpoint>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = _parseCsvLine(line);
        if (row.length <= idxLat || row.length <= idxLon) continue;
        final id = row[idxId].trim();
        final name = row[idxName].trim();
        final nameEn = (row.length > idxNameEn) ? row[idxNameEn].trim() : null;
        final lat = double.tryParse(row[idxLat].trim());
        final lon = double.tryParse(row[idxLon].trim());
        final desc = (row.length > idxDesc) ? row[idxDesc].trim() : '';
        if (name.isEmpty || lat == null || lon == null) continue;
        result.add(
          gtfs.Pinpoint(
            id: id.isEmpty ? 'PP_$i' : id,
            name: name,
            nameEn: (nameEn != null && nameEn.isNotEmpty) ? nameEn : null,
            lat: lat,
            lon: lon,
            placeType: desc.isNotEmpty ? desc : 'other',
          ),
        );
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, String>> _loadThaiStopNames() async {
    try {
      final content = await gtfsSyncService.getGtfsFile(
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
      final content = await gtfsSyncService.getGtfsFile(
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
      final content = await gtfsSyncService.getGtfsFile(
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
      final content = await gtfsSyncService.getGtfsFile(
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
      final content = await gtfsSyncService.getGtfsFile(
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
      final tripContent = await gtfsSyncService.getGtfsFile(
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
        final stContent = await gtfsSyncService.getGtfsFile(file);
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
      final content = await gtfsSyncService.getGtfsFile(
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

  // Returns true if lat/lon is within the camera's visible bounds expanded by
  // [bufferFactor] times the visible span in each direction.
  bool _isInViewport(double lat, double lon, {double bufferFactor = 0.5}) {
    final camera = _mapController.camera;
    final bounds = camera.visibleBounds;
    final latSpan = (bounds.north - bounds.south).abs();
    final lonSpan = (bounds.east - bounds.west).abs();
    return lat >= bounds.south - latSpan * bufferFactor &&
        lat <= bounds.north + latSpan * bufferFactor &&
        lon >= bounds.west - lonSpan * bufferFactor &&
        lon <= bounds.east + lonSpan * bufferFactor;
  }

  void _recalculateMapLayers() {
    _routeStopIds = <String>{};
    for (final seg in activeRouteSegments) {
      if (seg.intermediateStops != null) {
        _routeStopIds.addAll(seg.intermediateStops!.map((s) => s.stopId));
      }
      if (seg.start.stopId != null) _routeStopIds.add(seg.start.stopId!);
      if (seg.end.stopId != null) _routeStopIds.add(seg.end.stopId!);
    }

    _cachedShapePolylines = shapeSegments
        .where((s) {
          final isTrain = _isShapeTrain(s);
          final isMetro = _isShapeMetro(s);
          if (isTrain && !_showTrainPins) return false;
          if (isMetro && !_showMetroPins) return false;
          if (!isTrain && !isMetro) return false;
          return true;
        })
        .expand<Polyline<int>>((s) {
          final isTrain = _isShapeTrain(s);

          if (activeRouteSegments.isNotEmpty) {
            return [];
          }

          if (isTrain) {
            return [
              Polyline<int>(
                points: s.points,
                color: const Color(0xFF6B4226),
                strokeWidth: 7.0,
              ),
              Polyline<int>(
                points: s.points,
                color: Colors.white,
                strokeWidth: 4.0,
                pattern: StrokePattern.dashed(segments: [10.0, 10.0]),
              ),
            ];
          }

          return [
            Polyline<int>(points: s.points, color: s.color, strokeWidth: 6.0),
          ];
        })
        .toList();

    _cachedBusMarkers = busStops
        .where((stop) {
          if (activeRouteSegments.isNotEmpty &&
              !_routeStopIds.contains(stop.stopId)) {
            return false;
          }
          // Viewport culling — only render markers near the visible area
          if (!_isInViewport(stop.lat, stop.lon)) return false;
          return true;
        })
        .map((stop) {
          final isFav = _favoritePins.any(
            (p) =>
                p.point.latitude == stop.lat && p.point.longitude == stop.lon,
          );
          return Marker(
            point: LatLng(stop.lat, stop.lon),
            width: isFav ? 20 : 18,
            height: isFav ? 24 : 22,
            child: GestureDetector(
              onTap: () => _showStopDetails(context, stop),
              child: Tooltip(
                message: stop.name,
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        (activeRouteSegments.isNotEmpty &&
                            !_routeStopIds.contains(stop.stopId))
                        ? Colors.grey.shade400
                        : const Color.fromARGB(255, 38, 62, 199),
                    border: Border.all(
                      color: isFav
                          ? Colors.red
                          : (activeRouteSegments.isNotEmpty &&
                                !_routeStopIds.contains(stop.stopId))
                          ? Colors.grey.shade600
                          : Colors.black.withValues(alpha: 0.18),
                      width: isFav ? 2 : 1,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                      bottomLeft: Radius.circular(2),
                    ),
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
            ),
          );
        })
        .toList();

    _cachedFerryMarkers = ferryStops
        .where((stop) {
          if (activeRouteSegments.isNotEmpty &&
              !_routeStopIds.contains(stop.stopId)) {
            return false;
          }
          if (!_isInViewport(stop.lat, stop.lon)) return false;
          return true;
        })
        .map((stop) {
          final isFav = _favoritePins.any(
            (p) =>
                p.point.latitude == stop.lat && p.point.longitude == stop.lon,
          );
          return Marker(
            point: LatLng(stop.lat, stop.lon),
            width: isFav ? 24 : 20,
            height: isFav ? 24 : 20,
            child: GestureDetector(
              onTap: () => _showStopDetails(context, stop),
              child: Tooltip(
                message: stop.name,
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        (activeRouteSegments.isNotEmpty &&
                            !_routeStopIds.contains(stop.stopId))
                        ? Colors.grey.shade400
                        : const Color.fromARGB(255, 0, 150, 136),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isFav
                          ? Colors.red
                          : (activeRouteSegments.isNotEmpty &&
                                !_routeStopIds.contains(stop.stopId))
                          ? Colors.grey.shade600
                          : Colors.black.withValues(alpha: 0.2),
                      width: isFav ? 2.5 : 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_boat,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
            ),
          );
        })
        .toList();

    _cachedPinpointMarkers = pinpoints
        .where((pp) {
          if (activeRouteSegments.isNotEmpty) return false;
          final cat = _pinpointCategory(pp.placeType);
          if (!(_pinpointCategoryToggles[cat] ?? true)) return false;
          if (!_isInViewport(pp.lat, pp.lon)) return false;
          return true;
        })
        .map((pp) {
          final color = _pinpointColor(pp.placeType);
          final icon = _pinpointIcon(pp.placeType);
          return Marker(
            point: LatLng(pp.lat, pp.lon),
            width: 22,
            height: 22,
            child: GestureDetector(
              onTap: () => _showPinpointDetails(context, pp),
              child: Tooltip(
                message: pp.nameEn ?? pp.name,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 12),
                ),
              ),
            ),
          );
        })
        .toList();

    _cachedInactiveDirectionPolylines.clear();
    if (directionOptions.isNotEmpty) {
      for (int i = 0; i < directionOptions.length; i++) {
        if (i != selectedDirectionIndex) {
          _cachedInactiveDirectionPolylines[i] = _buildRoutePolylines(
            directionOptions[i].segments,
            hitValue: i,
            isActive: false,
          );
        }
      }
    }

    _cachedActiveDirectionPolylines = [];
    if (directionOptions.isNotEmpty &&
        selectedDirectionIndex < directionOptions.length) {
      _cachedActiveDirectionPolylines = _buildRoutePolylines(
        directionOptions[selectedDirectionIndex].segments,
        hitValue: selectedDirectionIndex,
        isActive: true,
      );
    }

    // Cache non-transit favourite pin markers. Use a coordinate Set for O(1)
    // lookup instead of allStops.any() on every build frame.
    final stopCoordSet = <String>{};
    for (final s in allStops) {
      stopCoordSet.add('${s.lat},${s.lon}');
    }
    _cachedFavoritePinMarkers = _favoritePins
        .where((pin) {
          final key = '${pin.point.latitude},${pin.point.longitude}';
          return !stopCoordSet.contains(key);
        })
        .map((pin) {
          return Marker(
            point: pin.point,
            width: 24,
            height: 24,
            child: GestureDetector(
              onTap: () => _showDroppedPinDetails(context, pin.point),
              child: Tooltip(
                message: 'Favorite Pin',
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.redAccent,
                    size: 14,
                  ),
                ),
              ),
            ),
          );
        })
        .toList();
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
    setState(() {
      _selectedNavIndex = 1;
    });
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

  void _openNavigation(DirectionOption option, {bool isNavigation = true}) {
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
        loadReports: () async => TransitUpdateService().fetchAndSyncReports(),
        allStops: allStops,
        stopToLinesMap: _stopToLinesMap,
      );
    } else {
      body = MorePage(
        onOpenTransportLines: _openTransportLines,
        onOpenTransitUpdates: _openTransitUpdatePage,
        onOpenGraphicMap: _openGraphicMap,
        onOpenCards: _openCardsPage,
        allStops: allStops,
        routeIconByName: _getRouteIcon,
        lineColorByName: _getPolylineColor,
        stopToLinesMap: _stopToLinesMap,
        onSelectFavoritePin: (lat, lon) {
          setState(() => _selectedNavIndex = 0);
          final point = LatLng(lat, lon);
          _mapController.move(point, 15);

          // Check if this saved location is actually an important place (pinpoint)
          gtfs.Pinpoint? matchedPinpoint;
          try {
            matchedPinpoint = pinpoints.firstWhere(
              (pp) => pp.lat == lat && pp.lon == lon,
            );
          } catch (_) {}

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (matchedPinpoint != null) {
              _showPinpointDetails(context, matchedPinpoint);
            } else {
              _showDroppedPinDetails(context, point);
            }
          });
        },
        profile: _profile,
        onProfileUpdated: _saveProfile,
        currentAccentColor: widget.currentAccentColor,
        onAccentColorChanged: widget.onAccentColorChanged,
        currentThemeMode: widget.currentThemeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      );
    }

    final bodyContent = SafeArea(
      top: false,
      bottom: false, // map and other pages handle bottom insets natively
      child: body,
    );

    return PopScope(
      canPop:
          directionOptions.isEmpty &&
          _viewingStop == null &&
          _viewingDroppedPin == null &&
          _viewingPinpoint == null &&
          !_collapsedSearchFocus.hasFocus &&
          !_startSearchFocus.hasFocus &&
          !_destSearchFocus.hasFocus &&
          _collapsedSearchController.text.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          if (_collapsedSearchFocus.hasFocus ||
              _startSearchFocus.hasFocus ||
              _destSearchFocus.hasFocus) {
            _collapsedSearchFocus.unfocus();
            _startSearchFocus.unfocus();
            _destSearchFocus.unfocus();
          } else if (_collapsedSearchController.text.isNotEmpty) {
            _collapsedSearchController.clear();
          } else if (_viewingPinpoint != null) {
            _viewingPinpoint = null;
          } else if (_viewingStop != null) {
            _viewingStop = null;
          } else if (_viewingDroppedPin != null) {
            _viewingDroppedPin = null;
          } else if (directionOptions.isNotEmpty ||
              _startSearchController.text.isNotEmpty ||
              _destSearchController.text.isNotEmpty) {
            _startSearchController.clear();
            _destSearchController.clear();
            selectedStartStopId = null;
            selectedDestinationStopId = null;
            _customStartPoint = null;
            _customDestPoint = null;
            directionOptions.clear();
            selectedDirectionIndex = 0;
            _headerCollapsed.value = false;
            _recalculateMapLayers();
          }
        });
      },
      child: Stack(
        children: [
          Scaffold(
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
          ),
          if (!_isGtfsDataLoaded)
            Material(
              color: theme.colorScheme.surface,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: widget.currentAccentColor),
                    const SizedBox(height: 24),
                    Text(
                      'Loading Transit Data...',
                      style: GoogleFonts.googleSans(
                        textStyle: TextStyle(
                          color: widget.currentAccentColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context, bool isWideLayout) {
    // 1. Wrap the header with the GlobalKey
    final headerWidget = KeyedSubtree(
      key: _headerGlobalKey,
      child: _buildHomeHeader(context, isWideLayout),
    );
    
    // 2. Pass the persistent headerWidget down
    final headerOverlay = _buildHeaderOverlay(context, isWideLayout, headerWidget);
    
    return SizedBox.expand(
      child: isWideLayout
          ? _buildWideLayout(context, headerOverlay, headerWidget)
          : _buildPhoneLayout(context, headerOverlay, headerWidget),
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
