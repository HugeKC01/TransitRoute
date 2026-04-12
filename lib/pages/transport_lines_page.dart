import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:route/services/gtfs_models.dart' as gtfs;
import 'package:route/services/terminal_loader.dart';
import 'package:route/services/route_asset_loader.dart';
import 'package:route/pages/transport_lines_details_page.dart';

class TransportLinesPage extends StatefulWidget {
  const TransportLinesPage({super.key});

  @override
  State<TransportLinesPage> createState() => _TransportLinesPageState();
}

class _TransportLinesPageState extends State<TransportLinesPage> {
  List<gtfs.Route> routes = [];
  Map<String, gtfs.Agency> agencies = {};
  Map<String, String> routeTerminals = {};
  bool _loading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<gtfs.Route>> _loadBusRoutesFromStops() async {
    try {
      final content = await rootBundle.loadString(
        'assets/gtfs_data/bus_route_stop.txt',
      );
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return [];

      final Map<String, gtfs.Route> busR = {};
      for (int i = 1; i < lines.length; i++) {
        final row = _parseCsvLine(lines[i]);
        if (row.length > 5) {
          final rShortName = row[1].trim();
          if (rShortName.isEmpty) continue;
          final routeId = rShortName.split(' ')[0].trim();
          final desc = row[2].trim();
          final typeId = row[3].trim().toLowerCase();
          final agencyId = row[4].trim();

          String color = '0000FF';
          if (typeId.contains('air')) {
            color = '0068b3';
          } else if (typeId.contains('ngv')) {
            color = '1752b0';
          } else {
            color = 'ff0000';
          }

          if (!busR.containsKey(routeId)) {
            busR[routeId] = gtfs.Route(
              routeId: routeId,
              agencyId: agencyId,
              shortName: rShortName,
              longName: desc,
              type: '3',
              color: color,
              textColor: 'FFFFFF',
              routeIcon: null,
              linePrefixes: [],
            );
            // Pre-fill routeTerminals
            routeTerminals[routeId] = desc;
          } else {
            // Append to description if it's a different direction
            final existingDesc = busR[routeId]!.longName;
            if (!existingDesc.contains(desc.split('-')[0].trim())) {
              busR[routeId] = gtfs.Route(
                routeId: busR[routeId]!.routeId,
                agencyId: busR[routeId]!.agencyId,
                shortName: busR[routeId]!.shortName,
                longName: '$existingDesc / $desc',
                type: busR[routeId]!.type,
                color: busR[routeId]!.color,
                textColor: busR[routeId]!.textColor,
                routeIcon: busR[routeId]!.routeIcon,
                linePrefixes: busR[routeId]!.linePrefixes,
              );
              routeTerminals[routeId] = busR[routeId]!.longName;
            }
          }
        }
      }
      return busR.values.toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadRoutes() async {
    try {
      final loadedRoutes = <gtfs.Route>[];
      final agencyFuture = rootBundle.loadString('assets/gtfs_data/agency.txt');

      final mainRoutes = await RouteAssetLoader.loadRoutes(
        'assets/gtfs_data/routes.txt',
      );
      final ferryRoutes = await RouteAssetLoader.loadRoutes(
        'assets/gtfs_data/ferry_route.txt',
      );
      final busRoutes = await RouteAssetLoader.loadRoutes(
        'assets/gtfs_data/bus_route.txt',
      );
      final extraBusRoutes = await _loadBusRoutesFromStops();

      loadedRoutes.addAll(mainRoutes);
      loadedRoutes.addAll(ferryRoutes);
      loadedRoutes.addAll(busRoutes);
      loadedRoutes.addAll(extraBusRoutes);

      final agencyContent = await agencyFuture;
      final loadedAgencies = _parseAgencies(agencyContent);

      final terminals = await TerminalLoader.loadAllTerminals();

      setState(() {
        routes = loadedRoutes;
        agencies = loadedAgencies;
        // Merge so we don't overwrite the bus terminals we just populated
        routeTerminals.addAll(terminals);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading routes: $e');
      setState(() {
        routes = [];
        agencies = {};
        _loading = false;
      });
    }
  }

  Map<String, gtfs.Agency> _parseAgencies(String content) {
    final lines = const LineSplitter().convert(content);
    if (lines.length <= 1) return {};
    final header = _parseCsvLine(lines.first).map((e) => e.trim()).toList();
    final idxId = header.indexOf('agency_id');
    final idxName = header.indexOf('agency_name');
    final idxUrl = header.indexOf('agency_url');
    final idxTz = header.indexOf('agency_timezone');
    final idxLang = header.indexOf('agency_lang');
    final idxPhone = header.indexOf('agency_phone');
    final idxFareUrl = header.indexOf('agency_fare_url');
    final map = <String, gtfs.Agency>{};
    for (int i = 1; i < lines.length; i++) {
      final row = _parseCsvLine(lines[i]);
      if (row.isEmpty) continue;
      String valueAt(int idx) =>
          (idx >= 0 && idx < row.length) ? row[idx].trim() : '';
      final agencyId = valueAt(idxId);
      if (agencyId.isEmpty) continue;
      map[agencyId] = gtfs.Agency(
        agencyId: agencyId,
        name: valueAt(idxName),
        url: valueAt(idxUrl),
        timezone: valueAt(idxTz),
        lang: valueAt(idxLang).isEmpty ? null : valueAt(idxLang),
        phone: valueAt(idxPhone).isEmpty ? null : valueAt(idxPhone),
        fareUrl: valueAt(idxFareUrl).isEmpty ? null : valueAt(idxFareUrl),
      );
    }
    return map;
  }

  // Basic CSV line parser supporting quoted fields and commas within quotes
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }

  String? _cleanHex(String? hex) {
    if (hex == null) return null;
    var s = hex.trim().replaceAll('\r', '').replaceAll('#', '');
    if (s.isEmpty) return null;
    return s.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transport Lines')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final filteredRoutes = _getFilteredRoutes();
    final grouped = _groupRoutes(filteredRoutes);
    final activeCategories = ['All'] + _getAvailableCategories();
    final groupedWidgets = _buildGroupedRouteWidgets(theme, grouped);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Transport Lines'),
            floating: true,
            pinned: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(144),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: TextField(
                      controller: _searchController,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.text,
                      autofillHints: const [],
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search lines, agencies, or codes...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: activeCategories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            showCheckmark: false,
                            avatar: Icon(
                              cat == 'All' ? Icons.apps : _iconForCategory(cat),
                              size: 18,
                              color: isSelected
                                  ? theme.colorScheme.onSecondaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = cat;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (filteredRoutes.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_bus_outlined,
                      size: 64,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No transport lines found.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(
                bottom: 24,
                left: 16,
                right: 16,
                top: 8,
              ),
              sliver: SliverList.builder(
                itemCount: groupedWidgets.length,
                itemBuilder: (context, index) => groupedWidgets[index],
              ),
            ),
        ],
      ),
    );
  }

  static const List<String> _typeOrder = [
    'Metro',
    'Train',
    'Bus',
    'Ferry',
    'Other',
  ];

  List<gtfs.Route> _getFilteredRoutes() {
    return routes.where((route) {
      final typeMatches =
          _selectedCategory == 'All' ||
          _transportCategory(route) == _selectedCategory;
      if (!typeMatches) return false;

      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();

      final routeLongName = route.longName.toLowerCase();
      final routeShortName = route.shortName.toLowerCase();
      final agency = _agencyName(route.agencyId).toLowerCase();
      final hasPrefix = route.linePrefixes.any(
        (p) => p.toLowerCase().contains(q),
      );

      return routeLongName.contains(q) ||
          routeShortName.contains(q) ||
          agency.contains(q) ||
          hasPrefix;
    }).toList();
  }

  List<String> _getAvailableCategories() {
    final types = routes.map((r) => _transportCategory(r)).toSet().toList();
    types.sort((a, b) {
      final idxA = _typeOrder.indexOf(a);
      final idxB = _typeOrder.indexOf(b);
      return (idxA >= 0 ? idxA : 99).compareTo(idxB >= 0 ? idxB : 99);
    });
    return types;
  }

  List<Widget> _buildGroupedRouteWidgets(
    ThemeData theme,
    Map<String, Map<String, List<gtfs.Route>>> grouped,
  ) {
    final typeKeys = grouped.keys.toList()
      ..sort((a, b) {
        int indexFor(String key) {
          final idx = _typeOrder.indexOf(key);
          return idx >= 0 ? idx : _typeOrder.length;
        }

        final diff = indexFor(a) - indexFor(b);
        if (diff != 0) return diff;
        return a.compareTo(b);
      });
    final widgets = <Widget>[];
    for (final type in typeKeys) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 12),
          child: Row(
            children: [
              Icon(_iconForCategory(type), color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                type,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );

      final agenciesMap = grouped[type]!;
      final agencyIds = agenciesMap.keys.toList()
        ..sort((a, b) => _agencyName(a).compareTo(_agencyName(b)));

      for (var i = 0; i < agencyIds.length; i++) {
        final agencyId = agencyIds[i];
        final agencyName = _agencyName(agencyId);

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              agencyName,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );

        final agencyRoutes = agenciesMap[agencyId]!;
        for (final route in agencyRoutes) {
          widgets.add(_buildRouteCard(theme, route));
        }
      }
    }
    return widgets;
  }

  Widget _buildRouteCard(ThemeData theme, gtfs.Route route) {
    final routeColor = _colorFromHexOr(
      route.color,
      theme.colorScheme.primaryContainer,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          final agency = agencies[route.agencyId];
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TransportLinesDetailsPage(route: route, agency: agency),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : routeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: routeColor, width: 2),
                ),
                child: Center(
                  child: route.routeIcon != null && route.routeIcon!.isNotEmpty
                      ? SizedBox(
                          width: 28,
                          height: 28,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SvgPicture.asset(route.routeIcon!),
                          ),
                        )
                      : Icon(
                          _iconForCategory(_transportCategory(route)),
                          size: 28,
                          color: theme.brightness == Brightness.dark
                              ? routeColor
                              : routeColor,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final isBusNotBRT =
                            _transportCategory(route) == 'Bus' &&
                            route.routeId != 'BRT';
                        final heading = isBusNotBRT
                            ? route.shortName
                            : route.longName;
                        final String? terminalText =
                            routeTerminals[route.routeId];
                        String? subHeading;
                        if (isBusNotBRT) {
                          subHeading = terminalText?.isNotEmpty == true
                              ? terminalText
                              : route.longName;
                        } else {
                          subHeading = terminalText?.isNotEmpty == true
                              ? terminalText
                              : (route.shortName != route.longName
                                    ? route.shortName
                                    : null);
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              heading.isNotEmpty ? heading : route.routeId,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (subHeading != null &&
                                subHeading.isNotEmpty &&
                                subHeading != heading) ...[
                              const SizedBox(height: 4),
                              Text(
                                subHeading,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(String type) {
    switch (type) {
      case 'Metro':
        return Icons.subway;
      case 'Train':
        return Icons.train;
      case 'Bus':
        return Icons.directions_bus;
      case 'Ferry':
        return Icons.directions_boat;
      default:
        return Icons.directions_transit;
    }
  }

  Map<String, Map<String, List<gtfs.Route>>> _groupRoutes(
    List<gtfs.Route> routeList,
  ) {
    final map = <String, Map<String, List<gtfs.Route>>>{};
    for (final route in routeList) {
      final typeKey = _transportCategory(route);
      final agencyKey = route.agencyId.isEmpty ? 'unknown' : route.agencyId;
      map.putIfAbsent(typeKey, () => <String, List<gtfs.Route>>{});
      final agencyMap = map[typeKey]!;
      agencyMap.putIfAbsent(agencyKey, () => <gtfs.Route>[]);
      agencyMap[agencyKey]!.add(route);
    }

    for (final agenciesMap in map.values) {
      for (final rList in agenciesMap.values) {
        rList.sort((a, b) => a.longName.compareTo(b.longName));
      }
    }
    return map;
  }

  String _transportCategory(gtfs.Route route) {
    final raw = route.type.trim().toLowerCase();
    bool matches(Iterable<String> values) =>
        values.any((value) => value == raw);

    if (matches(['0', '1', 'metro', 'subway', 'rapid transit'])) {
      return 'Metro';
    }
    if (matches(['2', 'rail', 'train', 'commuter'])) {
      return 'Train';
    }
    if (matches(['3', 'bus'])) {
      return 'Bus';
    }
    if (matches(['4', 'ferry', 'boat'])) {
      return 'Ferry';
    }
    return 'Other';
  }

  String _agencyName(String agencyId) {
    return agencies[agencyId]?.name.isNotEmpty == true
        ? agencies[agencyId]!.name
        : 'Agency $agencyId';
  }

  Color _colorFromHexOr(String? hex, Color fallback) {
    final cleaned = _cleanHex(hex);
    if (cleaned == null) return fallback;
    try {
      return Color(int.parse('0xFF$cleaned'));
    } catch (_) {
      return fallback;
    }
  }
}
