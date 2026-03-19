import re
with open('lib/services/direction_service.dart', 'r') as f:
    text = f.read()

text = text.replace(
    'Map<String, String>? ferryZones,\n  }) {',
    'Map<String, String>? ferryZones,\n    Map<String, gtfs.BusRouteInfo>? busRouteInfoMap,\n  }) {'
)
text = text.replace(
    'ferryZones: ferryZones,\n    );',
    'ferryZones: ferryZones,\n      busRouteInfoMap: busRouteInfoMap,\n    );'
)

with open('lib/services/direction_service.dart', 'w') as f:
    f.write(text)
