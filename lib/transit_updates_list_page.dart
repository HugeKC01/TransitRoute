import 'package:flutter/material.dart';

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
    await Future<void>.delayed(const Duration(milliseconds: 700));
    // Future: Replace with Firebase Firestore query and caching.
    return sampleReports;
  }
}

class TransitUpdatesListPage extends StatefulWidget {
  const TransitUpdatesListPage({
    super.key,
    required this.initialReports,
    this.loadReports,
  });

  final List<TransitReport> initialReports;
  final Future<List<TransitReport>> Function()? loadReports;

  @override
  State<TransitUpdatesListPage> createState() => _TransitUpdatesListPageState();
}

class _TransitUpdatesListPageState extends State<TransitUpdatesListPage> {
  static const List<String> _issueTypes = [
    'Train malfunction',
    'Power outage',
    'Station closure',
    'Crowding',
    'Security concern',
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
    final reports = _filteredReports;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, topInset + 20, 16, 28),
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
                      content:
                          Text('Realtime Firebase feed coming soon.'),
                    ),
                  );
                },
                icon: const Icon(Icons.cloud_sync_outlined),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Community-sourced alerts similar to Waze or Google Maps. Filter by issue type to focus on what matters.',
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
            _EmptyState(onClearFilter: () => setState(() => _selectedType = null))
          else
            for (final report in reports)
              _ReportCard(
                report: report,
                typeColor: _typeColor(report.type, scheme),
                timeLabel: _timeLabel(report.reportedAt),
              ),
        ],
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('Follow'),
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
        Text(
          'No reports for this filter',
          style: theme.textTheme.titleMedium,
        ),
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
