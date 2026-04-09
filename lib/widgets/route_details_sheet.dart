import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:route/services/direction_service.dart';
import 'formatters.dart';

import 'widget_types.dart';

class RouteDetailsSheet extends StatelessWidget {
  const RouteDetailsSheet({
    super.key,
    required this.option,
    required this.lineNameResolver,
    required this.lineColorResolver,
    required this.lineColors,
    required this.onBack,
    this.routeIconResolver,
  });

  final DirectionOption option;
  final LineNameResolver lineNameResolver;
  final LineColorResolver lineColorResolver;
  final Map<String, Color> lineColors;
  final VoidCallback onBack;
  final String? Function(String)? routeIconResolver;

  static const List<String> _tagOrder = [
    'Shortest',
    'Fastest',
    'Cheapest',
    'Direct',
    'Balanced',
    'Low transfers',
    'Fewest stops',
    'Transfer',
  ];

  Widget _buildSegmentHeader(
    BuildContext context,
    RouteSegment segment,
    int index,
    ThemeData theme,
  ) {
    IconData? icon;
    String? iconPath;
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
      if (routeIconResolver != null && segment.routeShortName != null) {
        iconPath = routeIconResolver!(segment.routeShortName!);
      }

      if (iconPath == null) {
        if (segment.isFerry) {
          icon = Icons.directions_boat;
        } else if (segment.isBus) {
          icon = Icons.directions_bus;
        } else {
          icon = Icons.train;
        }
      }

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
            decoration: BoxDecoration(
              color: iconPath != null
                  ? iconColor.withValues(alpha: 0.15)
                  : iconColor,
              shape: BoxShape.circle,
              border: iconPath != null
                  ? Border.all(color: iconColor, width: 1.5)
                  : null,
            ),
            child: iconPath != null
                ? SvgPicture.asset(iconPath, width: 20, height: 20)
                : Icon(icon, color: Colors.white, size: 20),
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
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${segment.durationMinutes} min • ${formatDistance(segment.distanceMeters)}${segment.fare > 0 ? " • ฿${segment.fare}" : ""}",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (segment.nextDepartureTime != null ||
                    segment.frequencyInfo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      segment.frequencyInfo ??
                          'Next departure: ${segment.nextDepartureTime}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
                    offset: Offset(isFirst || isLast ? -7.5 : -5.5, 0),
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

    final sortedTags = option.tags.toList()
      ..sort((a, b) {
        final ai = _tagOrder.indexOf(a);
        final bi = _tagOrder.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });
    final filteredTags = sortedTags;
    final headlineTags = filteredTags.take(3).toList();
    final remainingTags = filteredTags.length - headlineTags.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
                tooltip: 'Back to options',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: headlineTags.isNotEmpty
                    ? Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ...headlineTags.map((tag) {
                            final color = tag == 'Fastest'
                                ? const Color(0xFF2E7D32)
                                : tag == 'Cheapest'
                                ? const Color(0xFFF9A825)
                                : theme.colorScheme.primary;
                            final icon = tag == 'Fastest'
                                ? Icons.bolt
                                : tag == 'Cheapest'
                                ? Icons.savings
                                : tag == 'Shortest'
                                ? Icons.straighten
                                : null;
                            return _TagPill(
                              label: tag,
                              color: color,
                              icon: icon,
                            );
                          }),
                          if (remainingTags > 0)
                            _TagPill(
                              label: '+$remainingTags',
                              color: theme.colorScheme.secondary,
                            ),
                        ],
                      )
                    : Text(
                        option.label.isNotEmpty ? option.label : 'Trip Details',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                  if (segment.hasIssue)
                    Padding(
                      padding: const EdgeInsets.only(left: 32, bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: theme.colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                segment.issueNotice ??
                                    'Issue reported on this line',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (segment.mode == TravelMode.transit)
                    _buildStopList(segment, theme),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
