import 'package:route/services/gtfs_models.dart' as gtfs;

class FareCalculator {
  Map<String, String> _fareTypeMap = const {};
  Map<String, int> _fareDataMap = const {};

  void updateData({
    Map<String, String>? fareTypeMap,
    Map<String, int>? fareDataMap,
  }) {
    if (fareTypeMap != null) {
      _fareTypeMap = Map<String, String>.from(fareTypeMap);
    }
    if (fareDataMap != null) {
      _fareDataMap = Map<String, int>.from(fareDataMap);
    }
  }

  Map<String, int> calculateFare(List<gtfs.Stop> routeStops) {
    int mCount = 0;
    int sCount = 0;
    if (routeStops.length <= 1) {
      return {
        'mCount': 0,
        'sCount': 0,
        'mPrice': 0,
        'sPrice': 0,
        'total': 0,
      };
    }

    final Map<int, int> specialIndexExtra = {};
    final Map<int, String> specialStatusOverride = {};
    for (int i = 0; i < routeStops.length - 1; i++) {
      final a = routeStops[i].stopId.trim();
      final b = routeStops[i + 1].stopId.trim();
      if ((a == 'N5' && b == 'N7') || (a == 'N7' && b == 'N5')) {
        specialIndexExtra[i] = (specialIndexExtra[i] ?? 0) + 2;
      }
      if ((a == 'N8' && b == 'N9') ||
          (a == 'S8' && b == 'S9') ||
          (a == 'E9' && b == 'E10')) {
        specialStatusOverride[i] = 's';
      }
    }

    final stopsToCount = routeStops.sublist(0, routeStops.length - 1);
    for (int i = 0; i < stopsToCount.length; i++) {
      final currId = stopsToCount[i].stopId.trim();
      final extra = specialIndexExtra[i];
      if (extra != null) {
        mCount += extra;
        continue;
      }
      final override = specialStatusOverride[i];
      final status = override ?? _fareTypeMap[currId];
      if (status == 'm') {
        mCount++;
      } else if (status == 's') {
        sCount++;
      }
    }

    if (mCount > 8) mCount = 8;
    if (sCount > 13) sCount = 13;

    final mPrice = _fareDataMap['m$mCount'] ?? 0;
    final sPrice = _fareDataMap['s$sCount'] ?? 0;
    int total = mPrice + sPrice;
    if (total > 65) total = 65;
    return {
      'mCount': mCount,
      'sCount': sCount,
      'mPrice': mPrice,
      'sPrice': sPrice,
      'total': total,
    };
  }
}
