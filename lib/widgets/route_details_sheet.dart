import 'package:flutter/material.dart';
import 'package:route/services/direction_service.dart';
import 'package:route/services/fare_calculator.dart';
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
    final mCount = option.fareBreakdown['mCount'] ?? 0;
    final mPrice = option.fareBreakdown['mPrice'] ?? 0;
    final sCount = option.fareBreakdown['sCount'] ?? 0;
    final sPrice = option.fareBreakdown['sPrice'] ?? 0;
    final mrtSrtFares = _mrtSrtFaresFrom(option.fareBreakdown);
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
          const SizedBox(height: 16),
          Text('Fare sections', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FareSectionTile(
                title: 'Main network',
                color: theme.colorScheme.primary,
                subtitle: '$mCount segments',
                price: mPrice,
              ),
              FareSectionTile(
                title: 'Secondary network',
                color: theme.colorScheme.secondary,
                subtitle: '$sCount segments',
                price: sPrice,
              ),
              ...mrtSrtFares.map(
                (fare) => FareSectionTile(
                  title: fare.lineName,
                  color:
                      lineColors[fare.lineName] ?? theme.colorScheme.tertiary,
                  subtitle: '${fare.stopCount} stations (max 8 charged)',
                  price: fare.price,
                ),
              ),
            ],
          ),
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
                final lineName =
                    lineNameResolver(first.stopId) ?? 'Unknown line';
                final color =
                    lineColors[lineName] ?? lineColorResolver(first.stopId);
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

class FareSectionTile extends StatelessWidget {
  const FareSectionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.color,
  });

  final String title;
  final String subtitle;
  final int price;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceText = '฿$price';
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 10,
                width: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text(
                priceText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          Text(
            title,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LineFareBreakdown {
  const _LineFareBreakdown(
    this.lineName,
    this.stopCount,
    this.price,
  );

  final String lineName;
  final int stopCount;
  final int price;
}

List<_LineFareBreakdown> _mrtSrtFaresFrom(Map<String, int> breakdown) {
  final prefix = kMrtSrtFarePrefix;
  final countSuffix = kMrtSrtCountSuffix;
  final priceSuffix = kMrtSrtPriceSuffix;
  final buffer = <String, Map<String, int>>{};
  breakdown.forEach((key, value) {
    if (!key.startsWith(prefix)) return;
    if (key.endsWith(countSuffix)) {
      final line = key.substring(prefix.length, key.length - countSuffix.length);
      buffer.putIfAbsent(line, () => <String, int>{})['count'] = value;
    } else if (key.endsWith(priceSuffix)) {
      final line = key.substring(prefix.length, key.length - priceSuffix.length);
      buffer.putIfAbsent(line, () => <String, int>{})['price'] = value;
    }
  });
  final result = <_LineFareBreakdown>[];
  buffer.forEach((line, values) {
    final count = values['count'] ?? 0;
    final price = values['price'] ?? 0;
    if (count <= 0 && price <= 0) return;
    result.add(_LineFareBreakdown(line, count, price));
  });
  result.sort((a, b) => a.lineName.compareTo(b.lineName));
  return result;
}
