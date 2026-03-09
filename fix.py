with open("lib/graphic_map_page.dart", "r") as f:
    c = f.read()

c = c.replace("..translate(dx, dy)", "  ..translate(dx, dy, 0.0)")
c = c.replace("stop.stopLat", "stop.lat")
c = c.replace("stop.stopLon", "stop.lon")
c = c.replace("stop.stopName", "stop.name")
c = c.replace("_parseColor(segment.color)", "segment.color")
c = c.replace("..scale(1.0)", "  ..scale(1.0, 1.0, 1.0)")
c = c.replace("import 'dart:math' as math;", "")

with open("lib/graphic_map_page.dart", "w") as f:
    f.write(c)
