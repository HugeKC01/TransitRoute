import re

with open('lib/main.dart', 'r') as f:
    code = f.read()

# 1. Map Layers button
code = code.replace(
    '              _buildFilterMenu(isWide),',
    '              if (directionOptions.isEmpty) _buildFilterMenu(isWide),'
)

# 2. Polyline hitValue missed items.
build_rp_start = code.find('List<Polyline<int>> _buildRoutePolylines(')
build_rp_end = code.find('void _addOffsetConnectionLine(', build_rp_start)

build_rp_str = code[build_rp_start:build_rp_end]

build_rp_str = build_rp_str.replace('Polyline(', 'Polyline<int>(hitValue: hitValue, ')
build_rp_str = build_rp_str.replace('Polyline<int>(', 'Polyline<int>(hitValue: hitValue, ')
build_rp_str = build_rp_str.replace('<Polyline<int>>[hitValue: hitValue, ', '<Polyline<int>>[')
build_rp_str = build_rp_str.replace('Polyline<int>(hitValue: hitValue, hitValue: hitValue, ', 'Polyline<int>(hitValue: hitValue, ')

# 3. Shape connection logic
loop_shapes_start = build_rp_str.find('          bool foundShape = false;\n          // Look for a shape that connects stopA and stopB\n          for (final shape in shapeSegments) {')
fix_shapes = '''          final targetId = segment.routeId ?? lineName.split(' ').first;
          final exactShapeId = segment.shapeId;

          List<ShapeSegment> validShapes = [];
          if (exactShapeId != null && exactShapeId.isNotEmpty) {
            validShapes = shapeSegments.where((s) => s.shapeId == exactShapeId).toList();
          }
          if (validShapes.isEmpty && targetId.isNotEmpty) {
            validShapes = shapeSegments.where((s) => s.routeId == targetId || s.shapeId.contains(targetId)).toList();
          }
          if (validShapes.isEmpty) {
            validShapes = shapeSegments;
          }

          bool foundShape = false;
          // Look for a shape that connects stopA and stopB
          for (final shape in validShapes) {'''

if loop_shapes_start != -1:
    loop_shapes_repl = build_rp_str[loop_shapes_start : loop_shapes_start + len('          bool foundShape = false;\n          // Look for a shape that connects stopA and stopB\n          for (final shape in shapeSegments) {')]
    build_rp_str = build_rp_str.replace(loop_shapes_repl, fix_shapes)

geom_fb = '''          } // Geometric fallback for buses
          if (!foundShape) {
            final targetId = segment.routeId ?? lineName.split(' ').first;
            final exactShapeId = segment.shapeId;'''
geom_fb_fixed = '''          } // Geometric fallback for buses
          if (!foundShape) {
            // targetId and exactShapeId already computed'''
build_rp_str = build_rp_str.replace(geom_fb, geom_fb_fixed)

code = code[:build_rp_start] + build_rp_str + code[build_rp_end:]

# 4. Hide shapes when plan route mode
hide_shape_orig = '''            return [
              Polyline<int>(
                points: s.points,
                color: Colors.grey.withValues(alpha: 0.5),
                strokeWidth: 4.0,
              ),
            ];'''
hide_shape_new = 'true ? [] : [];// hidden'
code = code.replace(hide_shape_orig, hide_shape_new)

# We can also do the same when rendering _cachedBusMarkers
# To do so we replace activeRouteSegments.isNotEmpty checking color assignment
# No, they want to hide stops totally.
# Let's verify what `_cachedBusMarkers` logic looks like.
old_bus_markers = '''    _cachedBusMarkers = busStops.map((stop) {'''
new_bus_markers = '''    _cachedBusMarkers = busStops.where((stop) {
      if (activeRouteSegments.isNotEmpty && !_routeStopIds.contains(stop.stopId)) return false;
      return true;
    }).map((stop) {'''
code = code.replace(old_bus_markers, new_bus_markers)

old_ferry_markers = '''    _cachedFerryMarkers = ferryStops.map((stop) {'''
new_ferry_markers = '''    _cachedFerryMarkers = ferryStops.where((stop) {
      if (activeRouteSegments.isNotEmpty && !_routeStopIds.contains(stop.stopId)) return false;
      return true;
    }).map((stop) {'''
code = code.replace(old_ferry_markers, new_ferry_markers)

# filteredRailStops logic in _buildMap
old_rail_stops = '''    final filteredRailStops = railStops.where((stop) {
      final isTrain = _isStopTrain(stop);
      final isMetro = _isStopMetro(stop);

      if (isTrain && !_showTrainPins) return false;
      if (isMetro && !_showMetroPins) return false;
      if (!isTrain && !isMetro) {
        // Fallback if type isn't correctly identified, use metro fallback as before
        if (!_showMetroPins) return false;
      }
      return true;
    }).toList();'''
new_rail_stops = '''    final filteredRailStops = railStops.where((stop) {
      final isTrain = _isStopTrain(stop);
      final isMetro = _isStopMetro(stop);

      if (activeSegments.isNotEmpty && !_routeStopIds.contains(stop.stopId) && stop.stopId != startId && stop.stopId != destId) return false;

      if (isTrain && !_showTrainPins) return false;
      if (isMetro && !_showMetroPins) return false;
      if (!isTrain && !isMetro) {
        // Fallback if type isn't correctly identified, use metro fallback as before
        if (!_showMetroPins) return false;
      }
      return true;
    }).toList();'''
code = code.replace(old_rail_stops, new_rail_stops)

with open('lib/main.dart', 'w') as f:
    f.write(code)
print("Done")