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
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) {
          return SafeArea(
            child: RouteDetailsSheet(
              option: option,
              lineNameResolver: lineNameResolver,
              lineColorResolver: lineColorResolver,
              lineColors: lineColors,
              scrollController: controller,
            ),
          );
        },
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
    required this.scrollController,
  });

  final DirectionOption option;
  final LineNameResolver lineNameResolver;
  final LineColorResolver lineColorResolver;
  final Map<String, Color> lineColors;
  final ScrollController scrollController;

  Widget _buildSegmentHeader(
    BuildContext context,
    RouteSegment segment,
    int index,
    ThemeData theme,
  ) {
    IconData icon;
    Color iconColor;
    String title;

    if (segment.mode == TravelMode.walk) {
      icon = Icons.directions_walk;
      iconColor = Colors.grey;
      title = segment.instruction ?? 'Walk';
    } else if (segment.mode == TravelMode.taxi) {
      icon = Icons.local_taxi;
      iconColor = Colors.orange;
      title = segment.instruction ?? 'Taxi';
    } else if (segment.mode == TravelMode.bicycle) {
      icon = Icons.two_wheeler;
      iconColor = Colors.deepOrange;
      title = segment.instruction ?? 'Motorcycle Taxi';
    } else {
      if (segment.routeShortName != null && segment.routeShortName!.toLowerCase().contains("bus")) { icon = Icons.directions_bus; } else { icon = Icons.train; }
      iconColor =
          lineColors[segment.routeShortName] ?? theme.colorScheme.primary;
      title = segment.routeShortName ?? 'Transit';
      if (segment.instruction != null) {
        title = "$title (${segment.instruction})";
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: iconColor != Colors.grey
                        ? iconColor
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${segment.durationMinutes} min • ${formatDistance(segment.distanceMeters)}${segment.fare > 0 ? " • ฿${segment.fare}" : ""}",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopList(RouteSegment segment, ThemeData theme) {
    if (segment.intermediateStops == null ||
        segment.intermediateStops!.isEmpty) {
      return const SizedBox.shrink();
    }

    final stops = segment.intermediateStops!;
    final color =
        lineColors[segment.routeShortName] ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(left: 32, top: 8, bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: color.withValues(alpha: 0.3), width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(stops.length, (i) {
            final stop = stops[i];
            final isFirst = i == 0;
            final isLast = i == stops.length - 1;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(isFirst || isLast ? -4.5 : -2.5, 0),
                    child: Container(
                      width: isFirst || isLast ? 12 : 8,
                      height: isFirst || isLast ? 12 : 8,
                      decoration: BoxDecoration(
                        color: isFirst || isLast
                            ? theme.colorScheme.surface
                            : color,
                        shape: BoxShape.circle,
                        border: isFirst || isLast
                            ? Border.all(color: color, width: 3)
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(width: isFirst || isLast ? 12 : 16),
                  Expanded(
                    child: Text(
                      stop.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isFirst || isLast
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isFirst || isLast
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalFare = option.fareBreakdown['total'] ?? 0;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                option.label.isNotEmpty ? option.label : 'Trip Details',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "฿$totalFare",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.schedule,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              "${option.minutes} min",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              Icons.route,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              formatDistance(option.distanceMeters),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Journey',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        if (option.segments.isEmpty)
          Text('No segments available.', style: theme.textTheme.bodyMedium)
        else
          ...List.generate(option.segments.length, (index) {
            final segment = option.segments[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSegmentHeader(context, segment, index, theme),
                if (segment.mode == TravelMode.transit)
                  _buildStopList(segment, theme),
              ],
            );
          }),
      ],
    );
  }
}
