import sys
content = open('lib/pages/transport_lines_details_page.dart', 'r', encoding='utf-8').read()

if 'List<String> _firstStationNames = [];' not in content:
    content = content.replace(
        'List<LatLng> _lineShape = [];',
        'List<LatLng> _lineShape = [];\n  List<String> _firstStationNames = [];\n  List<String> _lastStationNames = [];'
    )

old_ordered_stop_ids = '''      final targetTripIds = <String>{};
      String? targetShapeId;
      final orderedStopIds = <String>[];'''

new_ordered_stop_ids = '''      final targetTripIds = <String>{};
      String? targetShapeId;
      final orderedStopIds = <String>[];
      final allFirstStopIds = <String>{};
      final allLastStopIds = <String>{};'''

content = content.replace(old_ordered_stop_ids, new_ordered_stop_ids)

old_bus = '''              final rShortName = row[1].trim();
              if (rShortName.split(' ')[0].trim() == routeId) {
                final stops = <String>[];
                for (int j = 6; j < row.length; j++) {
                  final sid = row[j].trim();
                  if (sid.isNotEmpty) stops.add(sid);
                }
                if (stops.length > bestStops.length) {
                  bestStops = stops;
                  bestShape = row[5].trim();
                }
              }'''
new_bus = '''              final rShortName = row[1].trim();
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
              }'''
              
content = content.replace(old_bus, new_bus)

old_trip_stops = '''            if (tripStopsMap.isNotEmpty) {
              final sortedTrips = tripStopsMap.values.toList()
                ..sort((a, b) => b.length.compareTo(a.length));
              final longestTrip = sortedTrips.first;
              longestTrip.sort(
                (a, b) =>
                    (a['sequence'] as int).compareTo(b['sequence'] as int),
              );
              for (final st in longestTrip) {
                orderedStopIds.add(st['stop_id'] as String);
              }
            }'''
new_trip_stops = '''            if (tripStopsMap.isNotEmpty) {
              for (final trip in tripStopsMap.values) {
                if (trip.isNotEmpty) {
                  trip.sort((a,b) => (a['sequence'] as int).compareTo(b['sequence'] as int));
                  allFirstStopIds.add(trip.first['stop_id'] as String);
                  allLastStopIds.add(trip.last['stop_id'] as String);
                }
              }
              final sortedTrips = tripStopsMap.values.toList()
                ..sort((a, b) => b.length.compareTo(a.length));
              final longestTrip = sortedTrips.first;
              for (final st in longestTrip) {
                orderedStopIds.add(st['stop_id'] as String);
              }
            }'''

content = content.replace(old_trip_stops, new_trip_stops)

old_stops = '''      final stopsContent = await gtfsSyncService.getGtfsFile(stopsFile);
      final stopsLines = const LineSplitter().convert(stopsContent);
      final Map<String, gtfs.Stop> stopsMap = {};'''
new_stops = '''      final stopsContent = await gtfsSyncService.getGtfsFile(stopsFile);
      final stopsLines = const LineSplitter().convert(stopsContent);
      final Map<String, gtfs.Stop> stopsMap = {};
      final resolvedFirstStops = <String, String>{};
      final resolvedLastStops = <String, String>{};'''

content = content.replace(old_stops, new_stops)

old_stops_read = '''          final stopId = row[idIdx];

          if (orderedStopIds.contains(stopId)) {
            String valueAt(int idx) =>
                (idx >= 0 && idx < row.length) ? row[idx].trim() : '';
            final thaiName = valueAt(thaiIdx);'''
new_stops_read = '''          final stopId = row[idIdx];

          String valueAt(int idx) =>
              (idx >= 0 && idx < row.length) ? row[idx].trim() : '';
          final thaiName = valueAt(thaiIdx);
          final pName = thaiName.isNotEmpty ? thaiName : valueAt(nameIdx);
          
          if (allFirstStopIds.contains(stopId)) resolvedFirstStops[stopId] = pName;
          if (allLastStopIds.contains(stopId)) resolvedLastStops[stopId] = pName;

          if (orderedStopIds.contains(stopId)) {'''

content = content.replace(old_stops_read, new_stops_read)

old_set_state = '''      setState(() {
        _routeStops = resultStops;
        _lineShape = linePoints;
        _loading = false;
      });'''
new_set_state = '''      setState(() {
        _routeStops = resultStops;
        _lineShape = linePoints;
        _firstStationNames = allFirstStopIds.map((id) => resolvedFirstStops[id]).where((n) => n != null).cast<String>().toSet().toList();
        _lastStationNames = allLastStopIds.map((id) => resolvedLastStops[id]).where((n) => n != null).cast<String>().toSet().toList();
        _loading = false;
      });'''

content = content.replace(old_set_state, new_set_state)

old_ui = '''            if (!_loading && _routeStops.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_routeStops.first.name} - ${_routeStops.last.name}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],'''
new_ui = '''            if (!_loading && _routeStops.isNotEmpty) ...[
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final startText = _firstStationNames.isNotEmpty ? _firstStationNames.join(', ') : _routeStops.first.name;
                final endText = _lastStationNames.isNotEmpty ? _lastStationNames.join(', ') : _routeStops.last.name;
                return Text(
                  '$startText - $endText',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }),
            ],'''

content = content.replace(old_ui, new_ui)

with open('lib/pages/transport_lines_details_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("done")
