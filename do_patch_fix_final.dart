import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync();

  content = content.replaceAll(
    '  List<Marker> _cachedBusMarkers = [];\n  List<Marker> _cachedFerryMarkers = [];\n  List<Polyline<int>> _cachedShapePolylines = [];\n  Set<String> _routeStopIds = {};',
    '''  List<Marker> _cachedBusMarkers = [];
  List<Marker> _cachedFerryMarkers = [];
  List<Polyline<int>> _cachedShapePolylines = [];
  Set<String> _routeStopIds = {};

  final Map<String, bool> _isTrainCache = {};
  final Map<String, bool> _isMetroCache = {};
  final Map<String, bool> _isShapeTrainCache = {};
  final Map<String, bool> _isShapeMetroCache = {};
  final Map<String, String?> _routeIconCache = {};'''
  );

  content = content.replaceAll(
'''  String? _getRouteIcon(String lineName) {
    if (lineName.isEmpty) return null;
    final firstLine = lineName.split(', ').first;
    try {
      final route = allRoutes
          .where(
            (r) => r.longName == firstLine || r.shortName == firstLine,
          )
          .firstOrNull;
      return route?.routeIcon;
    } catch (e) {
      return null;
    }
  }''',
'''  String? _getRouteIcon(String lineName) {
    if (lineName.isEmpty) return null;
    if (_routeIconCache.containsKey(lineName)) return _routeIconCache[lineName];
    final firstLine = lineName.split(', ').first;
    try {
      final route = allRoutes
          .where(
            (r) => r.longName == firstLine || r.shortName == firstLine,
          )
          .firstOrNull;
      final icon = route?.routeIcon;
      _routeIconCache[lineName] = icon;
      return icon;
    } catch (e) {
      return null;
    }
  }'''
  );

  content = content.replaceAll(
'''  bool _isStopMetro(gtfs.Stop stop) {
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
          return true;
        }
      }
    }
    return false;
  }''',
'''  bool _isStopMetro(gtfs.Stop stop) {
    if (_isMetroCache.containsKey(stop.stopId)) return _isMetroCache[stop.stopId]!;
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
  }'''
  );

  content = content.replaceAll(
'''  bool _isStopTrain(gtfs.Stop stop) {
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
          return true;
        }
      }
    }
    return false;
  }''',
'''  bool _isStopTrain(gtfs.Stop stop) {
    if (_isTrainCache.containsKey(stop.stopId)) return _isTrainCache[stop.stopId]!;
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
  }'''
  );

  content = content.replaceAll(
'''  bool _isShapeTrain(ShapeSegment shape) {
    if (shape.routeId == null) return false;
    final rId = shape.routeId!
        .replaceAll('\uFEFF', '')
        .toUpperCase(); // Avoid BOM issues
    final route = allRoutes
        .where((r) => r.routeId.replaceAll('\uFEFF', '').toUpperCase() == rId)
        .firstOrNull;
    return route?.type == '2';
  }''',
'''  bool _isShapeTrain(ShapeSegment shape) {
    if (shape.routeId == null) return false;
    if (_isShapeTrainCache.containsKey(shape.routeId)) return _isShapeTrainCache[shape.routeId]!;
    final rId = shape.routeId!
        .replaceAll('\uFEFF', '')
        .toUpperCase(); // Avoid BOM issues
    final route = allRoutes
        .where((r) => r.routeId.replaceAll('\uFEFF', '').toUpperCase() == rId)
        .firstOrNull;
    final isTrain = route?.type == '2';
    _isShapeTrainCache[shape.routeId!] = isTrain;
    return isTrain;
  }'''
  );

  content = content.replaceAll(
'''  bool _isShapeMetro(ShapeSegment shape) {
    if (shape.routeId == null) return false;
    final rId = shape.routeId!.replaceAll('\uFEFF', '').toUpperCase();
    final route = allRoutes
        .where((r) => r.routeId.replaceAll('\uFEFF', '').toUpperCase() == rId)
        .firstOrNull;
    return route?.type == '1';
  }''',
'''  bool _isShapeMetro(ShapeSegment shape) {
    if (shape.routeId == null) return false;
    if (_isShapeMetroCache.containsKey(shape.routeId)) return _isShapeMetroCache[shape.routeId]!;
    final rId = shape.routeId!.replaceAll('\uFEFF', '').toUpperCase();
    final route = allRoutes
        .where((r) => r.routeId.replaceAll('\uFEFF', '').toUpperCase() == rId)
        .firstOrNull;
    final isMetro = route?.type == '1';
    _isShapeMetroCache[shape.routeId!] = isMetro;
    return isMetro;
  }'''
  );

  file.writeAsStringSync(content);
  print('Done patching!');
}