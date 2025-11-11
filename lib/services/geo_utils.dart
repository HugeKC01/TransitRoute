import 'dart:math' as math;

import 'package:route/services/gtfs_models.dart' as gtfs;

double haversine(double lat1, double lon1, double lat2, double lon2) {
  const radius = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180.0;
  final dLon = (lon2 - lon1) * math.pi / 180.0;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180.0) *
          math.cos(lat2 * math.pi / 180.0) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return radius * c;
}

double routeDistanceMeters(List<gtfs.Stop> stops) {
  double total = 0;
  for (int i = 0; i < stops.length - 1; i++) {
    total += haversine(
      stops[i].lat,
      stops[i].lon,
      stops[i + 1].lat,
      stops[i + 1].lon,
    );
  }
  return total;
}
