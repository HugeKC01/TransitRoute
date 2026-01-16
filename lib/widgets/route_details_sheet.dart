import 'package:flutter/material.dart';
import 'package:route/services/direction_service.dart';
import 'package:route/services/route_formatters.dart';

import 'widget_types.dart';


Future<void> showRouteDetailsSheet({
  required BuildContext context,
  required DirectionOption option,
  required LineNameResolver lineNameResolver,
  required LineColorResolver lineColorResolver,
  required Map<String, Color> lineColors,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.9,
        child: SafeArea(
          child: RouteDetailsSheet(
            option: option,
            lineNameResolver: lineNameResolver,
            lineColorResolver: lineColorResolver,
            lineColors: lineColors,
          ),
        ),
      );
    },
  );
}

class RouteDetailsSheet extends StatelessWidget {
  const RouteDetailsSheet({
    super.key,
    required this.option,
    required this.lineNameResolver,
    required this.lineColorResolver,
    required this.lineColors,
  });

  final DirectionOption option;
  final LineNameResolver lineNameResolver;
  final LineColorResolver lineColorResolver;
  final Map<String, Color> lineColors;

  @override
  Widget build(BuildContext context) {
    final segments = splitRouteByLine(option.stops, lineNameResolver);
    final tags = option.tags.toList();
    final totalFare = option.fareBreakdown['total'] ?? 0;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  option.label.isNotEmpty ? option.label : 'Option details',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '฿$totalFare',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatDistance(option.distanceMeters)} • ~${option.minutes} min • ${option.stops.length} stops',
            style: theme.textTheme.bodyMedium,
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: tags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
          ],
          const SizedBox(height: 24),
          Text('Line segments', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (segments.isEmpty)
            Text('No line information available.',
                style: theme.textTheme.bodyMedium)
          else
            Column(
              children: segments.map((segment) {
                if (segment.isEmpty) {
                  return const SizedBox.shrink();
                }
                final first = segment.first;
                final last = segment.last;
                final lineName = resolveSegmentLineName(
                  segment,
                  lineNameResolver,
                );
                final representativeStop = segmentStopMatchingLine(
                      segment,
                      lineNameResolver,
                      lineName,
                    ) ??
                    first;
                final color = lineColors[lineName] ??
                    lineColorResolver(representativeStop.stopId);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: color),
                  title: Text('$lineName • ${segment.length} stops'),
                  subtitle: Text('${first.name} → ${last.name}'),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
          Text('Stops along the way', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: option.stops.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final stop = option.stops[index];
              final color = lineColorResolver(stop.stopId);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: color,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(stop.name),
                subtitle: Text('ID: ${stop.stopId}'),
              );
            },
          ),
        ],
      ),
    );
  }
}

