import 'package:flutter/material.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;

class StationDetailsPage extends StatelessWidget {
  const StationDetailsPage({
    super.key,
    required this.stop,
    required this.lineColor,
    this.lineName,
    required this.onSelectAsStart,
    required this.onSelectAsDestination,
  });

  final gtfs.Stop stop;
  final Color lineColor;
  final String? lineName;
  final VoidCallback onSelectAsStart;
  final VoidCallback onSelectAsDestination;

  bool get _hasThaiName =>
      stop.thaiName != null && stop.thaiName!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final infoChips = <Widget>[
      _InfoChip(label: 'Stop ID', value: stop.stopId),
      if (lineName != null && lineName!.isNotEmpty)
        _InfoChip(label: 'Line', value: lineName!),
      _InfoChip(
        label: 'Coordinates',
        value:
            'Lat ${stop.lat.toStringAsFixed(4)}, Lon ${stop.lon.toStringAsFixed(4)}',
      ),
      if (stop.zoneId != null && stop.zoneId!.isNotEmpty)
        _InfoChip(label: 'Zone', value: stop.zoneId!),
      if (stop.code != null && stop.code!.isNotEmpty)
        _InfoChip(label: 'Code', value: stop.code!),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(stop.name),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            _StationHeroCard(
              stop: stop,
              lineColor: lineColor,
              lineName: lineName,
              hasThaiName: _hasThaiName,
            ),
            const SizedBox(height: 24),
            const _SectionHeader('Station facts'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: infoChips,
            ),
            if (stop.desc != null && stop.desc!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _InfoCard(
                icon: Icons.subject,
                title: 'About this station',
                subtitle: stop.desc!,
              ),
            ],
            const SizedBox(height: 24),
            _InfoCard(
              icon: Icons.location_on_outlined,
              title: 'Exact location',
              subtitle:
                  'Lat ${stop.lat.toStringAsFixed(5)}, Lon ${stop.lon.toStringAsFixed(5)}',
            ),
            const SizedBox(height: 28),
            const _SectionHeader('Trip planning'),
            _QuickActionButtons(
              onSelectAsStart: onSelectAsStart,
              onSelectAsDestination: onSelectAsDestination,
            ),
            const SizedBox(height: 16),
            Text(
              'Tip: You can always swap origin and destination in the planner header.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButtons extends StatelessWidget {
  const _QuickActionButtons({
    required this.onSelectAsStart,
    required this.onSelectAsDestination,
  });

  final VoidCallback onSelectAsStart;
  final VoidCallback onSelectAsDestination;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onSelectAsStart,
            icon: const Icon(Icons.trip_origin),
            label: const Text('Use as origin'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onSelectAsDestination,
            icon: const Icon(Icons.flag),
            label: const Text('Use as destination'),
          ),
        ),
      ],
    );
  }
}

class _StationHeroCard extends StatelessWidget {
  const _StationHeroCard({
    required this.stop,
    required this.lineColor,
    required this.lineName,
    required this.hasThaiName,
  });

  final gtfs.Stop stop;
  final Color lineColor;
  final String? lineName;
  final bool hasThaiName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = LinearGradient(
      colors: [
        lineColor,
        lineColor.withValues(alpha: 0.75),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (hasThaiName)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          stop.thaiName!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.train,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (lineName != null && lineName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  lineName!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
