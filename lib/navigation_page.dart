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

  List<gtfs.Stop> get _stops => widget.option.stops;

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

  ({int index, double distance})? _nearestUpcomingStop(
    double lat,
    double lon,
  ) {
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
          width: 26,
          height: 26,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: polylines.isNotEmpty
            ? polylines.first
            : const LatLng(13.7463, 100.5347),
        initialZoom: 13,
        interactionOptions: const InteractionOptions(
          enableMultiFingerGestureRace: true,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.route',
        ),
        if (polylines.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: polylines,
                strokeWidth: 6,
                color: widget.lineColorResolver(
                  _stops[_currentIndex].stopId,
                ),
              ),
            ],
          ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
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
    final stopsLeftLine = _stopsLeftOnCurrentLine();
    final remainingMinutes = _remainingMinutes();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentLineName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$stopsLeftLine stops left on this line • ~$remainingMinutes min',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Recenter',
            icon: Icon(_followUser ? Icons.my_location : Icons.location_searching),
            onPressed: () {
              setState(() => _followUser = !_followUser);
              if (_followUser &&
                  _lastLocation?.latitude != null &&
                  _lastLocation?.longitude != null) {
                _mapController.move(
                  LatLng(_lastLocation!.latitude!, _lastLocation!.longitude!),
                  _mapController.camera.zoom,
                );
              }
            },
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
            label: const Text('End'),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepCard(ThemeData theme) {
    final isLast = _currentIndex >= _stops.length - 1;
    final nextStop = isLast ? _stops.last : _stops[_currentIndex + 1];
    final nextLine = widget.lineNameResolver(nextStop.stopId) ?? _currentLineName;
    final nextColor = widget.lineColorResolver(nextStop.stopId);
    final distance = (_lastLocation?.latitude != null &&
            _lastLocation?.longitude != null)
        ? _distanceToStop(
                nextStop, _lastLocation!.latitude!, _lastLocation!.longitude!)
            .toStringAsFixed(0)
        : null;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: nextColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.navigation, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLast ? 'Arrive at destination' : 'Next stop',
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(
                    nextStop.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Line $nextLine${distance != null ? ' • ${distance}m away' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (!isLast)
              FilledButton.icon(
                onPressed: () => _jumpTo(index: _currentIndex + 1),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Advance'),
              ),
          ],
        ),
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
        final distance = (_lastLocation?.latitude != null &&
                _lastLocation?.longitude != null)
            ? '${_distanceToStop(stop, _lastLocation!.latitude!, _lastLocation!.longitude!).toStringAsFixed(0)} m'
            : null;
        return ListTile(
          onTap: () => _jumpTo(index: index),
          leading: CircleAvatar(
            backgroundColor:
                isCurrent ? color : color.withValues(alpha: 0.18),
            child: Icon(
              isLast
                  ? Icons.flag
                  : index == 0
                      ? Icons.trip_origin
                      : Icons.stop_circle,
              color: Colors.white,
              size: 18,
            ),
          ),
          title: Text(stop.name),
          subtitle: Text('Line $line${distance != null ? ' • $distance' : ''}'),
          trailing: isPassed
              ? const Icon(Icons.check_circle, color: Colors.green)
              : isCurrent
                  ? const Icon(Icons.my_location)
                  : null,
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
      appBar: AppBar(
        title: Text(
          widget.option.label.isNotEmpty
              ? widget.option.label
              : 'Navigation',
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          if (_locationError != null)
            Positioned(
              top: 16,
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
          Positioned.fill(
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.24,
              minChildSize: 0.18,
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
                      if (_isExpanded)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          child: _buildNextStepCard(theme),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Next: ${_currentIndex >= _stops.length - 1 ? 'Arrive at destination' : _stops[_currentIndex + 1].name}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      Expanded(
                        child: _isExpanded
                            ? _buildInstructionsList(theme, controller)
                            : ListView(
                                controller: controller,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                children: [
                                  _buildNextStepCard(theme),
                                ],
                              ),
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
