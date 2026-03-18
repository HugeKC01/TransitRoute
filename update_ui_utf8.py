import sys
import re

with open('lib/pages/transport_lines_details_page.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Replace State properties
text = text.replace(
'''class _TransportLinesDetailsPageState extends State<TransportLinesDetailsPage> {
  bool _loading = true;
  List<gtfs.Stop> _routeStops = [];

  @override''',
'''class TripInfo {
  final String tripId;
  final String headsign;
  final String directionId;
  final List<gtfs.Stop> stops;
  TripInfo({
    required this.tripId,
    required this.headsign,
    required this.directionId,
    required this.stops,
  });
}

class _TransportLinesDetailsPageState extends State<TransportLinesDetailsPage> {
  bool _loading = true;
  List<TripInfo> _trips = [];
  int _selectedTripIndex = 0;

  @override''')

old_load_stops = r'''  Future<void> _loadRouteStops\(\) async \{.*?\n  \}'''
new_load_stops = '''  Future<void> _loadRouteStops() async {
    try {
      final tripsFuture = rootBundle.loadString('assets/gtfs_data/trips.txt');
      final stopTimesFuture = rootBundle.loadString(
        'assets/gtfs_data/stop_times.txt',
      );
      final stopsFuture = rootBundle.loadString('assets/gtfs_data/stops.txt');

      final tripsContent = await tripsFuture;
      final tripsLines = const LineSplitter().convert(tripsContent);

      final List<Map<String, String>> routeTrips = [];
      if (tripsLines.length > 1) {
        final headerRow = _parseCsvLine(tripsLines.first);
        final routeIdIdx = headerRow.indexOf('route_id');
        final tripIdIdx = headerRow.indexOf('trip_id');
        final headsignIdx = headerRow.indexOf('trip_headsign');
        final directionIdx = headerRow.indexOf('direction_id');

        for (int i = 1; i < tripsLines.length; i++) {
          final row = _parseCsvLine(tripsLines[i]);
          if (row.isEmpty) continue;

          if (routeIdIdx >= 0 && row.length > routeIdIdx && row[routeIdIdx] == widget.route.routeId) {
            String valAt(int idx) => (idx >= 0 && idx < row.length) ? row[idx] : '';
            routeTrips.add({
              'trip_id': valAt(tripIdIdx),
              'headsign': valAt(headsignIdx),
              'direction_id': valAt(directionIdx),
            });
          }
        }
      }

      if (routeTrips.isEmpty) {
        setState(() {
          _loading = false;
        });
        return;
      }

      final Map<String, Map<String, String>> distinctTripsByDir = {};
      for (final t in routeTrips) {
        final key = t['direction_id']!.isNotEmpty ? t['direction_id']! : t['headsign']!.isNotEmpty ? t['headsign']! : t['trip_id']!;
        if (!distinctTripsByDir.containsKey(key)) {
            distinctTripsByDir[key] = t;
        }
      }
      
      final validTrips = distinctTripsByDir.values.toList();
      final validTripIds = validTrips.map((e) => e['trip_id']!).toSet();

      final stopTimesContent = await stopTimesFuture;
      final stopTimesLines = const LineSplitter().convert(stopTimesContent);
      final Map<String, List<Map<String, dynamic>>> tripStopsData = {};
      for (final tid in validTripIds) {
          tripStopsData[tid] = [];
      }
      final allNeededStopIds = set();
      
      if (stopTimesLines.length > 1) {
        final headerRow = _parseCsvLine(stopTimesLines.first);
        final tripIdIdx = headerRow.indexOf('trip_id');
        final stopIdIdx = headerRow.indexOf('stop_id');
        final seqIdx = headerRow.indexOf('stop_sequence');

        for (int i = 1; i < stopTimesLines.length; i++) {
          final row = _parseCsvLine(stopTimesLines[i]);
          if (row.isEmpty) continue;
          if (tripIdIdx >= 0 && row.length > tripIdIdx) {
             final tId = row[tripIdIdx];
             if (validTripIds.contains(tId)) {
                final stopId = row[stopIdIdx];
                tripStopsData[tId]!.add({
                  'stop_id': stopId,
                  'sequence': int.tryParse(row[seqIdx]) ?? 0,
                });
                allNeededStopIds.add(stopId);
             }
          }
        }
      }

      for (final tId in validTripIds) {
         tripStopsData[tId]!.sort((a, b) => (a['sequence'] as int).compareTo(b['sequence'] as int));
      }

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
          if (allNeededStopIds.contains(stopId)) {
            String valueAt(int idx) => (idx >= 0 && idx < row.length) ? row[idx].trim() : '';
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

      final finalTrips = <TripInfo>[];
      for (final vt in validTrips) {
          final tId = vt['trip_id']!;
          final stopsData = tripStopsData[tId]!;
          final tripStops = <gtfs.Stop>[];
          for (final sd in stopsData) {
             final sId = sd['stop_id'] as String;
             if (stopsMap.containsKey(sId)) {
                 tripStops.add(stopsMap[sId]!);
             }
          }
          if (tripStops.isNotEmpty) {
            finalTrips.add(TripInfo(
               tripId: tId,
               headsign: vt['headsign']!,
               directionId: vt['direction_id']!,
               stops: tripStops,
            ));
          }
      }

      setState(() {
        _trips = finalTrips;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading stops for route: \');
      setState(() {
        _loading = false;
      });
    }
  }'''
text = re.sub(old_load_stops, new_load_stops, text, flags=re.DOTALL)

old_build_end = r'''          else if \(_routeStops\.isNotEmpty\) \.\.\.\[.*?itemBuilder: \(context, index\) \{\n                  final stop = _routeStops\[index\];'''
new_build_end = '''          else if (_trips.isNotEmpty) ...[
            if (_trips.length > 1) ...[
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Direction',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: SegmentedButton<int>(
                    segments: List.generate(_trips.length, (index) {
                      final trip = _trips[index];
                      final name = trip.directionId == '0' ? 'Outbound' : (trip.directionId == '1' ? 'Inbound' : 'Trip \\');
                      final title = trip.headsign.isNotEmpty ? '\\ (\\)' : name;
                      return ButtonSegment<int>(
                        value: index,
                        label: Text(title, style: const TextStyle(fontSize: 12)),
                      );
                    }),
                    selected: {_selectedTripIndex},
                    onSelectionChanged: (Set<int> newSelection) {
                      setState(() {
                        _selectedTripIndex = newSelection.first;
                      });
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'Stations (\\)',
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
                itemCount: _trips[_selectedTripIndex].stops.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final stop = _trips[_selectedTripIndex].stops[index];'''
text = re.sub(old_build_end, new_build_end, text, flags=re.DOTALL)

with open('lib/pages/transport_lines_details_page.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print('Done')
