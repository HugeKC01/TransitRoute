import re

with open('lib/services/fare_calculator.dart', 'r') as f:
    text = f.read()

# Add _busRouteInfoMap
text = text.replace(
    '  Map<String, String> _ferryZones = const {};',
    '  Map<String, String> _ferryZones = const {};\n  Map<String, gtfs.BusRouteInfo> _busRouteInfoMap = const {};'
)

# Update updateData
text = text.replace(
    '    Map<String, String>? ferryZones,\n  }) {',
    '    Map<String, String>? ferryZones,\n    Map<String, gtfs.BusRouteInfo>? busRouteInfoMap,\n  }) {'
)
text = text.replace(
    '    if (ferryZones != null) {\n      _ferryZones = Map<String, String>.from(ferryZones);\n    }',
    '    if (ferryZones != null) {\n      _ferryZones = Map<String, String>.from(ferryZones);\n    }\n    if (busRouteInfoMap != null) {\n      _busRouteInfoMap = Map<String, gtfs.BusRouteInfo>.from(busRouteInfoMap);\n    }'
)

with open('lib/services/fare_calculator.dart', 'w') as f:
    f.write(text)
