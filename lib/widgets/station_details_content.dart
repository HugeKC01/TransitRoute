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
            _buildCompactTransfersList(context, theme, scheme),
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
          if (stop.desc != null && stop.desc!.isNotEmpty && stop.desc != '0' && stop.desc != '1') ...[
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
                    return Icon(Icons.train, color: lineColor, size: 28);
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
                        color: isFavorite ? Colors.red : scheme.onSurfaceVariant,
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
          if ((stop.code != null && stop.code!.isNotEmpty) ||
              (lineName != null && lineName!.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: (stop.code != null && stop.code!.isNotEmpty)
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
                                stop.code!,
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

  Widget _buildCompactTransfersList(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: transferStops.map((tStop) {
            final tLineName =
                lineNameResolver?.call(tStop.stopId) ?? 'Unknown Line';
            final tLineColor =
                lineColorResolver?.call(tStop.stopId) ?? Colors.grey;

            final isSameName =
                (tStop.name == stop.name) ||
                (tStop.thaiName == stop.thaiName && stop.thaiName != null);

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onTransferStationSelected?.call(tStop),
              child: Container(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: tLineColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isSameName
                            ? tLineName
                            : ((tStop.thaiName != null &&
                                      tStop.thaiName!.trim().isNotEmpty)
                                  ? tStop.thaiName!
                                  : tStop.name),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFullTransfersList(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: transferStops.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tStop = transferStops[index];
        final tLineName =
            lineNameResolver?.call(tStop.stopId) ?? 'Unknown Line';
        final tLineColor = lineColorResolver?.call(tStop.stopId) ?? Colors.grey;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onTransferStationSelected?.call(tStop),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tLineColor,
                    shape: BoxShape.circle,
                  ),
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: tLineName.split(', ').map((sl) {
                          final slColor =
                              lineColorByName?.call(sl) ?? tLineColor;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: slColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              sl,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: slColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
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
