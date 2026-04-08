with open("lib/main.dart", "r") as f:
    code = f.read()

start = code.find("if (shapeSegments.isNotEmpty)")
end = code.find("if (showBusStops)")

new_code = code[:start] + """if (shapeSegments.isNotEmpty)
              PolylineLayer(polylines: _cachedShapePolylines),
            """ + code[end:]

with open("lib/main.dart", "w") as f:
    f.write(new_code)
