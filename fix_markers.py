with open("lib/main.dart", "r") as f:
    code = f.read()

start = code.find("if (showBusStops)")
end = code.find("if (filteredRailStops.isNotEmpty)")

new_code = code[:start] + """if (showBusStops)
              MarkerLayer(markers: _cachedBusMarkers),
            if (showFerryStops)
              MarkerLayer(markers: _cachedFerryMarkers),
            """ + code[end:]

with open("lib/main.dart", "w") as f:
    f.write(new_code)
