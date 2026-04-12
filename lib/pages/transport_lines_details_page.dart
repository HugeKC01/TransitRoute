import 'package:route/pages/station_details_page.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:route/services/gtfs_sync_service.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;

class TransportLinesDetailsPage extends StatefulWidget {
  final gtfs.Route route;
  final gtfs.Agency? agency;

  const TransportLinesDetailsPage({
    super.key,
    required this.route,
    this.agency,
  });

  @override
  State<TransportLinesDetailsPage> createState() =>
      _TransportLinesDetailsPageState();
}

class _TransportLinesDetailsPageState extends State<TransportLinesDetailsPage> {
  bool _loading = true;
  List<gtfs.Stop> _routeStops = [];
  List<LatLng> _lineShape = [];
  List<String> _firstStationNames = [];
  List<String> _lastStationNames = [];

  @override
  void initState() {
    super.initState();
    _loadRouteStops();
  }

  // Basic CSV line parser supporting quoted fields and commas within quotes
  List<String> _parseCsvLine(String line) {
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

  Future<void> _loadRouteStops() async {
    try {
      final routeId = widget.route.routeId;
      String tripsFile = 'assets/gtfs_data/trips.txt';
      String stopTimesFile = 'assets/gtfs_data/stop_times.txt';
      String stopsFile = 'assets/gtfs_data/stops.txt';
      String shapesFile = 'assets/gtfs_data/shapes.txt';
      String? tIdIdxName = 'trip_id';
      String? rIdIdxName = 'route_id';

      bool isBus =
          widget.route.type.toLowerCase() == 'bus' || widget.route.type == '3';
      if (routeId == 'BRT') {
        isBus = false;
        tripsFile = 'assets/gtfs_data/brt_trips.txt';
        stopTimesFile = 'assets/gtfs_data/bus_stop_times.txt';
        stopsFile = 'assets/gtfs_data/bus_stop.txt';
        shapesFile = 'assets/gtfs_data/shapes.txt';
      } else if (isBus) {
        tripsFile = 'assets/gtfs_data/bus_route_stop.txt';
        stopTimesFile = '';
        stopsFile = 'assets/gtfs_data/bus_stop.txt';
        shapesFile = 'assets/gtfs_data/shapes_source.txt';
      } else if (widget.route.type.toLowerCase() == 'ferry' ||
          widget.route.type == '4') {
        tripsFile = 'assets/gtfs_data/ferry_trips.txt';
        stopTimesFile = 'assets/gtfs_data/ferry_stop_times.txt';
        stopsFile = 'assets/gtfs_data/ferry_stop.txt';
        shapesFile = '';
      }

      final targetTripIds = <String>{};
      String? targetShapeId;
      final orderedStopIds = <String>[];
      final allFirstStopIds = <String>{};
      final allLastStopIds = <String>{};

      if (isBus) {
        final busContent = await gtfsSyncService.getGtfsFile(tripsFile);
        final busLines = const LineSplitter().convert(busContent);
        if (busLines.length > 1) {
          String? bestShape;
          List<String> bestStops = [];
          for (int i = 1; i < busLines.length; i++) {
            final row = _parseCsvLine(busLines[i]);
            if (row.length > 5) {
              final rShortName = row[1].trim();
              if (rShortName.split(' ')[0].trim() == routeId) {
                final stops = <String>[];
                for (int j = 6; j < row.length; j++) {
                  final sid = row[j].trim();
                  if (sid.isNotEmpty) stops.add(sid);
                }
                if (stops.isNotEmpty) {
                  allFirstStopIds.add(stops.first);
                  allLastStopIds.add(stops.last);
                }
                if (stops.length > bestStops.length) {
                  bestStops = stops;
                  bestShape = row[5].trim();
                }
              }
            }
          }
          if (bestShape != null) targetShapeId = bestShape;
          orderedStopIds.addAll(bestStops);
        }
      } else {
        final tripsContent = await gtfsSyncService.getGtfsFile(tripsFile);
        final tripsLines = const LineSplitter().convert(tripsContent);
        if (tripsLines.length > 1) {
          final headerRow = _parseCsvLine(tripsLines.first);
          final routeIdIdx = headerRow.indexOf(rIdIdxName);
          final tripIdIdx = headerRow.indexOf(tIdIdxName);
          final shapeIdIdx = headerRow.indexOf('shape_id');
          bool brtFallback = tripIdIdx < 0 && routeId == 'BRT';

          for (int i = brtFallback ? 0 : 1; i < tripsLines.length; i++) {
            final row = _parseCsvLine(tripsLines[i]);
            if (row.isEmpty) continue;
            if (brtFallback) {
              if (row[0].contains('BRT')) {
                targetTripIds.add(row[0]);
                if (row.length > 1 && row[1].isNotEmpty && row[0] == 'BRT_0') {
                  targetShapeId = row[1].trim();
                }
              }
            } else if (routeIdIdx >= 0 &&
                tripIdIdx >= 0 &&
                row.length > routeIdIdx &&
                row[routeIdIdx] == routeId) {
              targetTripIds.add(row[tripIdIdx]);
              if (shapeIdIdx >= 0 &&
                  row.length > shapeIdIdx &&
                  row[shapeIdIdx].isNotEmpty) {
                targetShapeId = row[shapeIdIdx];
              }
            } else if (routeIdIdx < 0 &&
                tripIdIdx >= 0 &&
                row.length > tripIdIdx) {
              if (row[tripIdIdx].contains(routeId)) {
                targetTripIds.add(row[tripIdIdx]);
                if (shapeIdIdx >= 0 &&
                    row.length > shapeIdIdx &&
                    row[shapeIdIdx].isNotEmpty) {
                  targetShapeId = row[shapeIdIdx];
                }
              }
            }
          }
        }

        if (targetTripIds.isNotEmpty && stopTimesFile.isNotEmpty) {
          final stopTimesContent = await gtfsSyncService.getGtfsFile(
            stopTimesFile,
          );
          final stopTimesLines = const LineSplitter().convert(stopTimesContent);
          if (stopTimesLines.isNotEmpty) {
            final headerRow = _parseCsvLine(stopTimesLines.first);
            int tripIdIdx = headerRow.indexOf('trip_id');
            if (tripIdIdx < 0) tripIdIdx = 0;
            int stopIdIdx = headerRow.indexOf('stop_id');
            if (stopIdIdx < 0) stopIdIdx = 3;
            int seqIdx = headerRow.indexOf('stop_sequence');
            if (seqIdx < 0) seqIdx = 4;

            bool stFallback = !headerRow.contains('trip_id');

            final tripStopsMap = <String, List<Map<String, dynamic>>>{};
            for (int i = stFallback ? 0 : 1; i < stopTimesLines.length; i++) {
              final row = _parseCsvLine(stopTimesLines[i]);
              if (row.isEmpty) continue;
              if (tripIdIdx >= 0 &&
                  stopIdIdx >= 0 &&
                  seqIdx >= 0 &&
                  row.length > tripIdIdx &&
                  row.length > stopIdIdx &&
                  row.length > seqIdx &&
                  targetTripIds.contains(row[tripIdIdx])) {
                tripStopsMap.putIfAbsent(row[tripIdIdx], () => []).add({
                  'stop_id': row[stopIdIdx],
                  'sequence': int.tryParse(row[seqIdx]) ?? 0,
                });
              }
            }
            if (tripStopsMap.isNotEmpty) {
              final sortedTrips = tripStopsMap.values.toList()
                ..sort((a, b) => b.length.compareTo(a.length));
              final longestTrip = sortedTrips.first;
              longestTrip.sort(
                (a, b) =>
                    (a['sequence'] as int).compareTo(b['sequence'] as int),
              );
              final referenceFirst = longestTrip.first['stop_id'] as String;
              final referenceLast = longestTrip.last['stop_id'] as String;

              for (final trip in tripStopsMap.values) {
                if (trip.isNotEmpty) {
                  trip.sort(
                    (a, b) =>
                        (a['sequence'] as int).compareTo(b['sequence'] as int),
                  );
                  final thisFirst = trip.first['stop_id'] as String;
                  final thisLast = trip.last['stop_id'] as String;
                  if (thisLast == referenceLast ||
                      thisFirst == referenceFirst) {
                    allFirstStopIds.add(thisFirst);
                    allLastStopIds.add(thisLast);
                  }
                }
              }
              for (final st in longestTrip) {
                orderedStopIds.add(st['stop_id'] as String);
              }
            }
          }
        }
      }

      final stopsContent = await gtfsSyncService.getGtfsFile(stopsFile);
      final stopsLines = const LineSplitter().convert(stopsContent);
      final Map<String, gtfs.Stop> stopsMap = {};
      final resolvedFirstStops = <String, String>{};
      final resolvedLastStops = <String, String>{};

      if (stopsLines.length > 1) {
        final headerRow = _parseCsvLine(stopsLines.first);
        int idIdx = headerRow.indexOf('stop_id');
        if (idIdx < 0) idIdx = 0;
        int nameIdx = headerRow.indexOf('stop_name');
        if (nameIdx < 0) nameIdx = 1;
        int thaiIdx = headerRow.indexOf('stop_name_th');
        int latIdx = headerRow.indexOf('stop_lat');
        if (latIdx < 0) latIdx = 2;
        int lonIdx = headerRow.indexOf('stop_lon');
        if (lonIdx < 0) lonIdx = 3;
        final codeIdx = headerRow.indexOf('stop_code');
        final descIdx = headerRow.indexOf('stop_desc');
        final zoneIdx = headerRow.indexOf('zone_id');

        for (int i = 1; i < stopsLines.length; i++) {
          final row = _parseCsvLine(stopsLines[i]);
          if (row.isEmpty || row.length <= idIdx) continue;
          final stopId = row[idIdx];

          String valueAt(int idx) =>
              (idx >= 0 && idx < row.length) ? row[idx].trim() : '';
          final thaiName = valueAt(thaiIdx);
          final pName = thaiName.isNotEmpty ? thaiName : valueAt(nameIdx);

          if (allFirstStopIds.contains(stopId)) {
            resolvedFirstStops[stopId] = pName;
          }
          if (allLastStopIds.contains(stopId)) {
            resolvedLastStops[stopId] = pName;
          }

          if (orderedStopIds.contains(stopId)) {
            stopsMap[stopId] = gtfs.Stop(
              stopId: stopId,
              name: valueAt(nameIdx),
              thaiName: thaiName.isNotEmpty ? thaiName : null,
              lat: double.tryParse(valueAt(latIdx)) ?? 0.0,
              lon: double.tryParse(valueAt(lonIdx)) ?? 0.0,
              code: valueAt(codeIdx).isEmpty ? null : valueAt(codeIdx),
              desc: valueAt(descIdx).isEmpty ? null : valueAt(descIdx),
              zoneId: valueAt(zoneIdx).isEmpty ? null : valueAt(zoneIdx),
            );
          }
        }
      }

      final resultStops = <gtfs.Stop>[];
      final seenStops = <String>{};
      for (final id in orderedStopIds) {
        if (stopsMap.containsKey(id) && !seenStops.contains(id)) {
          resultStops.add(stopsMap[id]!);
          seenStops.add(id);
        }
      }

      final linePoints = <LatLng>[];
      if (targetShapeId != null &&
          targetShapeId.isNotEmpty &&
          shapesFile.isNotEmpty) {
        try {
          final shapeContent = await gtfsSyncService.getGtfsFile(shapesFile);
          final shapeLines = const LineSplitter().convert(shapeContent);
          if (shapeLines.length > 1) {
            final sHead = _parseCsvLine(shapeLines.first);
            final sidIdx = sHead.indexOf('shape_id');
            final latIdx = sHead.indexOf('shape_pt_lat');
            final lonIdx = sHead.indexOf('shape_pt_lon');
            final seqIdx = sHead.indexOf('shape_pt_sequence');

            final pts = <Map<String, dynamic>>[];
            for (int i = 1; i < shapeLines.length; i++) {
              final row = _parseCsvLine(shapeLines[i]);
              if (row.length > sidIdx && row[sidIdx] == targetShapeId) {
                pts.add({
                  'lat': double.tryParse(row[latIdx]) ?? 0.0,
                  'lon': double.tryParse(row[lonIdx]) ?? 0.0,
                  'seq': int.tryParse(row[seqIdx]) ?? 0,
                });
              }
            }
            pts.sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
            for (final pt in pts) {
              linePoints.add(LatLng(pt['lat'], pt['lon']));
            }
          }
        } catch (_) {}
      }

      if (linePoints.isEmpty && resultStops.isNotEmpty) {
        for (final s in resultStops) {
          linePoints.add(LatLng(s.lat, s.lon));
        }
      }

      setState(() {
        _routeStops = resultStops;
        _lineShape = linePoints;
        _firstStationNames = allFirstStopIds
            .map((id) => resolvedFirstStops[id])
            .where((n) => n != null && n.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();
        _lastStationNames = allLastStopIds
            .map((id) => resolvedLastStops[id])
            .where((n) => n != null && n.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading stops for route: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  Color _colorFromHexOr(String? hex, Color fallback) {
    if (hex == null) return fallback;
    var s = hex.trim().replaceAll('\r', '').replaceAll('#', '');
    if (s.isEmpty) return fallback;
    try {
      return Color(int.parse('0xFF$s'));
    } catch (_) {
      return fallback;
    }
  }

  String _transportCategory(String type) {
    final raw = type.trim().toLowerCase();
    bool matches(Iterable<String> values) =>
        values.any((value) => value == raw);

    if (matches(['0', '1', 'metro', 'subway', 'rapid transit'])) return 'Metro';
    if (matches(['2', 'rail', 'train', 'commuter'])) return 'Train';
    if (matches(['3', 'bus'])) return 'Bus';
    if (matches(['4', 'ferry', 'boat'])) return 'Ferry';
    return 'Other Transport';
  }

  IconData _iconForCategory(String type) {
    switch (type) {
      case 'Metro':
        return Icons.subway;
      case 'Train':
        return Icons.train;
      case 'Bus':
        return Icons.directions_bus;
      case 'Ferry':
        return Icons.directions_boat;
      default:
        return Icons.directions_transit;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routeInfo = widget.route;
    final agency = widget.agency;

    final routeColor = _colorFromHexOr(
      routeInfo.color,
      theme.colorScheme.primary,
    );
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    final headerSection = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : routeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: routeColor, width: 3),
              ),
              child: Center(
                child:
                    routeInfo.routeIcon != null &&
                        routeInfo.routeIcon!.isNotEmpty
                    ? SizedBox(
                        width: 48,
                        height: 48,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SvgPicture.asset(routeInfo.routeIcon!),
                        ),
                      )
                    : Icon(
                        _iconForCategory(_transportCategory(routeInfo.type)),
                        size: 48,
                        color: routeColor,
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final isBusNotBRT =
                    _transportCategory(routeInfo.type) == 'Bus' &&
                    routeInfo.routeId != 'BRT';
                final heading = isBusNotBRT
                    ? routeInfo.shortName
                    : routeInfo.longName;
                final subHeading = isBusNotBRT ? routeInfo.longName : null;
                return Column(
                  children: [
                    Text(
                      heading.isNotEmpty ? heading : routeInfo.routeId,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subHeading != null &&
                        subHeading.isNotEmpty &&
                        subHeading != heading) ...[
                      const SizedBox(height: 8),
                      Text(
                        subHeading,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            if (!_loading && _routeStops.isNotEmpty) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final startText = _firstStationNames.isNotEmpty
                      ? _firstStationNames.join(', ')
                      : _routeStops.first.name;
                  final endText = _lastStationNames.isNotEmpty
                      ? _lastStationNames.join(', ')
                      : _routeStops.last.name;
                  return Text(
                    '$startText - $endText',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );

    final infoSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Information',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              _buildInfoTile(
                icon: Icons.directions_transit,
                title: 'Transport Type',
                subtitle: _transportCategory(routeInfo.type),
                theme: theme,
              ),
              const Divider(height: 1),
              _buildInfoTile(
                icon: Icons.business,
                title: 'Operating Agency',
                subtitle: agency?.name.isNotEmpty == true
                    ? agency!.name
                    : (routeInfo.agencyId.isNotEmpty
                          ? routeInfo.agencyId
                          : 'Unknown Agency'),
                theme: theme,
              ),
              if (agency?.url.isNotEmpty == true) ...[
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.language,
                  title: 'Website',
                  subtitle: agency!.url,
                  theme: theme,
                ),
              ],
              if (widget.agency?.phone?.isNotEmpty == true) ...[
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.phone,
                  title: 'Contact Phone',
                  subtitle: widget.agency!.phone ?? '',
                  theme: theme,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final markers = _routeStops.map((stop) {
      return Marker(
        point: LatLng(stop.lat, stop.lon),
        width: 16,
        height: 16,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: routeColor, width: 3),
          ),
        ),
      );
    }).toList();

    var cLat = 13.7563;
    var cLon = 100.5018;
    if (_routeStops.isNotEmpty) {
      cLat =
          _routeStops.map((s) => s.lat).reduce((a, b) => a + b) /
          _routeStops.length;
      cLon =
          _routeStops.map((s) => s.lon).reduce((a, b) => a + b) /
          _routeStops.length;
    }

    final mapWidget = Container(
      height: isPortrait ? 250 : double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(isPortrait ? 24 : 0),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: isPortrait ? Clip.antiAlias : Clip.none,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(cLat, cLon),
          initialZoom: 12.0,
          interactionOptions: isPortrait
              ? const InteractionOptions(flags: InteractiveFlag.none)
              : const InteractionOptions(flags: InteractiveFlag.all),
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: "com.example.transit_route",
          ),
          if (_lineShape.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _lineShape,
                  color: routeColor,
                  strokeWidth: 4.0,
                ),
              ],
            ),
          MarkerLayer(markers: markers),
        ],
      ),
    );

    final stopListSection = _loading
        ? const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          )
        : _routeStops.isNotEmpty
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Stations (${_routeStops.length})",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _routeStops.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final stop = _routeStops[index];
                    final hasThai =
                        stop.thaiName != null &&
                        stop.thaiName!.trim().isNotEmpty;
                    final displayCode =
                        (stop.code != null && stop.code!.trim().isNotEmpty)
                        ? stop.code!
                        : "${index + 1}";
                    return ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StationDetailsPage(
                              stop: stop,
                              lineColor: routeColor,
                              lineName: routeInfo.shortName.isNotEmpty
                                  ? routeInfo.shortName
                                  : routeInfo.longName,
                              onSelectAsStart: () {
                                // Can be implemented if needed
                              },
                              onSelectAsDestination: () {
                                // Can be implemented if needed
                              },
                            ),
                          ),
                        );
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 4.0,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: routeColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: routeColor, width: 2),
                        ),
                        child: Center(
                          child: FittedBox(
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(
                                displayCode,
                                style: TextStyle(
                                  color: routeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        hasThai ? stop.thaiName! : stop.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: hasThai
                          ? Text(
                              stop.name,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : null,
                      trailing: const Icon(
                        Icons.map,
                        size: 20,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ],
          )
        : const SizedBox();

    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: routeColor,
          secondary: routeColor,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text("Route Details"), centerTitle: true),
        body: isPortrait
            ? ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  headerSection,
                  const SizedBox(height: 16),
                  if (!_loading && _routeStops.isNotEmpty) mapWidget,
                  const SizedBox(height: 32),
                  infoSection,
                  const SizedBox(height: 32),
                  stopListSection,
                ],
              )
            : Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        headerSection,
                        const SizedBox(height: 32),
                        infoSection,
                        const SizedBox(height: 32),
                        stopListSection,
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    flex: 6,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : mapWidget,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      ),
      title: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
