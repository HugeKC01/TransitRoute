import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
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
      // 1. Load trips to find trip_id for this route
      final tripsFuture = rootBundle.loadString('assets/gtfs_data/trips.txt');
      final stopTimesFuture = rootBundle.loadString(
        'assets/gtfs_data/stop_times.txt',
      );
      final stopsFuture = rootBundle.loadString('assets/gtfs_data/stops.txt');

      final tripsContent = await tripsFuture;
      final tripsLines = const LineSplitter().convert(tripsContent);

      String targetTripId = '';
      if (tripsLines.length > 1) {
        final headerRow = _parseCsvLine(tripsLines.first);
        final routeIdIdx = headerRow.indexOf('route_id');
        final tripIdIdx = headerRow.indexOf('trip_id');

        for (int i = 1; i < tripsLines.length; i++) {
          final row = _parseCsvLine(tripsLines[i]);
          if (row.isEmpty) continue;

          if (routeIdIdx >= 0 &&
              row.length > routeIdIdx &&
              row[routeIdIdx] == widget.route.routeId) {
            targetTripId = row[tripIdIdx];
            break; // take the first matched trip
          }
        }
      }

      if (targetTripId.isEmpty) {
        setState(() {
          _loading = false;
        });
        return;
      }

      // 2. Load stop_times to find stop_ids in sequence for this trip
      final stopTimesContent = await stopTimesFuture;
      final stopTimesLines = const LineSplitter().convert(stopTimesContent);

      final orderedStopIds = <String>[];
      if (stopTimesLines.length > 1) {
        final headerRow = _parseCsvLine(stopTimesLines.first);
        final tripIdIdx = headerRow.indexOf('trip_id');
        final stopIdIdx = headerRow.indexOf('stop_id');
        final seqIdx = headerRow.indexOf('stop_sequence');

        final tripStops = <Map<String, dynamic>>[];

        for (int i = 1; i < stopTimesLines.length; i++) {
          final row = _parseCsvLine(stopTimesLines[i]);
          if (row.isEmpty) continue;

          if (tripIdIdx >= 0 &&
              row.length > tripIdIdx &&
              row[tripIdIdx] == targetTripId) {
            tripStops.add({
              'stop_id': row[stopIdIdx],
              'sequence': int.tryParse(row[seqIdx]) ?? 0,
            });
          }
        }

        tripStops.sort(
          (a, b) => (a['sequence'] as int).compareTo(b['sequence'] as int),
        );
        orderedStopIds.addAll(tripStops.map((e) => e['stop_id'] as String));
      }

      // 3. Load stops to get details matching those stop_ids
      final stopsContent = await stopsFuture;
      final stopsLines = const LineSplitter().convert(stopsContent);
      final Map<String, gtfs.Stop> stopsMap = {};

      if (stopsLines.length > 1) {
        final headerRow = _parseCsvLine(stopsLines.first);
        final idIdx = headerRow.indexOf('stop_id');
        final nameIdx = headerRow.indexOf('stop_name');
        final latIdx = headerRow.indexOf('stop_lat');
        final lonIdx = headerRow.indexOf('stop_lon');
        final codeIdx = headerRow.indexOf('stop_code');
        final descIdx = headerRow.indexOf('stop_desc');
        final zoneIdx = headerRow.indexOf('zone_id');

        for (int i = 1; i < stopsLines.length; i++) {
          final row = _parseCsvLine(stopsLines[i]);
          if (row.isEmpty || row.length <= idIdx) continue;

          final stopId = row[idIdx];

          // Optimization: Only parse stops we actually need
          if (orderedStopIds.contains(stopId)) {
            String valueAt(int idx) =>
                (idx >= 0 && idx < row.length) ? row[idx].trim() : '';

            stopsMap[stopId] = gtfs.Stop(
              stopId: stopId,
              name: valueAt(nameIdx),
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
      for (final id in orderedStopIds) {
        if (stopsMap.containsKey(id)) {
          resultStops.add(stopsMap[id]!);
        }
      }

      setState(() {
        _routeStops = resultStops;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final route = widget.route;
    final agency = widget.agency;

    final routeColor = _colorFromHexOr(route.color, theme.colorScheme.primary);

    // Choose text color based on background luminance, ensuring readability
    final routeTextColor = _colorFromHexOr(
      route.textColor,
      routeColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Details'),
        backgroundColor: routeColor,
        foregroundColor: routeTextColor,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Hero Header Section
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 32.0,
                horizontal: 16.0,
              ),
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: routeColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: routeColor.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        route.shortName.isNotEmpty ? route.shortName : "—",
                        style: TextStyle(
                          color: routeTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: route.shortName.length > 3 ? 24 : 36,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    route.longName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (route.linePrefixes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: route.linePrefixes
                          .where((p) => p.isNotEmpty)
                          .map(
                            (p) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                p,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Details Information Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                _buildInfoTile(
                  icon: Icons.directions_transit,
                  title: 'Transport Type',
                  subtitle: _transportCategory(route.type),
                  theme: theme,
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.business,
                  title: 'Operating Agency',
                  subtitle: agency?.name.isNotEmpty == true
                      ? agency!.name
                      : (route.agencyId.isNotEmpty
                            ? route.agencyId
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

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_routeStops.isNotEmpty) ...[
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'Stations (${_routeStops.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _routeStops.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final stop = _routeStops[index];
                  return ListTile(
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
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: routeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      stop.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: stop.code != null || stop.stopId.isNotEmpty
                        ? Text(
                            stop.code ?? stop.stopId,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : null,
                    trailing: const Icon(
                      Icons.location_on,
                      size: 20,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
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
