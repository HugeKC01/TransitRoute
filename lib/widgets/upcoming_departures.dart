import 'package:flutter/material.dart';
import 'package:route/services/timetable_service.dart';

class UpcomingDeparturesWidget extends StatefulWidget {
  final String stopId;

  const UpcomingDeparturesWidget({super.key, required this.stopId});

  @override
  State<UpcomingDeparturesWidget> createState() =>
      _UpcomingDeparturesWidgetState();
}

class _UpcomingDeparturesWidgetState extends State<UpcomingDeparturesWidget> {
  late Future<List<TimetableEntry>> _timetableFuture;

  @override
  void initState() {
    super.initState();
    _timetableFuture = TimetableService.getTimetableForStop(widget.stopId);
  }

  @override
  void didUpdateWidget(UpcomingDeparturesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stopId != widget.stopId) {
      setState(() {
        _timetableFuture = TimetableService.getTimetableForStop(widget.stopId);
      });
    }
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
        final currentTimeString =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

        final validEntries = snapshot.data!;

        // Find next departures (simplified strictly by time string comparison for fixed schedules, or just show active frequency)
        final displayEntries = <TimetableEntry>[];
        for (var e in validEntries) {
          if (e.isFrequency) {
            // Check if current time falls in frequency
            if (e.startTime != null &&
                e.endTime != null &&
                currentTimeString.compareTo(e.startTime!) >= 0 &&
                currentTimeString.compareTo(e.endTime!) <= 0) {
              displayEntries.add(e);
            }
          } else {
            // Include if it departs after now, up to a small limit
            if (e.departureTime.isNotEmpty &&
                e.departureTime.compareTo(currentTimeString) >= 0) {
              displayEntries.add(e);
            }
          }
        }

        displayEntries.sort((a, b) {
          final tA = a.isFrequency ? a.startTime! : a.departureTime;
          final tB = b.isFrequency ? b.startTime! : b.departureTime;
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Upcoming Departures',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.2),
                ),
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
                            e.displayTime,
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
            ),
          ],
        );
      },
    );
  }
}
