import 'package:flutter/material.dart';
import 'package:route/services/direction_service.dart';
import 'package:route/services/route_formatters.dart';

class RouteOptionsPanel extends StatelessWidget {
  const RouteOptionsPanel({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelectOption,
    required this.onViewDetails,
    required this.onStartNavigation,
    required this.lineNameResolver,
    required this.lineColors,
  });

  final List<DirectionOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelectOption;
  final ValueChanged<DirectionOption> onViewDetails;
  final ValueChanged<DirectionOption> onStartNavigation;
  final LineNameResolver lineNameResolver;
  final Map<String, Color> lineColors;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    int? fastestIndex;
    int? shortestIndex;
    int? cheapestIndex;
    int? fastestMinutes;
    double? shortestDistance;
    int? cheapestFare;
    for (int i = 0; i < options.length; i++) {
      final option = options[i];
      if (fastestMinutes == null || option.minutes < fastestMinutes) {
        fastestMinutes = option.minutes;
        fastestIndex = i;
      }
      if (shortestDistance == null ||
          option.distanceMeters < shortestDistance) {
        shortestDistance = option.distanceMeters;
        shortestIndex = i;
      }
      final totalFare = option.fareBreakdown['total'] ?? 0;
      if (cheapestFare == null || totalFare < cheapestFare) {
        cheapestFare = totalFare;
        cheapestIndex = i;
      }
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Routes',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${options.length} options',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
              onStartNavigation: () => onStartNavigation(options[index]),
              lineNameResolver: lineNameResolver,
              lineColors: lineColors,
              highlightType: index == fastestIndex
                  ? _HighlightType.fastest
                  : index == cheapestIndex
                  ? _HighlightType.cheapest
                  : null,
              showShortestTag: index == shortestIndex,
              showFastestTag: index == fastestIndex,
            ),
          ),
        ],
      ),
    );
  }
}

enum _HighlightType { fastest, cheapest }

class _RouteOptionCard extends StatelessWidget {
  const _RouteOptionCard({
    required this.option,
    required this.index,
    required this.isSelected,
    required this.onSelect,
    required this.onViewDetails,
    required this.onStartNavigation,
    required this.lineNameResolver,
    required this.lineColors,
    this.highlightType,
    required this.showShortestTag,
    required this.showFastestTag,
  });

  final DirectionOption option;
  final int index;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onViewDetails;
  final VoidCallback onStartNavigation;
  final LineNameResolver lineNameResolver;
  final Map<String, Color> lineColors;
  final _HighlightType? highlightType;
  final bool showShortestTag;
  final bool showFastestTag;

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
    final stops = option.allStops;
    if (stops.isEmpty) {
      return const SizedBox.shrink();
    }
    final label = option.label.isNotEmpty
        ? option.label
        : 'Option ${index + 1}';
    final sortedTags = option.tags.toList()
      ..sort((a, b) {
        final ai = _tagOrder.indexOf(a);
        final bi = _tagOrder.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });
    final filteredTags = sortedTags.where((tag) {
      if (tag == 'Shortest' && !showShortestTag) return false;
      if (tag == 'Fastest' && !showFastestTag) return false;
      return true;
    }).toList();
    final headlineTags = filteredTags.take(3).toList();
    final remainingTags = filteredTags.length - headlineTags.length;
    final distanceText = formatDistance(option.distanceMeters);
    final lineSegments = splitRouteByLine(stops, lineNameResolver);

    final theme = Theme.of(context);
    final highlightColor = switch (highlightType) {
      _HighlightType.fastest => const Color(0xFF2E7D32),
      _HighlightType.cheapest => const Color(0xFFF9A825),
      _ => null,
    };
    final applyHighlight = highlightColor != null && !isSelected;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onSelect,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : applyHighlight
                    ? highlightColor.withValues(alpha: 0.5)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: isSelected ? 2.0 : 1.0,
              ),
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : theme.colorScheme.surface,
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                else
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (headlineTags.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ...headlineTags.map((tag) => _TagPill(
                                        label: tag,
                                        color: tag == 'Fastest'
                                            ? const Color(0xFF2E7D32)
                                            : tag == 'Cheapest'
                                            ? const Color(0xFFF9A825)
                                            : theme.colorScheme.primary,
                                      )),
                                  if (remainingTags > 0)
                                    _TagPill(
                                      label: '+$remainingTags',
                                      color: theme.colorScheme.secondary,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${option.minutes}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: applyHighlight
                                      ? highlightColor
                                      : theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'min',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '฿${option.fareBreakdown['total'] ?? 0}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Transit Line Visualizer
                  if (lineSegments.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (int i = 0; i < lineSegments.length; i++) ...[
                              if (i > 0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(Icons.arrow_right_alt, size: 20, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              Builder(
                                builder: (context) {
                                  final lineName = resolveSegmentLineName(lineSegments[i], lineNameResolver);
                                  final color = lineColors[lineName] ?? theme.colorScheme.primary;
                                  final textColor = color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
                                  
                                  IconData getTransportIcon(String name) {
                                    final lower = name.toLowerCase();
                                    if (lower.contains('walk')) return Icons.directions_walk;
                                    if (lower.contains('bus')) return Icons.directions_bus;
                                    if (lower.contains('boat') || lower.contains('ferry')) return Icons.directions_boat;
                                    return Icons.directions_transit;
                                  }

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          getTransportIcon(lineName),
                                          size: 16,
                                          color: textColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          lineName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Metrics Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.route, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(distanceText, style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          )),
                          const SizedBox(width: 12),
                          Icon(Icons.signpost, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('${stops.length} stops', style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          )),
                        ],
                      ),
                      if (isSelected)
                        Row(
                          children: [
                            IconButton.filledTonal(
                              onPressed: onViewDetails,
                              icon: const Icon(Icons.info_outline, size: 20),
                              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                              padding: EdgeInsets.zero,
                              tooltip: 'Details',
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: onStartNavigation,
                              icon: const Icon(Icons.navigation, size: 18),
                              label: const Text('Go'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
