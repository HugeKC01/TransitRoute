import 'package:flutter/material.dart';
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
  final void Function(gtfs.Stop stop)? onTransferStationSelected;
  final bool isBottomSheet;
  final bool isSidePanel;

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
    this.onTransferStationSelected,
    this.isBottomSheet = false,
    this.isSidePanel = false,
  });

  bool get _hasThaiName =>
      stop.thaiName != null && stop.thaiName!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        isBottomSheet ? 8 : 16,
        16,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  if (isBottomSheet) {
                    Navigator.pop(context);
                  }
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false,
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (_, __, ___) => StationDetailsPage(
                        stop: stop,
                        lineColor: lineColor,
                        lineName: lineName,
                        onSelectAsStart: onSelectAsStart,
                        onSelectAsDestination: onSelectAsDestination,
                        transferStops: transferStops,
                        lineNameResolver: lineNameResolver,
                        lineColorResolver: lineColorResolver,
                        lineColorByName: lineColorByName,
                        onTransferStationSelected: onTransferStationSelected,
                      ),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                    ),
                  );
                },
                child: const Text('More Details'),
              ),
            ),
          ] else ...[
            if (stop.desc != null && stop.desc!.isNotEmpty) ...[
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
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lineColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.train, color: lineColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _hasThaiName ? stop.thaiName! : stop.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (stop.code != null && stop.code!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Text(
                          stop.code!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_hasThaiName)
                  Text(
                    stop.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (lineName != null && lineName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: lineName!.split(', ').map((singleLine) {
                        final specificColor =
                            lineColorByName?.call(singleLine) ?? lineColor;
                        return Container(
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
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: transferStops.map((tStop) {
        final tLineName =
            lineNameResolver?.call(tStop.stopId) ?? 'Unknown Line';
        final tLineColor = lineColorResolver?.call(tStop.stopId) ?? Colors.grey;

        final isSameName =
            (tStop.name == stop.name) ||
            (tStop.thaiName == stop.thaiName && stop.thaiName != null);

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onTransferStationSelected?.call(tStop),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                Text(
                  isSameName
                      ? tLineName
                      : ((tStop.thaiName != null &&
                                tStop.thaiName!.trim().isNotEmpty)
                            ? tStop.thaiName!
                            : tStop.name),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
