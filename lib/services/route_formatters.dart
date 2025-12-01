import 'package:route/services/direction_service.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;

String formatDistance(double meters) {
  if (meters < 1000) {
    return '${meters.toStringAsFixed(0)} m';
  }
  return '${(meters / 1000).toStringAsFixed(2)} km';
}

List<List<gtfs.Stop>> splitRouteByLine(
  List<gtfs.Stop> route,
  LineNameResolver lineNameResolver,
) {
  if (route.isEmpty) return [];
  final segments = <List<gtfs.Stop>>[];
  var currentSegment = <gtfs.Stop>[route.first];
  var lastLine = lineNameResolver(route.first.stopId) ?? '';
  if (route.first.stopId == 'CEN' && lastLine.isEmpty) {
    for (int j = 1; j < route.length; j++) {
      if (route[j].stopId != 'CEN') {
        final inferred = lineNameResolver(route[j].stopId) ?? '';
        if (inferred.isNotEmpty) {
          lastLine = inferred;
        }
        break;
      }
    }
  }

  String effectiveLineFor(int index) {
    final id = route[index].stopId;
    final inferred = lineNameResolver(id) ?? '';
    if (id == 'CEN') {
      if (lastLine.isNotEmpty) return lastLine;
      for (int j = index + 1; j < route.length; j++) {
        if (route[j].stopId != 'CEN') {
          final future = lineNameResolver(route[j].stopId) ?? '';
          if (future.isNotEmpty) {
            return future;
          }
          break;
        }
      }
    }
    return inferred;
  }

  for (int i = 1; i < route.length; i++) {
    final line = effectiveLineFor(i);
    if (line != lastLine) {
      segments.add(currentSegment);
      currentSegment = [route[i - 1], route[i]];
      lastLine = line;
    } else {
      currentSegment.add(route[i]);
    }
  }
  if (currentSegment.isNotEmpty) {
    segments.add(currentSegment);
  }
  return segments;
}

String resolveSegmentLineName(
  List<gtfs.Stop> segment,
  LineNameResolver lineNameResolver,
) {
  if (segment.isEmpty) {
    return 'Unknown line';
  }
  final firstLine = lineNameResolver(segment.first.stopId);
  if (segment.length == 1) {
    return firstLine ?? 'Unknown line';
  }
  String? fallback;
  for (int i = 1; i < segment.length; i++) {
    final candidate = lineNameResolver(segment[i].stopId);
    if (candidate == null || candidate.isEmpty) {
      continue;
    }
    fallback ??= candidate;
    if (firstLine == null || candidate != firstLine) {
      return candidate;
    }
  }
  return firstLine ?? fallback ?? 'Unknown line';
}

gtfs.Stop? segmentStopMatchingLine(
  List<gtfs.Stop> segment,
  LineNameResolver lineNameResolver,
  String lineName,
) {
  if (segment.isEmpty || lineName.isEmpty) {
    return null;
  }
  for (final stop in segment) {
    final candidate = lineNameResolver(stop.stopId);
    if (candidate == lineName) {
      return stop;
    }
  }
  return null;
}
