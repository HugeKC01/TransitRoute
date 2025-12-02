import 'package:route/services/gtfs_models.dart' as gtfs;

const String kMrtSrtFarePrefix = 'mrtSrt|';
const String kMrtSrtCountSuffix = '|count';
const String kMrtSrtPriceSuffix = '|price';
const String kMrtSrtTotalKey = 'mrtSrtTotal';

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

  Map<String, int> calculateFare(
    List<gtfs.Stop> routeStops, {
    required String? Function(String stopId) lineNameResolver,
  }) {
    int mCount = 0;
    int sCount = 0;
    if (routeStops.length <= 1) {
      return {
        'mCount': 0,
        'sCount': 0,
        'mPrice': 0,
        'sPrice': 0,
        kMrtSrtTotalKey: 0,
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

    final breakdown = {
      'mCount': mCount,
      'sCount': sCount,
      'mPrice': mPrice,
      'sPrice': sPrice,
    };

    final mrtSrtTotals = _calculateMrtSrtFares(
      routeStops,
      lineNameResolver,
    );
    total += mrtSrtTotals.total;
    breakdown.addAll(mrtSrtTotals.entries);
    breakdown[kMrtSrtTotalKey] = mrtSrtTotals.total;
    breakdown['total'] = total;
    return breakdown;
  }

  _MrtSrtFareResult _calculateMrtSrtFares(
    List<gtfs.Stop> routeStops,
    String? Function(String stopId) lineNameResolver,
  ) {
    if (routeStops.length <= 1) {
      return const _MrtSrtFareResult(total: 0, entries: {});
    }
    final counts = <String, int>{};
    for (int i = 0; i < routeStops.length - 1; i++) {
      final current = routeStops[i];
      final next = routeStops[i + 1];
      final lineName = _resolveLineName(
        current.stopId,
        next.stopId,
        lineNameResolver,
      );
      if (lineName == null) continue;
      counts[lineName] = (counts[lineName] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      return const _MrtSrtFareResult(total: 0, entries: {});
    }

    final entries = <String, int>{};
    int total = 0;
    counts.forEach((lineName, count) {
      if (!_isMrtOrSrtLine(lineName)) return;
      final ladderSteps = count > 8 ? 8 : count;
      final price = _fareDataMap['m$ladderSteps'] ?? 0;
      if (price <= 0 && count <= 0) return;
      entries[_lineKey(lineName, kMrtSrtCountSuffix)] = count;
      entries[_lineKey(lineName, kMrtSrtPriceSuffix)] = price;
      total += price;
    });
    return _MrtSrtFareResult(total: total, entries: entries);
  }

  String? _resolveLineName(
    String currentStopId,
    String nextStopId,
    String? Function(String stopId) lineNameResolver,
  ) {
    final currentLine = lineNameResolver(currentStopId);
    if (_isMrtOrSrtLine(currentLine)) return currentLine;
    final nextLine = lineNameResolver(nextStopId);
    if (_isMrtOrSrtLine(nextLine)) return nextLine;
    if (currentLine != null && _looksLikeTransitLine(currentLine)) {
      return currentLine;
    }
    if (nextLine != null && _looksLikeTransitLine(nextLine)) {
      return nextLine;
    }
    return null;
  }

  String _lineKey(String lineName, String suffix) {
    return '$kMrtSrtFarePrefix$lineName$suffix';
  }

  bool _isMrtOrSrtLine(String? lineName) {
    if (lineName == null) return false;
    final upper = lineName.toUpperCase();
    return upper.contains('MRT') || upper.contains('SRT');
  }

  bool _looksLikeTransitLine(String? lineName) {
    if (lineName == null || lineName.isEmpty) return false;
    final upper = lineName.toUpperCase();
    return upper.contains('LINE');
  }
}

class _MrtSrtFareResult {
  const _MrtSrtFareResult({required this.total, required this.entries});

  final int total;
  final Map<String, int> entries;
}
