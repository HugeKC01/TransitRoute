import re

with open("lib/main.dart", "r") as f:
    content = f.read()

# Add import
if "import 'package:flutter_svg/flutter_svg.dart';" not in content:
    content = content.replace(
        "import 'package:flutter_map/flutter_map.dart';",
        "import 'package:flutter_map/flutter_map.dart';\nimport 'package:flutter_svg/flutter_svg.dart';"
    )

pattern = r"""\s*\.map\(\s*\(stop\) => Marker\(\s*point: LatLng\(stop\.lat, stop\.lon\),\s*width:\s*\(stop\.stopId == startId \|\| stop\.stopId == destId\)\s*\?\s*railSelectedSize\s*:\s*railBaseSize,\s*height:\s*\(stop\.stopId == startId \|\| stop\.stopId == destId\)\s*\?\s*railSelectedSize\s*:\s*railBaseSize,\s*child: GestureDetector\(\s*onTap: \(\) => _showStopDetails\(context, stop\),\s*child: Tooltip\(\s*message: _stopDisplayLabel\(stop\),\s*child: Container\("""

rep = """                      .map(
                        (stop) {
                          final lineName = _getLineName(stop.stopId);
                          final routeIcon = lineName != null ? _getRouteIcon(lineName) : null;
                          final isSelected = stop.stopId == startId || stop.stopId == destId;
                          final dim = activeSegments.isNotEmpty &&
                              !routeStopIds.contains(stop.stopId) &&
                              !isSelected;

                          return Marker(
                            point: LatLng(stop.lat, stop.lon),
                            width: isSelected ? railSelectedSize * 1.5 : railBaseSize * 1.5,
                            height: isSelected ? railSelectedSize * 1.5 : railBaseSize * 1.5,
                            child: GestureDetector(
                              onTap: () => _showStopDetails(context, stop),
                              child: Tooltip(
                                message: _stopDisplayLabel(stop),
                                child: routeIcon != null && routeIcon.isNotEmpty
                                    ? Container(
                                        decoration: BoxDecoration(
                                          color: stop.stopId == startId
                                              ? Colors.greenAccent.withValues(alpha: 0.85)
                                              : stop.stopId == destId
                                              ? Colors.redAccent.withValues(alpha: 0.85)
                                              : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: dim ? Colors.grey.shade500 : _getLineColor(stop.stopId),
                                            width: isSelected ? railSelectedBorderWidth : railBorderWidth,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: Opacity(
                                            opacity: dim ? 0.4 : 1.0,
                                            child: Padding(
                                              padding: EdgeInsets.all(isSelected ? 3.0 : 2.0),
                                              child: SvgPicture.asset(routeIcon, fit: BoxFit.contain),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container("""

if re.search(pattern, content):
    content = re.sub(pattern, rep, content, count=1)
    
    parts = content.split("SvgPicture.asset(routeIcon, fit: BoxFit.contain)")
    if len(parts) == 2:
        part2 = parts[1]
        
        match = re.search(r"\)\s*,\s*\)\s*,\s*\)\s*,\s*\)\s*,\s*\)\s*,\s*\)\s*,\s*\)\s*\.toList\(\),", part2)
        if match:
            new_end = "),\n                                ),\n                              ),\n                            ),\n                          );\n                        },\n                      )\n                      .toList(),"
            part2 = part2[:match.start()] + new_end + part2[match.end():]
            
            content = parts[0] + "SvgPicture.asset(routeIcon, fit: BoxFit.contain)" + part2
            with open("lib/main.dart", "w") as f:
                f.write(content)
            print("Success")
        else:
            print("Failed to find end pattern")
    else:
        print("Failed to split by SvgPicture")

else:
    print("Failed to find start pattern!")
