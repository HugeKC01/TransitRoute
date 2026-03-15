import 'package:flutter/foundation.dart';
import '../pages/transit_updates_list_page.dart';

class TransitUpdateService extends ChangeNotifier {
  static final TransitUpdateService _instance = TransitUpdateService._internal();

  factory TransitUpdateService() => _instance;

  TransitUpdateService._internal() {
    _reports.addAll(TransitUpdatesRepository.sampleReports);
  }

  final List<TransitReport> _reports = [];

  List<TransitReport> get activeReports => List.unmodifiable(_reports);

  void addReport(TransitReport report) {
    _reports.insert(0, report);
    notifyListeners();
  }

  /// Returns severely impacted lines (e.g. train malfunction, closure, severity >= 3)
  List<TransitReport> getReportsForLine(String lineName) {
    return _reports.where((r) {
      final rLine = r.line.toLowerCase();
      final qLine = lineName.toLowerCase();
      return rLine.contains(qLine) || qLine.contains(rLine);
    }).toList();
  }

  List<TransitReport> getReportsForStation(String stationName) {
    return _reports.where((r) {
      final rStation = r.station.toLowerCase();
      final qStation = stationName.toLowerCase();
      return rStation.contains(qStation) || qStation.contains(rStation);
    }).toList();
  }
}
