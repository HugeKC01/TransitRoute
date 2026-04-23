import 'package:flutter/material.dart';
import 'package:route/services/timetable_service.dart';

class UpcomingDeparturesWidget extends StatefulWidget {
  final String stopId;
  final List<String> mergedStopIds;

  const UpcomingDeparturesWidget({
    super.key, 
    required this.stopId,
    this.mergedStopIds = const [],
  });

  @override
  State<UpcomingDeparturesWidget> createState() =>
      _UpcomingDeparturesWidgetState();
}

class _UpcomingDeparturesWidgetState extends State<UpcomingDeparturesWidget> {
  late Future<List<TimetableEntry>> _timetableFuture;

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  @override
  void didUpdateWidget(UpcomingDeparturesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stopId != oldWidget.stopId || widget.mergedStopIds != oldWidget.mergedStopIds) {
      _loadTimetable();
    }
  }

  void _loadTimetable() {
    final stopIds = widget.mergedStopIds.isNotEmpty ? widget.mergedStopIds : [widget.stopId];
    _timetableFuture = _fetchCombinedTimetables(stopIds);
  }

  Future<List<TimetableEntry>> _fetchCombinedTimetables(List<String> ids) async {
    final futures = ids.map((id) => TimetableService.getTimetableForStop(id));
    final results = await Future.wait(futures);
    final combined = results.expand((list) => list).toList();
    combined.sort((a, b) => a.departureTime.compareTo(b.departureTime));
    return combined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FutureBuilder<List<TimetableEntry>>(
      future: _timetableFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              'No upcoming departures found for this time.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          );
        }

        final now = DateTime.now();

        // GTFS departure times can go past 24:00 (e.g. 25:30 = 1:30am next day).
        // We compute the current time as "GTFS seconds from midnight" of the
        // service day. If it's before 03:00 we treat it as the continuation of
        // yesterday's service (add 24 h so "01:30" becomes "25:30").
        int toGtfsSeconds(String timeStr) {
          final parts = timeStr.split(':');
          if (parts.length < 2) return 0;
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final s = parts.length >= 3 ? (int.tryParse(parts[2]) ?? 0) : 0;
          return h * 3600 + m * 60 + s;
        }

        int nowGtfsSecs = now.hour * 3600 + now.minute * 60 + now.second;
        // If before 3am assume we're still in yesterday's service day.
        if (now.hour < 3) nowGtfsSecs += 24 * 3600;

        final validEntries = snapshot.data!;

        final displayEntries = <TimetableEntry>[];
        for (var e in validEntries) {
          if (e.isFrequency) {
            if (e.startTime != null && e.endTime != null) {
              final start = toGtfsSeconds(e.startTime!);
              final end = toGtfsSeconds(e.endTime!);
              if (nowGtfsSecs >= start && nowGtfsSecs <= end) {
                displayEntries.add(e);
              }
            }
          } else {
            if (e.departureTime.isNotEmpty) {
              final depSecs = toGtfsSeconds(e.departureTime);
              if (depSecs >= nowGtfsSecs) {
                displayEntries.add(e);
              }
            }
          }
        }

        displayEntries.sort((a, b) {
          final tA = toGtfsSeconds(
            a.isFrequency ? (a.startTime ?? '99:99') : a.departureTime,
          );
          final tB = toGtfsSeconds(
            b.isFrequency ? (b.startTime ?? '99:99') : b.departureTime,
          );
          return tA.compareTo(tB);
        });


        // Find the next departure for each trip/route
        final groupedDepartures = <String, TimetableEntry>{};
        for (final e in displayEntries) {
          final key = '${e.routeId}-${e.headsign}';
          if (!groupedDepartures.containsKey(key)) {
            groupedDepartures[key] = e;
          }
        }
        final topEntries = groupedDepartures.values.toList();

        if (topEntries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              'All trips finished for the day.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: topEntries.map((e) {
              final groupTitle = '${e.routeId} - ${e.headsign}'
                  .replaceAll(RegExp(r'^-|-$'), '')
                  .trim();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        groupTitle.isEmpty ? 'Train' : groupTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        e.isFrequency
                            ? (e.headwaySecs != null
                                  ? 'Every ${e.headwaySecs! ~/ 60}m${e.headwaySecs! % 60 > 0 ? ' ${e.headwaySecs! % 60}s' : ''}'
                                  : 'Frequent')
                            : e.displayTime,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
