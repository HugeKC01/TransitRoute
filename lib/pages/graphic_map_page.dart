import 'package:flutter/material.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;
import 'package:route/services/gtfs_shapes.dart';

class GraphicMapPage extends StatefulWidget {
  final List<gtfs.Stop> railStops;
  final List<ShapeSegment> shapeSegments;

  const GraphicMapPage({
    super.key,
    required this.railStops,
    required this.shapeSegments,
  });

  @override
  State<GraphicMapPage> createState() => _GraphicMapPageState();
}

class _GraphicMapPageState extends State<GraphicMapPage> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      const mapSize = 4000.0;
      final dx = (size.width - mapSize) / 2;
      final dy = (size.height - mapSize) / 2;
      _transformationController.value = Matrix4.translationValues(dx, dy, 0.0);
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transit System Map')),
      body: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.1,
        maxScale: 10.0,
        boundaryMargin: const EdgeInsets.all(4000),
        constrained: false,
        child: CustomPaint(
          size: const Size(4000, 4000),
          painter: _TransitGraphicPainter(
            railStops: widget.railStops,
            shapeSegments: widget.shapeSegments,
          ),
        ),
      ),
    );
  }
}

class _TransitGraphicPainter extends CustomPainter {
  final List<gtfs.Stop> railStops;
  final List<ShapeSegment> shapeSegments;

  _TransitGraphicPainter({
    required this.railStops,
    required this.shapeSegments,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (railStops.isEmpty && shapeSegments.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLon = double.infinity;
    double maxLon = -double.infinity;

    for (final stop in railStops) {
      if (stop.lat < minLat) minLat = stop.lat;
      if (stop.lat > maxLat) maxLat = stop.lat;
      if (stop.lon < minLon) minLon = stop.lon;
      if (stop.lon > maxLon) maxLon = stop.lon;
    }

    for (final segment in shapeSegments) {
      for (final point in segment.points) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLon) minLon = point.longitude;
        if (point.longitude > maxLon) maxLon = point.longitude;
      }
    }

    final latPadding = (maxLat - minLat) * 0.05;
    final lonPadding = (maxLon - minLon) * 0.05;
    minLat -= latPadding;
    maxLat += latPadding;
    minLon -= lonPadding;
    maxLon += lonPadding;

    double getX(double lon) {
      return (lon - minLon) / (maxLon - minLon) * size.width;
    }

    double getY(double lat) {
      return (1 - (lat - minLat) / (maxLat - minLat)) * size.height;
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final segment in shapeSegments) {
      if (segment.points.isEmpty) continue;

      linePaint.color = segment.color;

      final path = Path();
      var first = true;
      for (final point in segment.points) {
        final x = getX(point.longitude);
        final y = getY(point.latitude);

        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, linePaint);
    }

    final stationPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final stationBorderPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final stop in railStops) {
      final x = getX(stop.lon);
      final y = getY(stop.lat);

      const radius = 6.0;
      canvas.drawCircle(Offset(x, y), radius, stationPaint);
      canvas.drawCircle(Offset(x, y), radius, stationBorderPaint);

      final textSpan = TextSpan(
        text: _extractStationName(stop.name),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );

      final foregroundPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      foregroundPainter.layout();

      final textSpanShadow = TextSpan(
        text: _extractStationName(stop.name),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white,
        ),
      );

      final shadowPainter = TextPainter(
        text: textSpanShadow,
        textDirection: TextDirection.ltr,
      );
      shadowPainter.layout();

      const offsetX = 10.0;
      const offsetY = -8.0;

      shadowPainter.paint(canvas, Offset(x + offsetX, y + offsetY));

      foregroundPainter.paint(canvas, Offset(x + offsetX, y + offsetY));
    }
  }

  @override
  bool shouldRepaint(covariant _TransitGraphicPainter oldDelegate) {
    return railStops != oldDelegate.railStops ||
        shapeSegments != oldDelegate.shapeSegments;
  }

  String _extractStationName(String fullName) {
    if (fullName.contains('(')) {
      return fullName.split('(').first.trim();
    }
    return fullName;
  }
}
