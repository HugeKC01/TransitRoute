import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:route/services/direction_service.dart';
import 'formatters.dart';

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
    required this.selectedSortMode,
    required this.onSortModeChanged,
    this.routeIconResolver,
  });

  final List<DirectionOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelectOption;
  final ValueChanged<DirectionOption> onViewDetails;
  final ValueChanged<DirectionOption> onStartNavigation;
  final LineNameResolver lineNameResolver;
  final Map<String, Color> lineColors;
  final String selectedSortMode;
  final ValueChanged<String?> onSortModeChanged;
  final String? Function(String)? routeIconResolver;

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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.route,
                      size: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${options.length} Routes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    'Sort by:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: selectedSortMode,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    icon: Icon(
                      Icons.sort,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    underline: const SizedBox.shrink(),
                    onChanged: onSortModeChanged,
                    items: const [
                      DropdownMenuItem(
                        value: 'Default',
                        child: Text('Default'),
                      ),
                      DropdownMenuItem(value: 'Price', child: Text('Price')),
                      DropdownMenuItem(
                        value: 'Distance',
                        child: Text('Distance'),
                      ),
                      DropdownMenuItem(
                        value: 'Fastest',
                        child: Text('Fastest'),
                      ),
                    ],
                  ),
                ],
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
              routeIconResolver: routeIconResolver,
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
    this.routeIconResolver,
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
  final String? Function(String)? routeIconResolver;
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
    final displaySegments = option.segments.where((s) {
      if (s.mode == TravelMode.transit && s.routeShortName != null) return true;
      if (s.mode == TravelMode.walk && s.distanceMeters > 0) return true;
      return false;
    }).toList();

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
                            if (headlineTags.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ...headlineTags.map(
                                    (tag) => _TagPill(
                                      label: tag,
                                      color: tag == 'Fastest'
                                          ? const Color(0xFF2E7D32)
                                          : tag == 'Cheapest'
                                          ? const Color(0xFFF9A825)
                                          : tag == 'Fewest stops'
                                          ? const Color(0xFF0288D1)
                                          : tag == 'Low transfers'
                                          ? const Color(0xFF8E24AA)
                                          : theme.colorScheme.primary,
                                      icon: tag == 'Fastest'
                                          ? Icons.bolt
                                          : tag == 'Cheapest'
                                          ? Icons.savings
                                          : tag == 'Shortest'
                                          ? Icons.straighten
                                          : tag == 'Fewest stops'
                                          ? Icons.signpost
                                          : tag == 'Low transfers'
                                          ? Icons.swap_horiz
                                          : null,
                                    ),
                                  ),
                                  if (remainingTags > 0)
                                    _TagPill(
                                      label: '+$remainingTags',
                                      color: theme.colorScheme.secondary,
                                    ),
                                ],
                              )
                            else
                              Text(
                                label,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 18,
                                color: applyHighlight
                                    ? highlightColor
                                    : theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '~${option.minutes}',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: applyHighlight
                                                ? highlightColor
                                                : theme.colorScheme.primary,
                                          ),
                                    ),
                                    TextSpan(
                                      text: ' min',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.payments_outlined,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          '~${option.fareBreakdown['total'] ?? 0}',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                    ),
                                    TextSpan(
                                      text: ' ฿',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (option.hasIssue) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
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
                              option.issueNotice ?? 'Transit issue reported',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Transit Line Visualizer
                  if (displaySegments.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (
                              int i = 0;
                              i < displaySegments.length;
                              i++
                            ) ...[
                              if (i > 0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Icon(
                                    Icons.arrow_right_alt,
                                    size: 20,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              Builder(
                                builder: (context) {
                                  final segment = displaySegments[i];
                                  final isWalk =
                                      segment.mode == TravelMode.walk;

                                  final lineName = isWalk
                                      ? formatDistance(segment.distanceMeters)
                                      : (segment.routeShortName ??
                                            'Unknown line');

                                  final color = isWalk
                                      ? theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                      : (lineColors[lineName] ??
                                            theme.colorScheme.primary);

                                  final textColor = isWalk
                                      ? theme.colorScheme.onSurface
                                      : (color.computeLuminance() > 0.5
                                            ? Colors.black87
                                            : Colors.white);

                                  final String? iconPath =
                                      (!isWalk && routeIconResolver != null)
                                      ? routeIconResolver!(lineName)
                                      : null;

                                  IconData getTransportIcon(
                                    RouteSegment segment,
                                  ) {
                                    if (segment.mode == TravelMode.walk) {
                                      return Icons.directions_walk;
                                    }
                                    if (segment.isFerry) {
                                      return Icons.directions_boat;
                                    }
                                    if (segment.isBus) {
                                      return Icons.directions_bus;
                                    }
                                    return Icons.directions_transit;
                                  }

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: iconPath != null
                                          ? color.withValues(alpha: 0.15)
                                          : color,
                                      border: iconPath != null
                                          ? Border.all(color: color)
                                          : null,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (iconPath != null) ...[
                                          SvgPicture.asset(
                                            iconPath,
                                            height: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            lineName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ] else ...[
                                          Icon(
                                            getTransportIcon(segment),
                                            size: 16,
                                            color: textColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            lineName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                        ],
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
                          Icon(
                            Icons.route,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            distanceText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.signpost,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${stops.length} stops',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (isSelected)
                        Row(
                          children: [
                            IconButton.filledTonal(
                              onPressed: onViewDetails,
                              icon: const Icon(Icons.info_outline, size: 20),
                              constraints: const BoxConstraints.tightFor(
                                width: 40,
                                height: 40,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: 'Details',
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: onStartNavigation,
                              icon: const Icon(Icons.navigation, size: 20),
                              constraints: const BoxConstraints.tightFor(
                                width: 40,
                                height: 40,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: 'Go',
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
  const _TagPill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(color);
    final textColor = isDark
        ? hsl.withLightness(hsl.lightness.clamp(0.7, 1.0)).toColor()
        : hsl.withLightness(hsl.lightness.clamp(0.2, 0.4)).toColor();
    final bgColor = color.withValues(alpha: isDark ? 0.25 : 0.15);

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );

    return content;
  }
}
