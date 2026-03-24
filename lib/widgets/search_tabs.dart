import 'package:flutter/material.dart';
import '../services/gtfs_models.dart' as gtfs;

class ServiceTabs extends StatefulWidget {
  final List<gtfs.Stop> allStops;
  final List<gtfs.Stop> busStops;
  final Map<String, List<String>> linePrefixes;
  final Map<String, Color> lineColors;
  final String? Function(String) getLineName;
  final List<String> Function(String)? getLineNames;
  final void Function(gtfs.Stop) onSelect;
  final int Function(gtfs.Stop) getServicePriority;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Group stops by line name
  Map<String, List<gtfs.Stop>> _groupStopsByLine(
    List<gtfs.Stop> stops,
    bool Function(String, gtfs.Stop) filterLine,
  ) {
    final Map<String, List<gtfs.Stop>> grouped = {};
    for (final stop in stops) {
      if (widget.getLineNames != null) {
        final lineNames = widget.getLineNames!(stop.stopId);
        if (lineNames.isEmpty) {
          if (filterLine('Unknown', stop)) {
            grouped.putIfAbsent('Unknown', () => []).add(stop);
          }
        } else {
          for (final lineName in lineNames) {
            if (filterLine(lineName, stop)) {
              grouped.putIfAbsent(lineName, () => []).add(stop);
            }
          }
        }
      } else {
        final lineName = widget.getLineName(stop.stopId) ?? 'Unknown';
        if (filterLine(lineName, stop)) {
          grouped.putIfAbsent(lineName, () => []).add(stop);
        }
      }
    }
    return grouped;
  }

  Widget _buildStopTile(BuildContext context, gtfs.Stop stop, String lineName) {
    final lineColor = widget.lineColors[lineName] ?? Colors.grey;
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lineColor,
          border: Border.all(color: theme.colorScheme.surface, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          stop.code ?? '',
          style: TextStyle(
            color: (lineColor.computeLuminance() > 0.5)
                ? Colors.black
                : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      title: Text(stop.name),
      subtitle: Text(
        (stop.thaiName != null && stop.thaiName!.isNotEmpty)
            ? stop.thaiName!
            : 'Thai Station provide later',
        style: theme.textTheme.bodySmall,
      ),
      onTap: () => widget.onSelect(stop),
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
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String?>(
              isExpanded: true,
              value: effectiveSelectedLine,
              underline: Container(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'All Lines',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                ...lines.map((line) {
                  final color = widget.lineColors[line] ?? Colors.grey;
                  return DropdownMenuItem<String?>(
                    value: line,
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: onLineChanged,
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
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
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
                      return _buildStopTile(context, item.stop!, item.line);
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
    final height =
        mediaQuery.size.height *
        0.7; // Take 70% of the screen height by default

    final metroStops = _groupStopsByLine(
      widget.allStops,
      (line, stop) => widget.getServicePriority(stop) == 1,
    );
    final trainStops = _groupStopsByLine(
      widget.allStops,
      (line, stop) => widget.getServicePriority(stop) == 2,
    );
    final busStops = _groupStopsByLine(
      widget.allStops,
      (line, stop) => widget.getServicePriority(stop) == 3,
    );
    final ferryStops = _groupStopsByLine(
      widget.allStops,
      (line, stop) => widget.getServicePriority(stop) == 4,
    );

    return SizedBox(
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
                  groupedStops: metroStops,
                  selectedLine: _selectedMetroLine,
                  onLineChanged: (val) =>
                      setState(() => _selectedMetroLine = val),
                ),
                _buildTabView(
                  context,
                  groupedStops: trainStops,
                  selectedLine: _selectedTrainLine,
                  onLineChanged: (val) =>
                      setState(() => _selectedTrainLine = val),
                ),
                _buildTabView(
                  context,
                  groupedStops: busStops,
                  selectedLine: _selectedBusLine,
                  onLineChanged: (val) =>
                      setState(() => _selectedBusLine = val),
                ),
                _buildTabView(
                  context,
                  groupedStops: ferryStops,
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
  }
}
