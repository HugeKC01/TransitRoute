import re

with open("lib/widgets/station_details_content.dart", "r") as f:
    text = f.read()

# Add transitTypeResolver definition
text = text.replace("final String? Function(String lineName)? lineIconByName;",
    "final String? Function(String lineName)? lineIconByName;\n  final String Function(gtfs.Stop stop)? transitTypeResolver;")
text = text.replace("this.lineIconByName,",
    "this.lineIconByName,\n    this.transitTypeResolver,")

start_str = "Widget _buildCompactTransfersList("
end_str = "Widget _buildInfoChips("

start_idx = text.find(start_str)
end_idx = text.find(end_str)

new_methods = """  Map<String, List<gtfs.Stop>> _groupTransfersByType() {
    final groups = <String, List<gtfs.Stop>>{};
    for (final tStop in transferStops) {
      final type = transitTypeResolver?.call(tStop) ?? 'Other';
      if (!groups.containsKey(type)) {
        groups[type] = [];
      }
      groups[type]!.add(tStop);
    }
    return groups;
  }

  Widget _buildTransferGroup(BuildContext context, ThemeData theme, ColorScheme scheme, String title, List<gtfs.Stop> stops, Widget Function(gtfs.Stop) builder, bool initiallyExpanded) {
    if (stops.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        title: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: scheme.primary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stops.map((s) => builder(s)).toList(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCompactTransfersList(BuildContext context, ThemeData theme, ColorScheme scheme) {
    final groups = _groupTransfersByType();
    final currentType = transitTypeResolver?.call(stop) ?? 'Other';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.map((entry) {
        bool initiallyExpanded = entry.key == currentType || groups.length == 1;
        return _buildTransferGroup(
          context, theme, scheme, entry.key, entry.value,
          (tStop) => _buildCompactTransferItem(context, theme, scheme, tStop),
          initiallyExpanded
        );
      }).toList(),
    );
  }

  Widget _buildCompactTransferItem(BuildContext context, ThemeData theme, ColorScheme scheme, gtfs.Stop tStop) {
    final tLineName = lineNameResolver?.call(tStop.stopId) ?? 'Unknown Line';
    final tLineColor = lineColorResolver?.call(tStop.stopId) ?? Colors.grey;

    final isSameName = (tStop.name == stop.name) || (tStop.thaiName == stop.thaiName && stop.thaiName != null);

    String? tIconPath;
    if (lineIconByName != null) {
      final names = tLineName.split(', ');
      for (final n in names) {
        final p = lineIconByName!(n);
        if (p != null && p.isNotEmpty) {
          tIconPath = p;
          break;
        }
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTransferStationSelected?.call(tStop),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tLineColor.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [BoxShadow(color: tLineColor.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tIconPath != null)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: tLineColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: SvgPicture.asset(tIconPath, width: 18, height: 18),
                )
              else
                Container(width: 16, height: 16, decoration: BoxDecoration(color: tLineColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSameName ? tLineName.split(', ').first : ((tStop.thaiName != null && tStop.thaiName!.trim().isNotEmpty) ? tStop.thaiName! : tStop.name),
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: scheme.onSurface),
                  ),
                  if (!isSameName)
                    Text(tLineName.split(', ').first, style: theme.textTheme.labelSmall?.copyWith(color: tLineColor, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullTransfersList(BuildContext context, ThemeData theme, ColorScheme scheme) {
    final groups = _groupTransfersByType();
    final currentType = transitTypeResolver?.call(stop) ?? 'Other';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.map((entry) {
        bool initiallyExpanded = entry.key == currentType || groups.length == 1;
        // Notice we still use a Wrap in _buildTransferGroup, so we wrap the Full cards which makes them flow horizontally or stack.
        // Wait, full cards might want to take full width? Let's fix that in builder if needed.
        return _buildTransferGroup(
          context, theme, scheme, entry.key, entry.value,
          (tStop) => _buildFullTransferItem(context, theme, scheme, tStop),
          initiallyExpanded
        );
      }).toList(),
    );
  }

  Widget _buildFullTransferItem(BuildContext context, ThemeData theme, ColorScheme scheme, gtfs.Stop tStop) {
    final tLineName = lineNameResolver?.call(tStop.stopId) ?? 'Unknown Line';
    final tLineColor = lineColorResolver?.call(tStop.stopId) ?? Colors.grey;

    String? tIconPath;
    if (lineIconByName != null) {
      final names = tLineName.split(', ');
      for (final n in names) {
        final p = lineIconByName!(n);
        if (p != null && p.isNotEmpty) {
          tIconPath = p;
          break;
        }
      }
    }

    return Container(
      width: double.infinity, // force to fill width inside the wrap
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onTransferStationSelected?.call(tStop),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tLineColor.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [BoxShadow(color: tLineColor.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                if (tIconPath != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: tLineColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: SvgPicture.asset(tIconPath, width: 24, height: 24),
                  )
                else
                  Container(width: 20, height: 20, decoration: BoxDecoration(color: tLineColor, shape: BoxShape.circle)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (tStop.thaiName != null && tStop.thaiName!.trim().isNotEmpty) ? tStop.thaiName! : tStop.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tLineName.split(', ').map((sl) {
                          final slColor = lineColorByName?.call(sl) ?? tLineColor;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: slColor, borderRadius: BorderRadius.circular(6)),
                            child: Text(sl, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: tLineColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  """

text = text[:start_idx] + new_methods + text[end_idx:]

with open("lib/widgets/station_details_content.dart", "w") as f:
    f.write(text)
