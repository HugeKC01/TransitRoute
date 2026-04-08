import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/transit_update_service.dart';
import '../services/gtfs_models.dart' as gtfs;

class TransitReport {
  const TransitReport({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.line,
    required this.station,
    required this.reportedAt,
    required this.severity,
    required this.status,
    this.verified = false,
    this.upvotes = 0,
    this.resolveVotes = 0,
    this.resolved = false,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final String line;
  final String station;
  final DateTime reportedAt;
  final int severity;
  final String status;
  final bool verified;
  final int upvotes;
  final int resolveVotes;
  final bool resolved;

  TransitReport copyWith({
    String? id,
    String? type,
    String? title,
    String? description,
    String? line,
    String? station,
    DateTime? reportedAt,
    int? severity,
    String? status,
    bool? verified,
    int? upvotes,
    int? resolveVotes,
    bool? resolved,
  }) {
    return TransitReport(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      line: line ?? this.line,
      station: station ?? this.station,
      reportedAt: reportedAt ?? this.reportedAt,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      verified: verified ?? this.verified,
      upvotes: upvotes ?? this.upvotes,
      resolveVotes: resolveVotes ?? this.resolveVotes,
      resolved: resolved ?? this.resolved,
    );
  }

  factory TransitReport.fromJson(Map<String, dynamic> json, String id) {
    return TransitReport(
      id: id,
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      line: json['line'] as String? ?? '',
      station: json['station'] as String? ?? '',
      reportedAt: json['reportedAt'] != null
          ? DateTime.parse(json['reportedAt'] as String)
          : DateTime.now(),
      severity: json['severity'] as int? ?? 1,
      status: json['status'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
      upvotes: json['upvotes'] as int? ?? 0,
      resolveVotes: json['resolveVotes'] as int? ?? 0,
      resolved: json['resolved'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'description': description,
      'line': line,
      'station': station,
      'reportedAt': reportedAt.toIso8601String(),
      'severity': severity,
      'status': status,
      'verified': verified,
      'upvotes': upvotes,
      'resolveVotes': resolveVotes,
      'resolved': resolved,
    };
  }
}

class TransitUpdatesRepository {
  static final List<TransitReport> sampleReports = [
    TransitReport(
      id: 'rep_001',
      type: 'Train malfunction',
      title: 'Blue Line delay near Hua Lamphong',
      description:
          'Westbound train stuck for 12 minutes between Sam Yan and Hua Lamphong. Expect cascading delays.',
      line: 'MRT Blue Line',
      station: 'Hua Lamphong',
      reportedAt: DateTime(2025, 12, 1, 8, 10),
      severity: 4,
      status: 'Technicians en route',
      verified: true,
    ),
    TransitReport(
      id: 'rep_002',
      type: 'Power outage',
      title: 'Partial blackout at Bearing',
      description:
          'Ticket gates running on backup power. Elevators offline until Metropolitan Electricity Authority resolves outage.',
      line: 'BTS Sukhumvit',
      station: 'Bearing (E14)',
      reportedAt: DateTime(2025, 12, 1, 7, 35),
      severity: 3,
      status: 'Backup power available',
    ),
    TransitReport(
      id: 'rep_003',
      type: 'Crowding',
      title: 'Queues spilling outside Siam interchange',
      description:
          'Morning peak crowding on platforms 2 & 3. Staff forming single-file lines similar to Waze crowd-sourced alerts.',
      line: 'BTS Sukhumvit + Silom',
      station: 'Siam (CEN)',
      reportedAt: DateTime(2025, 12, 1, 7, 55),
      severity: 2,
      status: 'Extra marshals dispatched',
    ),
    TransitReport(
      id: 'rep_004',
      type: 'Security concern',
      title: 'Suspicious package cleared at Bang Wa',
      description:
          'Police responded quickly and cleared the area. Service resumed but expect lingering platform closures.',
      line: 'BTS Silom',
      station: 'Bang Wa (S12)',
      reportedAt: DateTime(2025, 12, 1, 6, 50),
      severity: 3,
      status: 'Area reopened',
      verified: true,
    ),
    TransitReport(
      id: 'rep_005',
      type: 'Station closure',
      title: 'Phahon Yothin 24 exits 2 & 3 closed',
      description:
          'Escalator maintenance blocking two exits until 14:00. Use exit 1 or 4 for access to Union Mall.',
      line: 'BTS Sukhumvit',
      station: 'Phahon Yothin 24 (N10)',
      reportedAt: DateTime(2025, 12, 1, 6, 15),
      severity: 1,
      status: 'Maintenance ongoing',
    ),
    TransitReport(
      id: 'rep_006',
      type: 'Other',
      title: 'Water leak spotted at Bang Na skywalk',
      description:
          'Small leak dripping onto escalator steps. Staff placing cones; tread carefully.',
      line: 'BTS Sukhumvit',
      station: 'Bang Na (E13)',
      reportedAt: DateTime(2025, 12, 1, 8, 5),
      severity: 1,
      status: 'Cleanup in progress',
    ),
  ];

  static Future<List<TransitReport>> fetchLatestReports() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('transit_reports')
          .orderBy('reportedAt', descending: true)
          .limit(50)
          .get();
      return snapshot.docs
          .map((doc) => TransitReport.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching reports from Firestore: $e');
      // Fallback
      return sampleReports;
    }
  }

  static Future<void> addReport(TransitReport report) async {
    try {
      await FirebaseFirestore.instance
          .collection('transit_reports')
          .doc(report.id)
          .set(report.toJson());
    } catch (e) {
      debugPrint('Error adding report to Firestore: $e');
    }
  }

  static Future<void> upvoteReport(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('transit_reports')
          .doc(id)
          .update({'upvotes': FieldValue.increment(1)});
    } catch (e) {
      debugPrint('Error upvoting report in Firestore: $e');
    }
  }

  static Future<void> voteResolveReport(String id) async {
    try {
      // In a real app we might read the current resolveVotes and update resolved boolean if needed
      await FirebaseFirestore.instance
          .collection('transit_reports')
          .doc(id)
          .update({'resolveVotes': FieldValue.increment(1)});
    } catch (e) {
      debugPrint('Error resolving report in Firestore: $e');
    }
  }
}

class TransitUpdatesListPage extends StatefulWidget {
  const TransitUpdatesListPage({
    super.key,
    required this.initialReports,
    this.loadReports,
    required this.allStops,
    required this.stopToLinesMap,
  });

  final List<TransitReport> initialReports;
  final Future<List<TransitReport>> Function()? loadReports;
  final List<gtfs.Stop> allStops;
  final Map<String, Set<String>> stopToLinesMap;

  @override
  State<TransitUpdatesListPage> createState() => _TransitUpdatesListPageState();
}

class _TransitUpdatesListPageState extends State<TransitUpdatesListPage> {
  static const List<String> _issueTypes = [
    'Train Delay',
    'Train malfunction',
    'Ticketing Issue',
    'Power outage',
    'Station closure',
    'Crowding',
    'Overcrowding',
    'Security concern',
    'Security',
    'Other',
  ];

  late List<TransitReport> _reports;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _reports = widget.initialReports;
  }

  Future<void> _handleRefresh() async {
    if (widget.loadReports == null) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return;
    }
    final latest = await widget.loadReports!();
    setState(() => _reports = latest);
  }

  List<TransitReport> get _filteredReports {
    final sorted = _reports.toList()
      ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
    if (_selectedType == null) return sorted;
    return sorted.where((report) => report.type == _selectedType).toList();
  }

  String _timeLabel(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _typeColor(String type, ColorScheme scheme) {
    switch (type) {
      case 'Train malfunction':
        return scheme.error;
      case 'Power outage':
        return scheme.tertiary;
      case 'Station closure':
        return scheme.primary;
      case 'Crowding':
        return scheme.secondary;
      case 'Security concern':
        return scheme.errorContainer;
      default:
        return scheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final reports = _filteredReports;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 10.0 + bottomInset),
        child: FloatingActionButton.extended(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => _ReportIssueSheet(
                allStops: widget.allStops,
                stopToLinesMap: widget.stopToLinesMap,
              ),
            ).then((_) {
              setState(() {
                _reports = TransitUpdateService().activeReports;
              });
            });
          },
          icon: const Icon(Icons.add_alert),
          label: const Text('Report Issue'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, topInset + 20, 16, bottomInset + 80),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Transit updates',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Future: subscribe via Firebase',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Realtime Firebase feed coming soon.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.cloud_sync_outlined),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Community-sourced alerts. Filter by issue type to focus on what matters.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _selectedType == null,
                  onSelected: (_) => setState(() => _selectedType = null),
                ),
                for (final type in _issueTypes)
                  ChoiceChip(
                    label: Text(type),
                    selected: _selectedType == type,
                    onSelected: (_) => setState(() => _selectedType = type),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (reports.isEmpty)
              _EmptyState(
                onClearFilter: () => setState(() => _selectedType = null),
              )
            else
              for (final report in reports)
                _ReportCard(
                  report: report,
                  typeColor: _typeColor(report.type, scheme),
                  timeLabel: _timeLabel(report.reportedAt),
                ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.typeColor,
    required this.timeLabel,
  });

  final TransitReport report;
  final Color typeColor;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: typeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.type,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (report.verified)
                  Row(
                    children: [
                      Icon(Icons.verified, color: scheme.primary, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              report.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              report.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.route, size: 16, color: scheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${report.line} • ${report.station}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Icon(Icons.schedule, size: 16, color: scheme.outline),
                const SizedBox(width: 4),
                Text(
                  timeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Severity ${report.severity}/5',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Future Firebase action: follow ${report.id}.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                  ),
                  label: const Text('Follow'),
                ),
              ],
            ),
            const Divider(height: 24),
            if (report.resolved || report.resolveVotes >= 5)
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Resolved by community',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => TransitUpdateService().upvote(report.id),
                    icon: const Icon(Icons.thumb_up_outlined, size: 18),
                    label: Text('Upvote (${report.upvotes})'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => TransitUpdateService().voteResolve(report.id),
                    icon: const Icon(Icons.check_circle_outlined, size: 18),
                    label: Text('Mark Resolved (${report.resolveVotes})'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onClearFilter});

  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: 60),
        Icon(Icons.inbox_outlined, size: 72, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Text('No reports for this filter', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Great news! Switch back to all to monitor the network.',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onClearFilter,
          icon: const Icon(Icons.clear_all),
          label: const Text('Clear filter'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _ReportIssueSheet extends StatefulWidget {
  const _ReportIssueSheet({
    required this.allStops,
    required this.stopToLinesMap,
  });

  final List<gtfs.Stop> allStops;
  final Map<String, Set<String>> stopToLinesMap;

  @override
  State<_ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<_ReportIssueSheet> {
  String? _selectedIssue;
  String? _selectedLine;
  bool _isLoadingTracker = true;
  bool _hasLocationPermission = false;
  List<String> _dynamicLineOptions = [];

  static const List<Map<String, dynamic>> _issueOptions = [
    {'title': 'Train Delay', 'icon': Icons.train, 'severity': 3},
    {'title': 'Overcrowding', 'icon': Icons.groups, 'severity': 2},
    {'title': 'Station Closure', 'icon': Icons.block, 'severity': 4},
    {
      'title': 'Ticketing Issue',
      'icon': Icons.confirmation_number,
      'severity': 1,
    },
    {'title': 'Security', 'icon': Icons.security, 'severity': 3},
    {'title': 'Other', 'icon': Icons.report_problem, 'severity': 1},
  ];

  static const List<String> _defaultLineOptions = [
    'BTS Sukhumvit',
    'BTS Silom',
    'MRT Blue Line',
    'MRT Purple Line',
    'ARL',
    'SRT Red Line',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _checkLocation();
  }

  Future<void> _checkLocation() async {
    final location = Location();
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            setState(() {
              _isLoadingTracker = false;
              _hasLocationPermission = false;
            });
          }
          return;
        }
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          if (mounted) {
            setState(() {
              _isLoadingTracker = false;
              _hasLocationPermission = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _hasLocationPermission = true;
        });
      }

      final locData = await location.getLocation();
      final userLat = locData.latitude;
      final userLon = locData.longitude;

      if (userLat != null && userLon != null) {
        final userLatLng = LatLng(userLat, userLon);
        final distance = const Distance();
        final nearbyLines = <String>{};

        for (final stop in widget.allStops) {
          final stopLatLng = LatLng(stop.lat, stop.lon);
          final distMeters = distance.as(
            LengthUnit.Meter,
            userLatLng,
            stopLatLng,
          );

          if (distMeters <= 2000) {
            // Check stop code or other IDs you map by.
            // The map usually keys by stop code or stop ID.
            final linesByCode = widget.stopToLinesMap[stop.code] ?? <String>{};
            final linesById = widget.stopToLinesMap[stop.stopId] ?? <String>{};
            nearbyLines.addAll(linesByCode);
            nearbyLines.addAll(linesById);
          }
        }

        if (mounted) {
          setState(() {
            if (nearbyLines.isEmpty) {
              _dynamicLineOptions = List.from(_defaultLineOptions);
            } else {
              _dynamicLineOptions = nearbyLines.toList();
            }
            _sortLineOptions();
            _isLoadingTracker = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _dynamicLineOptions = List.from(_defaultLineOptions);
            _sortLineOptions();
            _isLoadingTracker = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dynamicLineOptions = List.from(_defaultLineOptions);
          _sortLineOptions();
          _isLoadingTracker = false;
        });
      }
    }
  }

  void _sortLineOptions() {
    int getPriority(String line) {
      final upper = line.toUpperCase();
      if (upper.contains('MRT') || upper.contains('BTS') || upper.contains('ARL')) return 1;
      if (upper.contains('SRT')) return 2;
      if (upper.startsWith('BUS') || upper.contains('BUS')) return 3;
      if (upper.contains('FERRY')) return 4;
      return 5;
    }

    _dynamicLineOptions.sort((a, b) {
      final pA = getPriority(a);
      final pB = getPriority(b);
      if (pA != pB) return pA.compareTo(pB);
      return a.compareTo(b);
    });
  }

  IconData _getIconForLine(String line) {
    final upper = line.toUpperCase();
    if (upper.contains('MRT') || upper.contains('BTS') || upper.contains('ARL')) return Icons.subway;
    if (upper.contains('SRT')) return Icons.train;
    if (upper.startsWith('BUS') || upper.contains('BUS')) return Icons.directions_bus;
    if (upper.contains('FERRY')) return Icons.directions_boat;
    return Icons.directions_transit;
  }

  void _submitReport() {
    if (_selectedIssue == null || _selectedLine == null) return;

    final severity =
        _issueOptions.firstWhere(
              (e) => e['title'] == _selectedIssue,
            )['severity']
            as int;

    final report = TransitReport(
      id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
      type: _selectedIssue!,
      title: '$_selectedIssue reported on $_selectedLine',
      description: 'User reported $_selectedIssue via quick report.',
      line: _selectedLine!,
      station: 'Unknown (Quick Report)',
      reportedAt: DateTime.now(),
      severity: severity,
      status: 'Report received',
      verified: false,
    );

    TransitUpdateService().addReport(report);
    TransitUpdatesRepository.addReport(report);

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_isLoadingTracker) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasLocationPermission) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 64, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              'Location Access Required',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You must grant location permission to report issues to prevent spam.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            SafeArea(child: const SizedBox(height: 16)),
          ],
        ),
      );
    }

    final isReady = _selectedIssue != null && _selectedLine != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Report an Issue',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Text('What is the problem?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
            children: _issueOptions.map((issue) {
              final isSelected = _selectedIssue == issue['title'];
              return InkWell(
                onTap: () =>
                    setState(() => _selectedIssue = issue['title'] as String),
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primaryContainer
                        : scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? scheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        issue['icon'] as IconData,
                        color: isSelected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        issue['title'] as String,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isSelected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text('Which line?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dynamicLineOptions.map((line) {
                  return ChoiceChip(
                    avatar: Icon(_getIconForLine(line), size: 18),
                    label: Text(line),
                    selected: _selectedLine == line,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedLine = line);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: isReady ? _submitReport : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Submit Report'),
          ),
          SafeArea(child: const SizedBox(height: 16)),
        ],
      ),
    );
  }
}
