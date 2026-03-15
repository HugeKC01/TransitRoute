import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:route/services/direction_service.dart';
import 'package:route/services/geo_utils.dart' as geo;
import 'package:route/services/gtfs_models.dart' as gtfs;
import 'package:route/widgets/widget_types.dart';

class NavigationPage extends StatefulWidget {
  const NavigationPage({
    super.key,
    required this.option,
    required this.lineNameResolver,
    required this.lineColorResolver,
    required this.lineColors,
  });

  final DirectionOption option;
  final LineNameResolver lineNameResolver;
  final LineColorResolver lineColorResolver;
  final Map<String, Color> lineColors;

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  int _currentIndex = 0;
  bool _isExpanded = false;
  bool _followUser = true;
  bool _tracking = false;
  String? _locationError;
  LocationData? _lastLocation;
  StreamSubscription<LocationData>? _locationSub;

  List<gtfs.Stop> get _stops => widget.option.allStops;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetChanged);
    _startLocationTracking();
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();
    _locationSub?.cancel();
    super.dispose();
  }

  void _onSheetChanged() {
    final expanded = _sheetController.size > 0.35;
    if (expanded != _isExpanded && mounted) {
      setState(() => _isExpanded = expanded);
    }
  }

  Future<void> _startLocationTracking() async {
    final location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
    }
    if (!serviceEnabled) {
      setState(() => _locationError = 'Location service is off');
      return;
    }
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
    }
    if (permissionGranted != PermissionStatus.granted &&
        permissionGranted != PermissionStatus.grantedLimited) {
      setState(() => _locationError = 'Location permission not granted');
      return;
    }
    _tracking = true;
    _locationSub = location.onLocationChanged.listen(_handleLocationUpdate);
  }

  void _handleLocationUpdate(LocationData data) {
    if (!_tracking || _stops.isEmpty) return;
    if (data.latitude == null || data.longitude == null) return;
    final lat = data.latitude!;
    final lon = data.longitude!;
    setState(() => _lastLocation = data);

    const double arrivalThresholdMeters = 120.0;
    const double snapThresholdMeters = 220.0;
    final nearest = _nearestUpcomingStop(lat, lon);
    if (nearest != null && nearest.index > _currentIndex) {
      if (nearest.distance <= arrivalThresholdMeters) {
        _setCurrentIndex(nearest.index, moveCamera: false);
      } else if (nearest.distance <= snapThresholdMeters &&
          nearest.index <= _currentIndex + 3) {
        _setCurrentIndex(nearest.index, moveCamera: false);
      }
    }

    if (_followUser) {
      _mapController.move(LatLng(lat, lon), _mapController.camera.zoom);
    }
  }

  ({int index, double distance})? _nearestUpcomingStop(double lat, double lon) {
    if (_stops.isEmpty) return null;
    double? bestDistance;
    int? bestIndex;
    for (int i = _currentIndex; i < _stops.length; i++) {
      final d = _distanceToStop(_stops[i], lat, lon);
      if (bestDistance == null || d < bestDistance) {
        bestDistance = d;
        bestIndex = i;
      }
    }
    if (bestDistance == null || bestIndex == null) return null;
    return (index: bestIndex, distance: bestDistance);
  }

  int _stopsLeftOnCurrentLine() {
    if (_stops.isEmpty) return 0;
    final line = _currentLineName;
    int count = 0;
    for (int i = _currentIndex; i < _stops.length; i++) {
      if (widget.lineNameResolver(_stops[i].stopId) == line) {
        count++;
      } else {
        break;
      }
    }
    return math.max(count - 1, 0);
  }

  int _remainingMinutes() {
    if (_stops.isEmpty) return 0;
    final remainingStops = _stops.length - (_currentIndex + 1);
    final perStop = widget.option.minutes / _stops.length;
    return math.max(1, (perStop * remainingStops).ceil());
  }

  String get _currentLineName {
    if (_stops.isEmpty) return 'Line';
    return widget.lineNameResolver(_stops[_currentIndex].stopId) ?? 'Line';
  }

  double _distanceToStop(gtfs.Stop stop, double lat, double lon) {
    return geo.haversine(lat, lon, stop.lat, stop.lon);
  }

  LatLng _stopPoint(gtfs.Stop stop) => LatLng(stop.lat, stop.lon);

  List<LatLng> get _routePolyline => _stops.map(_stopPoint).toList();

  Widget _buildMap() {
    final polylines = _routePolyline;
    final markers = <Marker>[];
    if (_stops.isNotEmpty) {
      final next = _currentIndex < _stops.length - 1
          ? _stops[_currentIndex + 1]
          : _stops.last;
      markers.add(
        Marker(
          point: _stopPoint(next),
          width: 30,
          height: 30,
          child: const Icon(Icons.place, color: Colors.red, size: 30),
        ),
      );
      markers.add(
        Marker(
          point: _stopPoint(_stops.last),
          width: 28,
          height: 28,
          child: const Icon(Icons.flag, color: Colors.green, size: 26),
        ),
      );
    }
    if (_lastLocation?.latitude != null && _lastLocation?.longitude != null) {
      markers.add(
        Marker(
          point: LatLng(_lastLocation!.latitude!, _lastLocation!.longitude!),
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
                ),
              ),
            ),
          ),
        ),
      );
    }

    final travelledPath = polylines.sublist(
      0,
      math.min(_currentIndex + 1, polylines.length),
    );
    final upcomingPath = polylines.sublist(_currentIndex, polylines.length);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: polylines.isNotEmpty
            ? polylines.first
            : const LatLng(13.7463, 100.5347),
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          enableMultiFingerGestureRace: true,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.route',
        ),
        if (travelledPath.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: travelledPath,
                strokeWidth: 5,
                color: Colors.grey.withValues(alpha: 0.6),
              ),
            ],
          ),
        if (upcomingPath.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: upcomingPath,
                strokeWidth: 7,
                color: widget.lineColorResolver(_stops[_currentIndex].stopId),
                borderStrokeWidth: 2,
                borderColor: widget
                    .lineColorResolver(_stops[_currentIndex].stopId)
                    .withBlue(50)
                    .withGreen(50),
              ),
            ],
          ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildTopInstructionsCard(ThemeData theme) {
    final isLast = _currentIndex >= _stops.length - 1;
    final nextStop = isLast ? _stops.last : _stops[_currentIndex + 1];
    final nextColor = widget.lineColorResolver(nextStop.stopId);

    String distanceStr = '';
    if (_lastLocation?.latitude != null && _lastLocation?.longitude != null) {
      final m = _distanceToStop(
        nextStop,
        _lastLocation!.latitude!,
        _lastLocation!.longitude!,
      );
      distanceStr = m > 1000
          ? '${(m / 1000).toStringAsFixed(1)} km'
          : '${m.toStringAsFixed(0)} m';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 6,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Column(
              children: [
                Icon(
                  isLast ? Icons.flag : Icons.turn_slight_right,
                  color: isLast ? Colors.green : nextColor,
                  size: 36,
                ),
                if (distanceStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    distanceStr,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isLast ? Colors.green : nextColor,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLast ? 'Arrive at destination' : 'Next: ${nextStop.name}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Towards ${_stops.last.name}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHandle(Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(ThemeData theme) {
    final remainingMinutes = _remainingMinutes();
    final arrivalTime = TimeOfDay.fromDateTime(
      DateTime.now().add(Duration(minutes: remainingMinutes)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$remainingMinutes',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'min',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${arrivalTime.format(context)} • ${_stopsLeftOnCurrentLine()} stops left',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
                label: const Text('Exit'),
              ),
            ],
          ),
        ),
        _buildHorizontalTimeline(theme),
      ],
    );
  }

  Widget _buildHorizontalTimeline(ThemeData theme) {
    if (_stops.isEmpty) return const SizedBox.shrink();
    final currentLine = _currentLineName;
    final currentColor = widget.lineColorResolver(_stops[_currentIndex].stopId);

    // Find start index (up to 1 previous stop on the same line for context)
    int startIndex = _currentIndex;
    if (startIndex > 0 && widget.lineNameResolver(_stops[startIndex - 1].stopId) == currentLine) {
      startIndex--;
    }

    // Find end index (all remaining stops on this line)
    int endIndex = _currentIndex;
    while (endIndex < _stops.length - 1 && widget.lineNameResolver(_stops[endIndex + 1].stopId) == currentLine) {
      endIndex++;
    }

    final lineStops = _stops.sublist(startIndex, endIndex + 1);
    final localCurrentIndex = _currentIndex - startIndex;

    return Container(
      height: 100,
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: lineStops.length,
        itemBuilder: (context, index) {
          final stop = lineStops[index];
          final isPassed = index < localCurrentIndex;
          final isCurrent = index == localCurrentIndex;
          final isLast = index == lineStops.length - 1;
          final isFirst = index == 0;

          final color = isPassed ? Colors.grey.withValues(alpha: 0.5) : currentColor;
          final rightLineColor = (isPassed && !isCurrent) ? Colors.grey.withValues(alpha: 0.5) : currentColor;

          return SizedBox(
            width: 80, // Fixed width per stop
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Stop Name
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        stop.name,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isPassed
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Timeline Graphics
                SizedBox(
                  height: 24,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Left line
                      if (!isFirst)
                        Positioned(
                          left: 0,
                          right: 40,
                          child: Container(
                            height: 6,
                            color: color,
                          ),
                        ),
                      // Right line
                      if (!isLast)
                        Positioned(
                          left: 40,
                          right: 0,
                          child: Container(
                            height: 6,
                            color: rightLineColor,
                          ),
                        ),
                      // Dot
                      Container(
                        width: isCurrent ? 20 : 12,
                        height: isCurrent ? 20 : 12,
                        decoration: BoxDecoration(
                          color: isPassed ? Colors.grey : (isCurrent ? Colors.white : currentColor),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isPassed ? Colors.transparent : currentColor,
                            width: isCurrent ? 5 : 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstructionsList(ThemeData theme, ScrollController controller) {
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _stops.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final stop = _stops[index];
        final line = widget.lineNameResolver(stop.stopId) ?? 'Line';
        final color = widget.lineColorResolver(stop.stopId);
        final isCurrent = index == _currentIndex;
        final isPassed = index < _currentIndex;
        final isLast = index == _stops.length - 1;
        return ListTile(
          onTap: () => _jumpTo(index: index),
          contentPadding: EdgeInsets.zero,
          leading: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isLast
                    ? Icons.flag
                    : index == 0
                    ? Icons.trip_origin
                    : Icons.circle,
                color: isPassed ? Colors.grey : color,
                size: isCurrent ? 24 : 16,
              ),
            ],
          ),
          title: Text(
            stop.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isPassed
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Text('Line $line'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_stops.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Navigate')),
        body: const Center(child: Text('No stops available for navigation.')),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading:
            const SizedBox.shrink(), // hide default back button as we have custom ones
        flexibleSpace: SafeArea(child: _buildTopInstructionsCard(theme)),
        toolbarHeight: 120, // ample space for the floating card
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          if (_locationError != null)
            Positioned(
              top: 140,
              left: 16,
              right: 16,
              child: Material(
                color: theme.colorScheme.errorContainer,
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationError!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Floating action buttons
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.28,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter',
                  backgroundColor: theme.colorScheme.surface,
                  foregroundColor: _followUser
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  child: Icon(
                    _followUser ? Icons.my_location : Icons.location_searching,
                  ),
                  onPressed: () {
                    setState(() => _followUser = !_followUser);
                    if (_followUser &&
                        _lastLocation?.latitude != null &&
                        _lastLocation?.longitude != null) {
                      _mapController.move(
                        LatLng(
                          _lastLocation!.latitude!,
                          _lastLocation!.longitude!,
                        ),
                        _mapController.camera.zoom,
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'advance',
                  backgroundColor: theme.colorScheme.surface,
                  foregroundColor: theme.colorScheme.onSurface,
                  child: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    if (_currentIndex < _stops.length - 1) {
                      _jumpTo(index: _currentIndex + 1);
                    }
                  },
                ),
              ],
            ),
          ),

          Positioned.fill(
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.35,
              minChildSize: 0.35,
              maxChildSize: 0.9,
              builder: (context, controller) {
                return Material(
                  color: theme.colorScheme.surface,
                  elevation: 16,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Column(
                    children: [
                      _buildDrawerHandle(theme.colorScheme.outlineVariant),
                      _buildDrawerHeader(theme),
                      const Divider(height: 1),
                      Expanded(
                        child: _buildInstructionsList(theme, controller),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _jumpTo({required int index}) {
    _setCurrentIndex(index, moveCamera: true);
  }

  void _setCurrentIndex(int index, {required bool moveCamera}) {
    if (_stops.isEmpty) return;
    final nextIndex = index.clamp(0, _stops.length - 1);
    if (nextIndex == _currentIndex) return;
    setState(() => _currentIndex = nextIndex);
    if (moveCamera) {
      final target = _stopPoint(_stops[nextIndex]);
      _mapController.move(target, _mapController.camera.zoom);
    }
  }
}
