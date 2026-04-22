import 'package:flutter/foundation.dart';
import '../pages/transit_updates_list_page.dart';

class TransitUpdateService extends ChangeNotifier {
  static final TransitUpdateService _instance =
      TransitUpdateService._internal();

  factory TransitUpdateService() => _instance;

  TransitUpdateService._internal() {
    _initReports();
  }

  Future<void> _initReports() async {
    await fetchAndSyncReports();
  }

  Future<List<TransitReport>> fetchAndSyncReports() async {
    final fetched = await TransitUpdatesRepository.fetchLatestReports();
    _reports.clear();
    _reports.addAll(fetched);
    notifyListeners();
    return activeReports;
  }

  final List<TransitReport> _reports = [];

  List<TransitReport> get activeReports => List.unmodifiable(_reports);

  void addReport(TransitReport report) {
    _reports.insert(0, report);
    notifyListeners();
  }

  Future<void> upvote(String id) async {
    final index = _reports.indexWhere((r) => r.id == id);
    if (index != -1) {
      final report = _reports[index];
      _reports[index] = report.copyWith(upvotes: report.upvotes + 1);
      notifyListeners();
      await TransitUpdatesRepository.upvoteReport(id);
    }
  }

  Future<void> voteResolve(String id) async {
    final index = _reports.indexWhere((r) => r.id == id);
    if (index != -1) {
      final report = _reports[index];
      final newResolveVotes = report.resolveVotes + 1;
      final newResolved = newResolveVotes >= 5; // Reaches threshold
      _reports[index] = report.copyWith(
        resolveVotes: newResolveVotes,
        resolved: report.resolved || newResolved,
      );
      notifyListeners();
      await TransitUpdatesRepository.voteResolveReport(id);
    }
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
