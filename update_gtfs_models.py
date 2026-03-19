import os
with open('lib/services/gtfs_models.dart', 'r') as f:
    content = f.read()

snippet = """
class BusRouteInfo {
  final String routeShortName;
  final String typeId;
  final bool isExpressway;

  BusRouteInfo({
    required this.routeShortName,
    required this.typeId,
    required this.isExpressway,
  });
}
"""

if "class BusRouteInfo" not in content:
    with open('lib/services/gtfs_models.dart', 'a') as f:
        f.write('\n' + snippet)
