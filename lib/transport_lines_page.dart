import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:route/services/gtfs_models.dart' as gtfs;
import 'package:route/transport_lines_details_page.dart';

class TransportLinesPage extends StatefulWidget {
  const TransportLinesPage({super.key});

  @override
  State<TransportLinesPage> createState() => _TransportLinesPageState();
}

class _TransportLinesPageState extends State<TransportLinesPage> {
  List<gtfs.Route> routes = [];
  Map<String, gtfs.Agency> agencies = {};
  bool _loading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final routesFuture = rootBundle.loadString('assets/gtfs_data/routes.txt');
      final agencyFuture = rootBundle.loadString('assets/gtfs_data/agency.txt');
      final content = await routesFuture;
      final agencyContent = await agencyFuture;
      final lines = const LineSplitter().convert(content);
      final loadedRoutes = <gtfs.Route>[];
      if (lines.length > 1) {
        for (var i = 1; i < lines.length; i++) {
          final line = lines[i].trimRight();
          if (line.isEmpty) continue;
          final row = _parseCsvLine(line);
          if (row.length < 7) continue;
          final linePrefixes = row.length > 7
              ? row
                    .sublist(7)
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList()
              : <String>[];
          loadedRoutes.add(
            gtfs.Route(
              routeId: row[0].trim(),
              agencyId: row[1].trim(),
              shortName: row[2].trim(),
              longName: row[3].trim(),
              type: row[4].trim(),
              color: row.length > 5 ? _cleanHex(row[5]) : null,
              textColor: row.length > 6 ? _cleanHex(row[6]) : null,
              linePrefixes: linePrefixes,
            ),
          );
        }
      }
      final loadedAgencies = _parseAgencies(agencyContent);
      setState(() {
        routes = loadedRoutes;
        agencies = loadedAgencies;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading routes.txt: $e');
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
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search lines, agencies, or codes...',
                        prefixIcon: const Icon(Icons.search),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: activeCategories.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: _selectedCategory == cat,
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
                    Icon(Icons.directions_bus_outlined, size: 64, color: theme.colorScheme.outline),
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
              padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16, top: 8),
              sliver: SliverList.list(
                children: _buildGroupedRouteWidgets(theme, grouped),
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
      final typeMatches = _selectedCategory == 'All' || _transportCategory(route) == _selectedCategory;
      if (!typeMatches) return false;

      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();

      final routeLongName = route.longName.toLowerCase();
      final routeShortName = route.shortName.toLowerCase();
      final agency = _agencyName(route.agencyId).toLowerCase();
      final hasPrefix = route.linePrefixes.any((p) => p.toLowerCase().contains(q));

      return routeLongName.contains(q) || routeShortName.contains(q) || agency.contains(q) || hasPrefix;
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
      ThemeData theme, Map<String, Map<String, List<gtfs.Route>>> grouped) {
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
    final routeColor = _colorFromHexOr(route.color, theme.colorScheme.primaryContainer);
    final routeTextColor = _colorFromHexOr(route.textColor, theme.colorScheme.onPrimaryContainer);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final agency = agencies[route.agencyId];
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransportLinesDetailsPage(
                route: route,
                agency: agency,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: routeColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: routeColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    route.shortName.isNotEmpty ? route.shortName : "—",
                    style: TextStyle(
                      color: routeTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: route.shortName.length > 3 ? 14 : 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.longName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (route.linePrefixes.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: route.linePrefixes
                            .where((p) => p.isNotEmpty)
                            .map((p) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    p,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ))
                            .toList(),
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

  Map<String, Map<String, List<gtfs.Route>>> _groupRoutes(List<gtfs.Route> routeList) {
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
