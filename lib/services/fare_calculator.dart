import 'package:route/services/gtfs_models.dart' as gtfs;

class FareCalculator {
  Map<String, String> _fareTypeMap = const {};      // BTS: stopId → 'm'/'s'
  Map<String, int> _fareDataMap = const {};          // BTS: 'm0','m1'... → ราคา
  Map<String, int> _stopOrderMap = const {};         // MRT/SRT/Gold/ARL: stopId → ลำดับสถานี
  Map<String, List<int>> _fareTableMap = const {};   // non-BTS: "BL10"/"BL10-" → รายการราคา

  void updateData({
    Map<String, String>? fareTypeMap,
    Map<String, int>? fareDataMap,
    Map<String, int>? stopOrderMap,
    Map<String, List<int>>? fareTableMap,
  }) {
    if (fareTypeMap != null) {
      _fareTypeMap = Map<String, String>.from(fareTypeMap);
    }
    if (fareDataMap != null) {
      _fareDataMap = Map<String, int>.from(fareDataMap);
    }
    if (stopOrderMap != null) {
      _stopOrderMap = Map<String, int>.from(stopOrderMap);
    }
    if (fareTableMap != null) {
      _fareTableMap = Map<String, List<int>>.from(fareTableMap);
    }
  }

  // ─────────────────────────────────────────────
  // ตรวจว่า stop นี้เป็นสาย BTS หรือไม่
  // BTS = มีใน _fareTypeMap (CEN, S1-S12, E1-E23, N1-N24, W1, G1-G3)
  // ─────────────────────────────────────────────
  bool _isBtsStop(String stopId) {
    return _fareTypeMap.containsKey(stopId.trim());
  }

  // ─────────────────────────────────────────────
  // แบ่ง route ออกเป็น segment ตามสาย
  // ─────────────────────────────────────────────
  String _lineGroup(String stopId) {
    final id = stopId.trim();
    if (_isBtsStop(id)) return 'BTS';
    final match = RegExp(r'^([A-Za-z]+)').firstMatch(id);
    final prefix = match?.group(1)?.toUpperCase() ?? 'UNKNOWN';

    // Group RW and RN together as they are considered the same line for fare calculation
    if (prefix == 'RW' || prefix == 'RN') {
      return 'RW_RN';
    }

    // Group PK and MT together
    if (prefix == 'PK' || prefix == 'MT') {
      return 'PK_MT';
    }
    
    return prefix;
  }

  List<List<gtfs.Stop>> _splitByLineGroup(List<gtfs.Stop> stops) {
    if (stops.isEmpty) return [];
    final segments = <List<gtfs.Stop>>[];
    var current = <gtfs.Stop>[stops.first];
    var currentGroup = _lineGroup(stops.first.stopId);

    for (int i = 1; i < stops.length; i++) {
      final group = _lineGroup(stops[i].stopId);
      if (group != currentGroup) {
        segments.add(current);
        current = [stops[i]];
        currentGroup = group;
      } else {
        current.add(stops[i]);
      }
    }
    if (current.isNotEmpty) segments.add(current);
    return segments;
  }

  // ─────────────────────────────────────────────
  // คำนวณค่าโดยสาร BTS (logic เดิม)
  // ─────────────────────────────────────────────
  Map<String, int> _calculateBtsFare(List<gtfs.Stop> routeStops) {
    int mCount = 0;
    int sCount = 0;
    if (routeStops.length <= 1) {
      return {'mCount': 0, 'sCount': 0, 'mPrice': 0, 'sPrice': 0, 'total': 0};
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
      final extra = specialIndexExtra[i];
      if (extra != null) {
        mCount += extra;
        continue;
      }
      final currId = stopsToCount[i].stopId.trim();
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

  // ─────────────────────────────────────────────
  // คำนวณค่าโดยสารสายที่ไม่ใช่ BTS โดยใช้ fare_table
  //
  // ขั้นตอน:
  // 1. ดูลำดับสถานีต้นทางและปลายทางจาก _stopOrderMap
  // 2. diff = originOrder - destOrder
  //    · diff < 0 → ไปข้างหน้า → ใช้ row "{originId}-"
  //    · diff > 0 → ถอยหลัง   → ใช้ row "{originId}"
  // 3. ดึงราคาจาก _fareTableMap[ตำแหน่ง absDiff - 1]
  // ─────────────────────────────────────────────
  int _calculateNonBtsFare(List<gtfs.Stop> segment) {
    if (segment.length <= 1) return 0;

    final originId = segment.first.stopId.trim();
    final destId = segment.last.stopId.trim();

    final originOrder = _stopOrderMap[originId];
    final destOrder = _stopOrderMap[destId];

    // ถ้าไม่มีข้อมูลลำดับ ยังไม่คิดค่าโดยสาร
    if (originOrder == null || destOrder == null) return 0;

    final diff = originOrder - destOrder;
    final absDiff = diff.abs();
    if (absDiff == 0) return 0;

    // diff < 0 = ไปข้างหน้า → ใช้ row suffix "-"
    // diff > 0 = ถอยหลัง    → ใช้ row ปกติ
    final rowKey = diff < 0 ? '$originId-' : originId;
    final fareList = _fareTableMap[rowKey];
    if (fareList == null || fareList.isEmpty) return 0;

    // ตำแหน่งคือ absDiff  → index = absDiff 
    final idx = absDiff;
    if (idx >= fareList.length) return fareList.last;
    return fareList[idx];
  }

  // ─────────────────────────────────────────────
  // calculateFare: entry point หลัก
  // แบ่ง route เป็น segment ตามสาย แล้วคิดค่าโดยสารสายอิสระ
  // ─────────────────────────────────────────────
  Map<String, int> calculateFare(List<gtfs.Stop> routeStops) {
    if (routeStops.length <= 1) {
      return {
        'mCount': 0,
        'sCount': 0,
        'mPrice': 0,
        'sPrice': 0,
        'total': 0,
      };
    }

    final segments = _splitByLineGroup(routeStops);

    int totalMCount = 0;
    int totalSCount = 0;
    int totalMPrice = 0;
    int totalSPrice = 0;
    int total = 0;

    for (final segment in segments) {
      if (segment.isEmpty) continue;
      final group = _lineGroup(segment.first.stopId);

      if (group == 'BTS') {
        final result = _calculateBtsFare(segment);
        totalMCount += result['mCount'] ?? 0;
        totalSCount += result['sCount'] ?? 0;
        totalMPrice += result['mPrice'] ?? 0;
        totalSPrice += result['sPrice'] ?? 0;
        total += result['total'] ?? 0;
      } else {
        final fare = _calculateNonBtsFare(segment);
        total += fare;
      }
    }

    // คำนวณส่วนลด
    final discount = _calculateDiscount(routeStops);
    total -= discount;
    if (total < 0) total = 0;

    return {
      'mCount': totalMCount,
      'sCount': totalSCount,
      'mPrice': totalMPrice,
      'sPrice': totalSPrice,
      'total': total,
      'discount': discount,
    };
  }

  // ─────────────────────────────────────────────
  // คำนวณส่วนลดตามเงื่อนไข (สนใจลำดับสถานีต่อเนื่อง)
  // ─────────────────────────────────────────────
  int _calculateDiscount(List<gtfs.Stop> routeStops) {
    if (routeStops.length < 2) return 0;

    // กฎส่วนลด: ระบุลำดับสถานี (sequence) ที่ต้องเดินทางผ่านให้ครบตามลำดับ
    final discountRules = [
      // กรณี 1: PP15 -> PP16 -> BL10
      {'sequence': ['PP15', 'PP16', 'BL10'], 'amount': 14},
      // กรณี 2: BL10 -> PP16 -> PP15
      {'sequence': ['BL10', 'PP16', 'PP15'], 'amount': 14},
    ];

    int totalDiscount = 0;

    // ตรวจสอบแต่ละกฎกับเส้นทางเดินรถ
    for (var rule in discountRules) {
      final sequence = rule['sequence'] as List<String>;
      final amount = rule['amount'] as int;
      
      if (sequence.isEmpty || sequence.length > routeStops.length) continue;

      // วนลูปตรวจสอบว่ามี pattern นี้เกิดขึ้นใน routeStops หรือไม่
      for (int i = 0; i <= routeStops.length - sequence.length; i++) {
        bool match = true;
        for (int j = 0; j < sequence.length; j++) {
          final stopId = routeStops[i + j].stopId.trim();
          if (stopId != sequence[j]) {
            match = false;
            break;
          }
        }
        if (match) {
          totalDiscount += amount;
        }
      }
    }

    return totalDiscount;
  }
}