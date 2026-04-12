import 'package:flutter/material.dart';
import 'package:route/services/timetable_service.dart';

class StationTimetableSection extends StatefulWidget {
  final String stopId;
  const StationTimetableSection({super.key, required this.stopId});

  @override
  State<StationTimetableSection> createState() =>
      _StationTimetableSectionState();
}

class _StationTimetableSectionState extends State<StationTimetableSection> {
  late Future<List<TimetableEntry>> _timetableFuture;
  late String _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (now.weekday == DateTime.saturday) {
      _selectedDay = 'SAT';
    } else if (now.weekday == DateTime.sunday) {
      _selectedDay = 'SUN';
    } else {
      _selectedDay = 'WKD';
    }
    _loadTimetable();
  }

  void _loadTimetable() {
    _timetableFuture = TimetableService.getTimetableForStop(
      widget.stopId,
      serviceId: _selectedDay,
    );
  }

  @override
  void didUpdateWidget(StationTimetableSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stopId != widget.stopId) {
      setState(() {
        _loadTimetable();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final now = DateTime.now();
    final currentTimeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Timetable',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            DropdownButton<String>(
              value: _selectedDay,
              items: const [
                DropdownMenuItem(value: 'WKD', child: Text('Weekday')),
                DropdownMenuItem(value: 'SAT', child: Text('Saturday')),
                DropdownMenuItem(value: 'SUN', child: Text('Sunday/Holiday')),
              ],
              onChanged: (value) {
                if (value != null && value != _selectedDay) {
                  setState(() {
                    _selectedDay = value;
                    _loadTimetable();
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<TimetableEntry>>(
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
            if (snapshot.hasError) {
              return Text(
                'Error loading timetable: ${snapshot.error}',
                style: TextStyle(color: scheme.error),
              );
            }

            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const Text(
                'No upcoming departures or timetable data available.',
              );
            }

            // Group by Route + Headsign
            final grouped = <String, List<TimetableEntry>>{};
            for (var e in entries) {
              final key = '${e.routeId} - ${e.headsign}'.trim();
              grouped
                  .putIfAbsent(
                    key.isEmpty || key == '-' ? 'Unknown/Generic' : key,
                    () => [],
                  )
                  .add(e);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: grouped.entries.map((entry) {
                final groupTitle = entry.key;
                final times = entry.value;

                // Find next departure index to highlight
                int nextDepartureIndex = -1;
                for (int i = 0; i < times.length; i++) {
                  final t = times[i];
                  if (!t.isFrequency &&
                      t.departureTime.compareTo(currentTimeString) >= 0) {
                    nextDepartureIndex = i;
                    break;
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          groupTitle.replaceAll(RegExp(r'^-|-$'), '').trim(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(times.length, (index) {
                            final t = times[index];
                            final isNext = index == nextDepartureIndex;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isNext ? scheme.primary : scheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isNext
                                      ? scheme.primary
                                      : scheme.outlineVariant.withValues(
                                          alpha: 0.5,
                                        ),
                                ),
                              ),
                              child: Text(
                                t.displayTime,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isNext ? scheme.onPrimary : null,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
