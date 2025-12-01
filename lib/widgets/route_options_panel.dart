import 'package:flutter/material.dart';
import 'package:route/services/direction_service.dart';
import 'package:route/services/fare_calculator.dart';
import 'package:route/services/route_formatters.dart';

class RouteOptionsPanel extends StatelessWidget {
  const RouteOptionsPanel({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelectOption,
    required this.onViewDetails,
    required this.lineNameResolver,
    required this.lineColors,
  });

  final List<DirectionOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelectOption;
  final ValueChanged<DirectionOption> onViewDetails;
  final LineNameResolver lineNameResolver;
  final Map<String, Color> lineColors;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route options (${options.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a card to preview the path or open details for full breakdowns.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ...List.generate(
            options.length,
            (index) => _RouteOptionCard(
              option: options[index],
              index: index,
              isSelected: index == selectedIndex,
              onSelect: () => onSelectOption(index),
              onViewDetails: () => onViewDetails(options[index]),
              lineNameResolver: lineNameResolver,
              lineColors: lineColors,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteOptionCard extends StatelessWidget {
  const _RouteOptionCard({
    required this.option,
    required this.index,
    required this.isSelected,
    required this.onSelect,
    required this.onViewDetails,
    required this.lineNameResolver,
    required this.lineColors,
  });

  final DirectionOption option;
  final int index;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onViewDetails;
  final LineNameResolver lineNameResolver;
  final Map<String, Color> lineColors;

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

  @override
  Widget build(BuildContext context) {
    final stops = option.stops;
    if (stops.isEmpty) {
      return const SizedBox.shrink();
    }
    final label = option.label.isNotEmpty ? option.label : 'Option ${index + 1}';
    final sortedTags = option.tags.toList()
      ..sort((a, b) {
        final ai = _tagOrder.indexOf(a);
        final bi = _tagOrder.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });
    final headlineTags = sortedTags.take(3).toList();
    final remainingTags = sortedTags.length - headlineTags.length;
    final distanceText = formatDistance(option.distanceMeters);
    final ladderTotal = option.fareBreakdown[kMrtSrtTotalKey] ?? 0;
    final lineSegments = splitRouteByLine(stops, lineNameResolver);

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.7)
                : theme.colorScheme.surface,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (headlineTags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ...headlineTags.map(
                                  (tag) => _TagPill(label: tag),
                                ),
                                if (remainingTags > 0)
                                  _TagPill(label: '+$remainingTags more'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'View route details',
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.info_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.schedule,
                      label: 'Duration',
                      value: '${option.minutes} min',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.route,
                      label: 'Distance',
                      value: distanceText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.signpost,
                      label: 'Stops',
                      value: '${stops.length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimated fare',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            '฿${option.fareBreakdown['total'] ?? 0}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Text(
                        'm:${option.fareBreakdown['mCount'] ?? 0} (฿${option.fareBreakdown['mPrice'] ?? 0})  '
                        's:${option.fareBreakdown['sCount'] ?? 0} (฿${option.fareBreakdown['sPrice'] ?? 0})'
                        '${ladderTotal > 0 ? '\nMRT/SRT: ฿$ladderTotal' : ''}',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
              if (lineSegments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: lineSegments.map((segment) {
                    final lineName = segment.isNotEmpty
                        ? (lineNameResolver(segment.first.stopId) ?? 'Unknown line')
                        : 'Unknown line';
                    final color = lineColors[lineName] ?? theme.colorScheme.primary;
                    return InputChip(
                      avatar: CircleAvatar(
                        backgroundColor: color,
                        radius: 6,
                      ),
                      label: Text(lineName),
                      onPressed: null,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
