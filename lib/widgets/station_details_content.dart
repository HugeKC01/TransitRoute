import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;
import 'package:route/widgets/station_timetable.dart';
import 'package:route/widgets/upcoming_departures.dart';
import 'package:route/pages/station_details_page.dart';

class StationDetailsContent extends StatelessWidget {
  final gtfs.Stop stop;
  final Color lineColor;
  final String? lineName;
  final VoidCallback onSelectAsStart;
  final VoidCallback onSelectAsDestination;
  final List<gtfs.Stop> transferStops;
  final String? Function(String stopId)? lineNameResolver;
  final Color Function(String stopId)? lineColorResolver;
  final Color Function(String lineName)? lineColorByName;
  final String? Function(String lineName)? routeIconByName;
  final void Function(gtfs.Stop stop)? onTransferStationSelected;
  final VoidCallback? onClose;
  final bool isBottomSheet;
  final bool isSidePanel;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const StationDetailsContent({
    super.key,
    required this.stop,
    required this.lineColor,
    this.lineName,
    required this.onSelectAsStart,
    required this.onSelectAsDestination,
    this.transferStops = const [],
    this.lineNameResolver,
    this.lineColorResolver,
    this.lineColorByName,
    this.routeIconByName,
    this.onTransferStationSelected,
    this.onClose,
    this.isBottomSheet = false,
    this.isSidePanel = false,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  bool get _hasThaiName =>
      stop.thaiName != null && stop.thaiName!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroCard(context, theme, scheme),
        const SizedBox(height: 16),
        _buildQuickActionButtons(context),
        const SizedBox(height: 24),

        if (isBottomSheet) ...[
          _SectionHeader('Upcoming Departures'),
          const SizedBox(height: 12),
          UpcomingDeparturesWidget(stopId: stop.stopId),
          const SizedBox(height: 24),
          if (transferStops.isNotEmpty) ...[
            _SectionHeader('Transfers'),
            const SizedBox(height: 12),
            _buildFullTransfersList(context, theme, scheme),
            const SizedBox(height: 24),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () {
                if (isBottomSheet && !isSidePanel) {
                  Navigator.pop(context);
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => StationDetailsPage(
                      stop: stop,
                      lineColor: lineColor,
                      lineName: lineName,
                      onSelectAsStart: onSelectAsStart,
                      onSelectAsDestination: onSelectAsDestination,
                      transferStops: transferStops,
                      lineNameResolver: lineNameResolver,
                      lineColorResolver: lineColorResolver,
                      lineColorByName: lineColorByName,
                      routeIconByName: routeIconByName,
                      isFavorite: isFavorite,
                      onToggleFavorite: onToggleFavorite,
                      onTransferStationSelected: onTransferStationSelected,
                    ),
                  ),
                );
              },
              child: const Text('More Details'),
            ),
          ),
        ] else ...[
          if (stop.desc != null &&
              stop.desc!.isNotEmpty &&
              stop.desc != '0' &&
              stop.desc != '1') ...[
            _SectionHeader('About'),
            const SizedBox(height: 8),
            Text(
              stop.desc!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (transferStops.isNotEmpty) ...[
            _SectionHeader('Transfers'),
            const SizedBox(height: 12),
            _buildFullTransfersList(context, theme, scheme),
            const SizedBox(height: 24),
          ],
          _SectionHeader('Timetable & Departures'),
          const SizedBox(height: 12),
          StationTimetableSection(stopId: stop.stopId),
          const SizedBox(height: 24),
          _SectionHeader('Details'),
          const SizedBox(height: 12),
          _buildInfoChips(context, theme, scheme),
        ],
      ],
    );

    final padding = isSidePanel
        ? const EdgeInsets.fromLTRB(16, 0, 16, 16)
        : EdgeInsets.fromLTRB(
            16,
            isBottomSheet ? 8 : 16,
            16,
            MediaQuery.of(context).padding.bottom + 24,
          );

    if (isSidePanel) {
      return Padding(padding: padding, child: content);
    }

    return SingleChildScrollView(padding: padding, child: content);
  }

  Widget _buildHeroCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    bool isFerry =
        stop.stopId.startsWith('F_') || stop.stopId.startsWith('CRF_');
    bool isBRT = stop.stopId.startsWith('BRT');
    
    bool isRailLine = lineName != null && 
        (lineName!.contains('BTS') || 
         lineName!.contains('MRT') || 
         lineName!.contains('SRT') || 
         lineName!.contains('ARL') ||
         lineName!.contains('Metro') ||
         lineName!.contains('Line'));

    bool isBus =
        !isFerry &&
        !isRailLine &&
        (stop.stopId.startsWith('ST_') ||
            stop.stopId.startsWith('STOP_') ||
            int.tryParse(stop.stopId) != null ||
            stop.stopId.startsWith('BUS_') ||
            (stop.stopId.startsWith('B') && !stop.stopId.startsWith('BL') && !stop.stopId.startsWith('BKK')) ||
            isBRT ||
            (lineName != null &&
                (lineName!.contains('Bus') || lineName!.contains('BMTA'))));

    String displayCode = stop.code ?? '';
    if (isFerry) displayCode = stop.stopId;
    if (isBus && !isBRT) displayCode = '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : lineColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Builder(
                  builder: (context) {
                    String? routeIcon;
                    if (lineName != null &&
                        lineName!.isNotEmpty &&
                        routeIconByName != null) {
                      final lines = lineName!.split(', ');
                      for (var line in lines) {
                        routeIcon = routeIconByName!(line);
                        if (routeIcon != null && routeIcon.isNotEmpty) break;
                      }
                    }

                    if (routeIcon != null && routeIcon.isNotEmpty) {
                      return SizedBox(
                        width: 28,
                        height: 28,
                        child: SvgPicture.asset(
                          routeIcon,
                          width: 28,
                          height: 28,
                        ),
                      );
                    }
                    if (isFerry) {
                      return Icon(
                        Icons.directions_boat,
                        color: lineColor,
                        size: 28,
                      );
                    }
                    if (isBus) {
                      return Icon(
                        Icons.directions_bus,
                        color: lineColor,
                        size: 28,
                      );
                    }
                    return Icon(
                      Icons.directions_transit,
                      color: lineColor,
                      size: 28,
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hasThaiName ? stop.thaiName! : stop.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_hasThaiName)
                            Text(
                              stop.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (onToggleFavorite != null)
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                        ),
                        color: isFavorite
                            ? Colors.red
                            : scheme.onSurfaceVariant,
                        onPressed: onToggleFavorite,
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.surface.withValues(
                            alpha: 0.8,
                          ),
                          padding: const EdgeInsets.all(8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (onClose != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: onClose,
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.surface.withValues(
                            alpha: 0.8,
                          ),
                          padding: const EdgeInsets.all(8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if ((displayCode.isNotEmpty) ||
              (lineName != null && lineName!.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: (displayCode.isNotEmpty)
                        ? Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: lineColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                displayCode,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: lineColor.computeLuminance() > 0.5
                                      ? Colors.black87
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: (lineName != null && lineName!.isNotEmpty)
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              return Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: lineName!.split(', ').map((
                                  singleLine,
                                ) {
                                  final specificColor =
                                      lineColorByName?.call(singleLine) ??
                                      lineColor;
                                  return Container(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: specificColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      singleLine,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color:
                                                specificColor
                                                        .computeLuminance() >
                                                    0.5
                                                ? Colors.black87
                                                : Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onSelectAsStart,
            icon: const Icon(Icons.trip_origin),
            label: const Text('Origin'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onSelectAsDestination,
            icon: const Icon(Icons.flag),
            label: const Text('Destination'),
          ),
        ),
      ],
    );
  }

  Widget _buildFullTransfersList(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    return _TransferListWithTabs(
      transferStops: transferStops,
      lineNameResolver: lineNameResolver,
      lineColorResolver: lineColorResolver,
      lineColorByName: lineColorByName,
      routeIconByName: routeIconByName,
      onTransferStationSelected: onTransferStationSelected,
      theme: theme,
      scheme: scheme,
    );
  }

  Widget _buildInfoChips(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (stop.code != null && stop.code!.isNotEmpty)
          _InfoChip(label: 'Code', value: stop.code!),
        if (stop.zoneId != null && stop.zoneId!.isNotEmpty)
          _InfoChip(label: 'Zone', value: stop.zoneId!),
        _InfoChip(
          label: 'Coordinates',
          value:
              '${stop.lat.toStringAsFixed(4)}, ${stop.lon.toStringAsFixed(4)}',
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferListWithTabs extends StatefulWidget {
  final List<gtfs.Stop> transferStops;
  final String? Function(String stopId)? lineNameResolver;
  final Color Function(String stopId)? lineColorResolver;
  final Color Function(String lineName)? lineColorByName;
  final String? Function(String lineName)? routeIconByName;
  final void Function(gtfs.Stop stop)? onTransferStationSelected;
  final ThemeData theme;
  final ColorScheme scheme;

  const _TransferListWithTabs({
    required this.transferStops,
    this.lineNameResolver,
    this.lineColorResolver,
    this.lineColorByName,
    this.routeIconByName,
    this.onTransferStationSelected,
    required this.theme,
    required this.scheme,
  });

  @override
  State<_TransferListWithTabs> createState() => _TransferListWithTabsState();
}

class _TransferListWithTabsState extends State<_TransferListWithTabs> {
  String _selectedCategory = 'All';

  String _getCategory(String stopId) {
    if (stopId.startsWith('F_') || stopId.startsWith('CRF_')) return 'Ferry';
    
    final lineName = widget.lineNameResolver?.call(stopId) ?? '';
    
    if (lineName.contains('BTS') || lineName.contains('MRT')) return 'Metro';
    if (lineName.contains('SRT') || lineName.contains('ARL') || lineName.contains('Line')) return 'Train';

    if (lineName.contains('Bus') || lineName.contains('BMTA') || lineName.contains('BRT')) {
       return 'Bus';
    }
    if (lineName.contains('Ferry') || lineName.contains('Boat') || lineName.contains('Chao Phraya')) return 'Ferry';

    if (stopId.startsWith('BUS_') ||
        stopId.startsWith('ST_') ||
        stopId.startsWith('STOP_') ||
        stopId.startsWith('BRT') ||
        int.tryParse(stopId) != null ||
        stopId.startsWith('B') ||
        stopId.length > 5) {
      return 'Bus';
    }
    return 'Metro';
  }

  @override
  Widget build(BuildContext context) {
    final categories = {'All'};
    for (final s in widget.transferStops) {
      categories.add(_getCategory(s.stopId));
    }

    int catWeight(String c) {
      if (c == 'All') return 0;
      if (c == 'Metro') return 1;
      if (c == 'Train') return 2;
      if (c == 'Ferry') return 3;
      if (c == 'Bus') return 4;
      return 5;
    }

    final catsList = categories.toList()
      ..sort((a, b) => catWeight(a).compareTo(catWeight(b)));

    final displayCategories = _selectedCategory == 'All'
        ? catsList.where((c) => c != 'All').toList()
        : [_selectedCategory];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (catsList.length > 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: 8,
                children: catsList.map((cat) {
                  return ChoiceChip(
                    label: Text(cat),
                    selected: _selectedCategory == cat,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ...displayCategories.map((cat) {
          final stopsInCat = widget.transferStops
              .where((s) => _getCategory(s.stopId) == cat)
              .toList();

          if (stopsInCat.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedCategory == 'All' && displayCategories.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
                  child: Row(
                    children: [
                      Icon(
                        cat == 'Bus'
                            ? Icons.directions_bus
                            : cat == 'Ferry'
                                ? Icons.directions_boat
                                : cat == 'Metro'
                                    ? Icons.subway
                                    : Icons.train,
                        size: 18,
                        color: widget.scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat,
                        style: widget.theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: widget.scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.only(bottom: _selectedCategory == 'All' && displayCategories.length > 1 ? 8 : 0),
                itemCount: stopsInCat.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final tStop = stopsInCat[index];
                  final tLineName =
                      widget.lineNameResolver?.call(tStop.stopId) ??
                      'Unknown Line';
                  final tLineColor =
                      widget.lineColorResolver?.call(tStop.stopId) ??
                      Colors.grey;

                  IconData defaultIcon = Icons.train;
                  if (cat == 'Bus') {
                    defaultIcon = Icons.directions_bus;
                  } else if (cat == 'Ferry') {
                    defaultIcon = Icons.directions_boat;
                  } else if (cat == 'Metro') {
                    defaultIcon = Icons.subway;
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => widget.onTransferStationSelected?.call(tStop),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: widget.scheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.scheme.outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: tLineColor.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child:
                                Icon(defaultIcon, size: 16, color: tLineColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (tStop.thaiName != null &&
                                          tStop.thaiName!.trim().isNotEmpty)
                                      ? tStop.thaiName!
                                      : tStop.name,
                                  style: widget.theme.textTheme.titleSmall
                                      ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Builder(
                                  builder: (context) {
                                    final lines = tLineName.split(', ');
                                    lines.sort((a, b) {
                                      int lineWeight(String l) {
                                        if (l.contains('BTS') || l.contains('MRT')) return 1;
                                        if (l.contains('SRT') || l.contains('ARL') || l.contains('Line')) return 2;
                                        if (l.contains('Ferry') || l.contains('Boat') || l.contains('Chao Phraya')) return 3;
                                        if (l.contains('Bus') || l.contains('BMTA') || l.contains('BRT')) return 4;
                                        return 5;
                                      }
                                      return lineWeight(a).compareTo(lineWeight(b));
                                    });

                                    final displayLines = lines.take(3).toList();
                                    final extra = lines.length - 3;
                                    
                                    return Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        ...displayLines.map((sl) {
                                          final slColor = widget.lineColorByName?.call(sl) ?? tLineColor;
                                          String? routeSvg;
                                          if (widget.routeIconByName != null) {
                                            routeSvg = widget.routeIconByName!(sl);
                                          }
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: slColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (routeSvg != null && routeSvg.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(right: 4),
                                                    child: SvgPicture.asset(routeSvg, width: 14, height: 14),
                                                  ),
                                                Text(
                                                  sl,
                                                  style: widget.theme.textTheme.bodySmall?.copyWith(
                                                    color: slColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                        if (extra > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: widget.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '+$extra',
                                              style: widget.theme.textTheme.bodySmall?.copyWith(
                                                color: widget.theme.colorScheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        }),
      ],
    );
  }
}

