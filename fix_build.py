import sys

with open("lib/pages/transport_lines_details_page.dart", "r") as f:
    text = f.read()

build_idx = text.find("  @override\n  Widget build(BuildContext context) {")
if build_idx == -1:
    print("Could not find build function")
    sys.exit(1)

new_build = '''  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final route_info = widget.route;
    final agency = widget.agency;

    final routeColor = _colorFromHexOr(route_info.color, theme.colorScheme.primary);
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    final headerSection = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 32.0,
          horizontal: 16.0,
        ),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : routeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: routeColor, width: 3),
              ),
              child: Center(
                child: route_info.routeIcon != null &&
                        route_info.routeIcon!.isNotEmpty
                    ? SizedBox(
                        width: 48,
                        height: 48,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SvgPicture.asset(
                            route_info.routeIcon!,
                          ),
                        ),
                      )
                    : Icon(
                        _iconForCategory(_transportCategory(route_info.type)),
                        size: 48,
                        color: routeColor,
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              route_info.longName.isNotEmpty ? route_info.longName : route_info.routeId,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!_loading && _routeStops.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_routeStops.first.name} - ${_routeStops.last.name}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final infoSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Information',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              _buildInfoTile(
                icon: Icons.directions_transit,
                title: 'Transport Type',
                subtitle: _transportCategory(route_info.type),
                theme: theme,
              ),
              const Divider(height: 1),
              _buildInfoTile(
                icon: Icons.business,
                title: 'Operating Agency',
                subtitle: agency?.name.isNotEmpty == true
                    ? agency!.name
                    : (route_info.agencyId.isNotEmpty
                          ? route_info.agencyId
                          : 'Unknown Agency'),
                theme: theme,
              ),
              if (agency?.url.isNotEmpty == true) ...[
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.language,
                  title: 'Website',
                  subtitle: agency!.url,
                  theme: theme,
                ),
              ],
              if (widget.agency?.phone?.isNotEmpty == true) ...[
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.phone,
                  title: 'Contact Phone',
                  subtitle: widget.agency!.phone ?? '',
                  theme: theme,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final markers = _routeStops.map((stop) {
      return Marker(
        point: LatLng(stop.lat, stop.lon),
        width: 16,
        height: 16,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: routeColor, width: 3),
          ),
        ),
      );
    }).toList();

    var cLat = 13.7563;
    var cLon = 100.5018;
    if (_routeStops.isNotEmpty) {
      cLat = _routeStops.map((s) => s.lat).reduce((a, b) => a + b) / _routeStops.length;
      cLon = _routeStops.map((s) => s.lon).reduce((a, b) => a + b) / _routeStops.length;
    }

    final mapWidget = Container(
      height: isPortrait ? 250 : double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(isPortrait ? 24 : 0),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: isPortrait ? Clip.antiAlias : Clip.none,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(cLat, cLon),
          initialZoom: 12.0,
          interactionOptions: isPortrait 
              ? const InteractionOptions(flags: InteractiveFlag.none)
              : const InteractionOptions(flags: InteractiveFlag.all),
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: "com.example.transit_route",
          ),
          if (_lineShape.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _lineShape,
                  color: routeColor,
                  strokeWidth: 4.0,
                ),
              ],
            ),
          MarkerLayer(markers: markers),
        ],
      ),
    );

    final stopListSection = _loading
        ? const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          )
        : _routeStops.isNotEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Stations (${_routeStops.length})",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _routeStops.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final stop = _routeStops[index];
                        final hasThai = stop.thaiName != null && stop.thaiName!.trim().isNotEmpty;
                        final displayCode = (stop.code != null && stop.code!.trim().isNotEmpty) ? stop.code! : "${index + 1}";
                        return ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => route_main.MyHomePage(
                                  title: "Route Transit",
                                  currentAccentColor: theme.colorScheme.primary,
                                  onAccentColorChanged: (c) {},
                                  currentThemeMode: theme.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
                                  onThemeModeChanged: (m) {},
                                  initialViewingStop: stop,
                                ),
                              ),
                            );
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 4.0,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: routeColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: routeColor, width: 2),
                            ),
                            child: Center(
                              child: FittedBox(
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Text(
                                    displayCode,
                                    style: TextStyle(
                                      color: routeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            hasThai ? stop.thaiName! : stop.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: hasThai
                              ? Text(
                                  stop.name,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : null,
                          trailing: const Icon(
                            Icons.map,
                            size: 20,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
            : const SizedBox();

    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: routeColor,
          secondary: routeColor,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Route Details"),
          centerTitle: true,
        ),
        body: isPortrait
            ? ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  headerSection,
                  const SizedBox(height: 16),
                  if (!_loading && _routeStops.isNotEmpty) mapWidget,
                  const SizedBox(height: 32),
                  infoSection,
                  const SizedBox(height: 32),
                  stopListSection,
                ],
              )
            : Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        headerSection,
                        const SizedBox(height: 32),
                        infoSection,
                        const SizedBox(height: 32),
                        stopListSection,
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    flex: 6,
                    child: _loading ? const Center(child: CircularProgressIndicator()) : mapWidget,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      ),
      title: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
'''

text = text[:build_idx] + new_build

with open("lib/pages/transport_lines_details_page.dart", "w") as f:
    f.write(text)

