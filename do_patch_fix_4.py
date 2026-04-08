import re

with open('lib/main.dart', 'r') as f:
    text = f.read()

# Make sure it catches `color: isActive ? lineColor : lineColor.withValues...` correctly
lines_to_replace = """        } else {
          polylines.add(
            Polyline<int>(
              hitValue: hitValue,
              points: points,
              color: isActive ? lineColor : lineColor.withValues(alpha: 0.2),
              strokeWidth: isActive ? width : (width * 0.7),
              pattern: pattern ?? const StrokePattern.solid(),
            ),
          );
        }"""

new_lines = """        } else {
          polylines.add(
            Polyline<int>(
              hitValue: hitValue,
              points: points,
              color: isActive ? lineColor : Colors.grey,
              borderStrokeWidth: isActive ? 0.0 : 2.0,
              borderColor: isActive ? Colors.transparent : lineColor,
              strokeWidth: isActive ? width : 4.0,
              pattern: pattern ?? const StrokePattern.solid(),
            ),
          );
        }"""

if lines_to_replace in text:
    text = text.replace(lines_to_replace, new_lines)

# Now for the other Polylines:
# 1. Train routes non-active?
train_1 = """        if (isTrainSegment) {
          polylines.add(
            Polyline<int>(
              hitValue: hitValue,
              points: points,
              color: const Color(0xFF6B4226),
              strokeWidth: 7.0,
            ),
          );
          polylines.add(
            Polyline<int>(
              hitValue: hitValue,
              points: points,
              color: Colors.white,
              strokeWidth: 4.0,
              pattern: StrokePattern.dashed(segments: [10.0, 10.0]),
            ),
          );
        } else {"""
train_2 = """        if (isTrainSegment) {
          polylines.add(
            Polyline<int>(
              hitValue: hitValue,
              points: points,
              color: isActive ? const Color(0xFF6B4226) : Colors.grey,
              borderStrokeWidth: isActive ? 0.0 : 2.0,
              borderColor: isActive ? Colors.transparent : const Color(0xFF6B4226),
              strokeWidth: 7.0,
            ),
          );
          polylines.add(
            Polyline<int>(
              hitValue: hitValue,
              points: points,
              color: isActive ? Colors.white : Colors.grey.shade300,
              strokeWidth: 4.0,
              pattern: StrokePattern.dashed(segments: [10.0, 10.0]),
            ),
          );
        } else {"""
text = text.replace(train_1, train_2)

# Shape connections:
shape_1 = """              polylines.add(
                Polyline<int>(
                  hitValue: hitValue,
                  points: shapePoints,
                  color: isActive
                      ? lineColor
                      : lineColor.withValues(alpha: 0.2),
                  strokeWidth: 6.0,
                ),
              );"""
shape_2 = """              polylines.add(
                Polyline<int>(
                  hitValue: hitValue,
                  points: shapePoints,
                  color: isActive ? lineColor : Colors.grey,
                  borderStrokeWidth: isActive ? 0.0 : 2.0,
                  borderColor: isActive ? Colors.transparent : lineColor,
                  strokeWidth: isActive ? 6.0 : 4.0,
                ),
              );"""
text = text.replace(shape_1, shape_2)

shape_a_1 = """                  polylines.add(
                    Polyline<int>(
                      hitValue: hitValue,
                      points: shapePoints,
                      color: isActive
                          ? lineColor
                          : lineColor.withValues(alpha: 0.2),
                      strokeWidth: 6.0,
                    ),
                  );"""
shape_a_2 = """                  polylines.add(
                    Polyline<int>(
                      hitValue: hitValue,
                      points: shapePoints,
                      color: isActive ? lineColor : Colors.grey,
                      borderStrokeWidth: isActive ? 0.0 : 2.0,
                      borderColor: isActive ? Colors.transparent : lineColor,
                      strokeWidth: isActive ? 6.0 : 4.0,
                    ),
                  );"""
text = text.replace(shape_a_1, shape_a_2)

# Fallback line connection:
line_poly_1 = """              _linePolyline(
                LatLng(route[i - 1].lat, route[i - 1].lon),
                LatLng(route[i].lat, route[i].lon),
                lineColor,"""
line_poly_2 = """              _linePolyline(
                LatLng(route[i - 1].lat, route[i - 1].lon),
                LatLng(route[i].lat, route[i].lon),
                isActive ? lineColor : Colors.grey,"""
text = text.replace(line_poly_1, line_poly_2)

line_poly_func_1 = """  Polyline<int> _linePolyline(
    LatLng from,
    LatLng to,
    Color color, {
    int? hitValue,
    bool isActive = true,
  }) {
    return Polyline<int>(
      hitValue: hitValue,
      points: [from, to],
      color: color,
      strokeWidth: 6.0,
    );
  }"""

line_poly_func_2 = """  Polyline<int> _linePolyline(
    LatLng from,
    LatLng to,
    Color color, {
    int? hitValue,
    bool isActive = true,
    Color? borderColor,
  }) {
    return Polyline<int>(
      hitValue: hitValue,
      points: [from, to],
      color: color,
      borderStrokeWidth: isActive ? 0.0 : 2.0,
      borderColor: isActive ? Colors.transparent : borderColor ?? Colors.transparent,
      strokeWidth: isActive ? 6.0 : 4.0,
    );
  }"""
text = text.replace(line_poly_func_1, line_poly_func_2)

# Oh wait, passed borderColor above in fallback?
# I need to fix the fallback passing borderColor. Let's do it using regex to be safe.
# Actually I can just do another replace.

with open('lib/main.dart', 'w') as f:
    f.write(text)

