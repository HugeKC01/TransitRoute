import sys
content = open('lib/pages/transport_lines_details_page.dart', 'r', encoding='utf-8').read()

old_trip_stops = '''            if (tripStopsMap.isNotEmpty) {
              for (final trip in tripStopsMap.values) {
                if (trip.isNotEmpty) {
                  trip.sort((a, b) =>
                      (a['sequence'] as int).compareTo(b['sequence'] as int));
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

new_trip_stops = '''            if (tripStopsMap.isNotEmpty) {
              final sortedTrips = tripStopsMap.values.toList()
                ..sort((a, b) => b.length.compareTo(a.length));
              final longestTrip = sortedTrips.first;
              longestTrip.sort((a,b) => (a['sequence'] as int).compareTo(b['sequence'] as int));
              final referenceFirst = longestTrip.first['stop_id'] as String;
              final referenceLast = longestTrip.last['stop_id'] as String;

              for (final trip in tripStopsMap.values) {
                if (trip.isNotEmpty) {
                  trip.sort((a,b) => (a['sequence'] as int).compareTo(b['sequence'] as int));
                  final thisFirst = trip.first['stop_id'] as String;
                  final thisLast = trip.last['stop_id'] as String;
                  if (thisLast == referenceLast || thisFirst == referenceFirst) {
                    allFirstStopIds.add(thisFirst);
                    allLastStopIds.add(thisLast);
                  }
                }
              }
              for (final st in longestTrip) {
                orderedStopIds.add(st['stop_id'] as String);
              }
            }'''

if old_trip_stops in content:
    content = content.replace(old_trip_stops, new_trip_stops)
    with open('lib/pages/transport_lines_details_page.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("done details")
else:
    print("not found details")
