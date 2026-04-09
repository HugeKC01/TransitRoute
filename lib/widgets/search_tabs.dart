import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/gtfs_models.dart' as gtfs;

import 'custom_dropdown.dart';

class ServiceTabs extends StatefulWidget {
  final List<gtfs.Stop> allStops;
  final List<gtfs.Stop> busStops;
  final Map<String, List<String>> linePrefixes;
  final Map<String, Color> lineColors;
  final String? Function(String) getLineName;
  final List<String> Function(String)? getLineNames;
  final void Function(gtfs.Stop) onSelect;
  final int Function(gtfs.Stop) getServicePriority;
  final String? Function(String)? routeIconByName;

  const ServiceTabs({
    super.key,
    required this.allStops,
    required this.busStops,
    required this.linePrefixes,
    required this.lineColors,
    required this.getLineName,
    this.getLineNames,
    required this.onSelect,
    required this.getServicePriority,
    this.routeIconByName,
  });

  @override
  State<ServiceTabs> createState() => _ServiceTabsState();
}

class _ServiceTabsState extends State<ServiceTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String? _selectedMetroLine;
  String? _selectedTrainLine;
  String? _selectedBusLine;
  String? _selectedFerryLine;

  late Map<String, List<gtfs.Stop>> _metroStops;
  late Map<String, List<gtfs.Stop>> _trainStops;
  late Map<String, List<gtfs.Stop>> _busStops;
  late Map<String, List<gtfs.Stop>> _ferryStops;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _calculateStops();
  }

  @override
  void didUpdateWidget(ServiceTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allStops != oldWidget.allStops) {
      _calculateStops();
    }
  }

  void _calculateStops() {
    _metroStops = {};
    _trainStops = {};
    _busStops = {};
    _ferryStops = {};

    for (final stop in widget.allStops) {
      final priority = widget.getServicePriority(stop);
      final targetMap = switch (priority) {
        1 => _metroStops,
        2 => _trainStops,
        3 => _busStops,
        _ => _ferryStops,
      };

      if (widget.getLineNames != null) {
        final lineNames = widget.getLineNames!(stop.stopId);
        if (lineNames.isEmpty) {
          targetMap.putIfAbsent('Unknown', () => []).add(stop);
        } else {
          for (final lineName in lineNames) {
            targetMap.putIfAbsent(lineName, () => []).add(stop);
          }
        }
      } else {
        final lineName = widget.getLineName(stop.stopId) ?? 'Unknown';
        targetMap.putIfAbsent(lineName, () => []).add(stop);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildStopTile(
    BuildContext context,
    gtfs.Stop stop,
    String lineName, [
    int serviceType = 3,
  ]) {
    final lineColor = widget.lineColors[lineName] ?? Colors.grey;
    final theme = Theme.of(context);

    IconData getIconForType(int type) {
      switch (type) {
        case 1:
          return Icons.subway;
        case 2:
          return Icons.train;
        case 3:
          return Icons.directions_bus;
        case 4:
          return Icons.directions_boat;
        default:
          return Icons.directions_transit;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: theme.colorScheme.surface.withValues(
            alpha: 0.9,
          ), // adjusted opacity to compensate for lack of blue
          child: InkWell(
            onTap: () => widget.onSelect(stop),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      String? routeIcon;
                      if (serviceType == 1 && widget.routeIconByName != null) {
                        routeIcon = widget.routeIconByName!(lineName);
                      }

                      if (routeIcon != null && routeIcon.isNotEmpty) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: lineColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: SvgPicture.asset(
                                routeIcon,
                                width: 24,
                                height: 24,
                              ),
                            ),
                            if (stop.code != null && stop.code!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: lineColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  stop.code!,
                                  style: TextStyle(
                                    color: (lineColor.computeLuminance() > 0.5)
                                        ? Colors.black87
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: lineColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.5,
                            ),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: lineColor.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              getIconForType(serviceType),
                              color: (lineColor.computeLuminance() > 0.5)
                                  ? Colors.black87
                                  : Colors.white,
                              size: 16,
                            ),
                            if (stop.code != null && stop.code!.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                stop.code!,
                                style: TextStyle(
                                  color: (lineColor.computeLuminance() > 0.5)
                                      ? Colors.black87
                                      : Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (stop.thaiName != null && stop.thaiName!.isNotEmpty)
                          Text(
                            stop.thaiName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabView(
    BuildContext context, {
    required Map<String, List<gtfs.Stop>> groupedStops,
    required String? selectedLine,
    required ValueChanged<String?> onLineChanged,
  }) {
    final lines = groupedStops.keys.toList()..sort();
    final effectiveSelectedLine =
        (selectedLine != null && lines.contains(selectedLine))
        ? selectedLine
        : null;

    final List<({bool isHeader, String line, gtfs.Stop? stop})> listItems = [];
    if (effectiveSelectedLine == null) {
      for (final line in lines) {
        listItems.add((isHeader: true, line: line, stop: null));
        for (final stop in groupedStops[line]!) {
          listItems.add((isHeader: false, line: line, stop: stop));
        }
      }
    } else {
      for (final stop in groupedStops[effectiveSelectedLine]!) {
        listItems.add((
          isHeader: false,
          line: effectiveSelectedLine,
          stop: stop,
        ));
      }
    }

    return Column(
      children: [
        if (lines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: CustomInlineDropdown<String>(
                value: effectiveSelectedLine,
                items: lines,
                itemLabel: (item) => item ?? 'All Lines',
                itemLeading: (item) {
                  if (item == null) return null;
                  final color = widget.lineColors[item] ?? Colors.grey;
                  if (widget.routeIconByName != null) {
                    final routeIcon = widget.routeIconByName!(item);
                    if (routeIcon != null && routeIcon.isNotEmpty) {
                      return SizedBox(
                        width: 20,
                        height: 20,
                        child: SvgPicture.asset(
                          routeIcon,
                          width: 20,
                          height: 20,
                        ),
                      );
                    }
                  }
                  return Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  );
                },
                onChanged: onLineChanged,
              ),
            ),
          ),
        Expanded(
          child: listItems.isEmpty
              ? const Center(child: Text('No stations available'))
              : ListView.builder(
                  itemCount: listItems.length,
                  itemBuilder: (context, index) {
                    final item = listItems[index];

                    if (item.isHeader) {
                      final color = widget.lineColors[item.line] ?? Colors.grey;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index != 0) const Divider(height: 1),
                          Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: Row(
                              children: [
                                Builder(
                                  builder: (context) {
                                    if (widget.routeIconByName != null) {
                                      final routeIcon = widget.routeIconByName!(
                                        item.line,
                                      );
                                      if (routeIcon != null &&
                                          routeIcon.isNotEmpty) {
                                        return SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: SvgPicture.asset(
                                            routeIcon,
                                            width: 16,
                                            height: 16,
                                          ),
                                        );
                                      }
                                    }
                                    return Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.line,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else if (item.stop != null) {
                      return _buildStopTile(
                        context,
                        item.stop!,
                        item.line,
                        widget.getServicePriority(item.stop!),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isWideWindow = mediaQuery.size.width > 600;
    // On wide windows, let it take more space but stick to the left.
    final height = mediaQuery.size.height * (isWideWindow ? 0.8 : 0.7);

    Widget mainContent = SizedBox(
      height: height,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Metro'),
              Tab(text: 'Train'),
              Tab(text: 'Bus'),
              Tab(text: 'Ferry'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabView(
                  context,
                  groupedStops: _metroStops,
                  selectedLine: _selectedMetroLine,
                  onLineChanged: (val) =>
                      setState(() => _selectedMetroLine = val),
                ),
                _buildTabView(
                  context,
                  groupedStops: _trainStops,
                  selectedLine: _selectedTrainLine,
                  onLineChanged: (val) =>
                      setState(() => _selectedTrainLine = val),
                ),
                _buildTabView(
                  context,
                  groupedStops: _busStops,
                  selectedLine: _selectedBusLine,
                  onLineChanged: (val) =>
                      setState(() => _selectedBusLine = val),
                ),
                _buildTabView(
                  context,
                  groupedStops: _ferryStops,
                  selectedLine: _selectedFerryLine,
                  onLineChanged: (val) =>
                      setState(() => _selectedFerryLine = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
      child: mainContent,
    );
  }
}
