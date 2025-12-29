import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;

class ShapeSegment {
  final String shapeId;
  final String? routeId;
  final List<LatLng> points;
  final List<String?> pointNames;
  final Color color;

  const ShapeSegment({
    required this.shapeId,
    required this.points,
    this.pointNames = const <String?>[],
    required this.color,
    this.routeId,
  });
}

class GtfsShapesService {
  Future<List<ShapeSegment>> loadSegments({
    required String shapesAsset,
    required Map<String, Color> routeColors,
    String? tripsAsset,
    Map<String, gtfs.Trip>? tripMap,
  }) async {
    final shapes = await _parseShapes(shapesAsset);
    Map<String, String> shapeToRoute = {};
    Map<String, Color> shapeToColor = {};
    if (tripMap != null) {
      for (final t in tripMap.values) {
        final sid = t.shapeId;
        if (sid == null || sid.isEmpty) continue;
        // map shape -> route
        shapeToRoute.putIfAbsent(sid, () => t.routeId);
        // map shape -> color (Trip.shapeColor is Color?)
        if (t.shapeColor != null) {
          shapeToColor.putIfAbsent(sid, () => t.shapeColor!);
        }
      }
    } else if (tripsAsset != null) {
      final meta = await _parseShapeTripMeta(tripsAsset);
      shapeToRoute = meta.shapeToRoute;
      shapeToColor = meta.shapeToColor;
    }

    final segments = <ShapeSegment>[];
    for (final entry in shapes.entries) {
      final shapeId = entry.key;
      final seqPoints = entry.value;
      if (seqPoints.length < 2) continue;
      final points = seqPoints.map((sp) => sp.point).toList();
      final pointNames = seqPoints.map((sp) => sp.name).toList();
      final routeId = shapeToRoute[shapeId];
      final color = shapeToColor[shapeId] ??
          ((routeId != null && routeColors.containsKey(routeId))
              ? routeColors[routeId]!
              : _pickFallbackColor(shapeId, routeColors));
      segments.add(
        ShapeSegment(
          shapeId: shapeId,
          routeId: routeId,
          points: points,
          pointNames: pointNames,
          color: color,
        ),
      );
    }
    return segments;
  }

  Future<Map<String, List<_SeqPoint>>> _parseShapes(String assetPath) async {
    final text = await rootBundle.loadString(assetPath);
    if (text.trim().isEmpty) return <String, List<_SeqPoint>>{};
    final lines = const LineSplitter()
        .convert(text)
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return <String, List<_SeqPoint>>{};

    final header = _splitCsvLine(lines.first)
        .map((s) => s.trim().toLowerCase())
        .toList();
    final idxShapeId = header.indexOf('shape_id');
    final idxLat = header.indexOf('shape_pt_lat');
    final idxLon = header.indexOf('shape_pt_lon');
    final idxSeq = header.indexOf('shape_pt_sequence');
    final idxName = header.indexWhere((h) => h == 'shape_pt_name' || h == 'shape_name' || h == 'shape_pt_label');
    if (idxShapeId < 0 || idxLat < 0 || idxLon < 0) return <String, List<_SeqPoint>>{};
    final byShape = <String, List<_SeqPoint>>{};
    for (int i = 1; i < lines.length; i++) {
      final row = _splitCsvLine(lines[i]);
      if (row.length <= idxLon) continue;
      final id = row[idxShapeId].trim();
      final lat = double.tryParse(row[idxLat].trim());
      final lon = double.tryParse(row[idxLon].trim());
      int seq = 0;
      if (idxSeq >= 0 && row.length > idxSeq) {
        seq = int.tryParse(row[idxSeq].trim()) ?? i;
      } else {
        seq = i;
      }
      String? name;
      if (idxName >= 0 && row.length > idxName) {
        final n = row[idxName].trim();
        name = n.isEmpty ? null : n;
      }
      if (id.isEmpty || lat == null || lon == null) continue;
      byShape.putIfAbsent(id, () => <_SeqPoint>[]).add(
            _SeqPoint(seq: seq, point: LatLng(lat, lon), name: name),
          );
    }

    final result = <String, List<_SeqPoint>>{};
    for (final e in byShape.entries) {
      final pts = e.value..sort((a, b) => a.seq.compareTo(b.seq));
      result[e.key] = pts.toList();
    }
    return result;
  }

  Future<_ShapeTripMeta> _parseShapeTripMeta(String assetPath) async {
    final text = await rootBundle.loadString(assetPath);
    if (text.trim().isEmpty) return const _ShapeTripMeta(shapeToRoute: {}, shapeToColor: {});
    final lines = const LineSplitter()
        .convert(text)
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const _ShapeTripMeta(shapeToRoute: {}, shapeToColor: {});

    final header = _splitCsvLine(lines.first)
        .map((s) => s.trim().toLowerCase())
        .toList();
    final idxRouteId = header.indexOf('route_id');
    final idxShapeId = header.indexOf('shape_id');
    final idxShapeColor = header.indexWhere(
      (value) => value == 'shape_color' || value == 'shape-color',
    );
    if (idxRouteId < 0 || idxShapeId < 0) {
      return const _ShapeTripMeta(shapeToRoute: {}, shapeToColor: {});
    }

    final mapRoute = <String, String>{};
    final mapColor = <String, Color>{};
    for (int i = 1; i < lines.length; i++) {
      final row = _splitCsvLine(lines[i]);
      if (row.length <= idxShapeId) continue;
      final routeId = row[idxRouteId].trim();
      final shapeId = row[idxShapeId].trim();
      if (routeId.isEmpty || shapeId.isEmpty) continue;
      // Trip may appear many times with same shape_id; mapping is straightforward.
      mapRoute.putIfAbsent(shapeId, () => routeId);
      if (idxShapeColor >= 0 && row.length > idxShapeColor) {
        final cstr = row[idxShapeColor].trim();
        final c = _parseHexColor(cstr);
        if (c != null) mapColor[shapeId] = c;
      }
    }
    return _ShapeTripMeta(shapeToRoute: mapRoute, shapeToColor: mapColor);
  }

  List<String> _splitCsvLine(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    out.add(buf.toString());
    return out;
  }

  Color _pickFallbackColor(String shapeId, Map<String, Color> routeColors) {
    // Try to find a color by matching routeId prefix in shapeId
    for (final entry in routeColors.entries) {
      if (shapeId.toUpperCase().contains(entry.key.toUpperCase())) {
        return entry.value;
      }
    }
    // Deterministic fallback color from shapeId hash.
    final hash = shapeId.hashCode & 0xFFFFFF;
    return Color(0xFF000000 | hash).withValues(alpha: 1.0);
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    var s = hex.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('#')) s = s.substring(1);
    // If 6 digits, assume RRGGBB with implicit FF alpha
    if (s.length == 6) {
      return Color(int.parse('0xFF$s'));
    }
    // If 8 digits, assume AARRGGBB
    if (s.length == 8) {
      return Color(int.parse('0x$s'));
    }
    return null;
  }
}

class _SeqPoint {
  final int seq;
  final LatLng point;
  final String? name;
  const _SeqPoint({required this.seq, required this.point, this.name});
}

class _ShapeTripMeta {
  final Map<String, String> shapeToRoute;
  final Map<String, Color> shapeToColor;
  const _ShapeTripMeta({required this.shapeToRoute, required this.shapeToColor});
}
