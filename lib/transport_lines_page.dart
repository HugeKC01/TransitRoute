import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:route/services/gtfs_models.dart' as gtfs;

class TransportLinesPage extends StatefulWidget {
  const TransportLinesPage({super.key});

  @override
  State<TransportLinesPage> createState() => _TransportLinesPageState();
}

class _TransportLinesPageState extends State<TransportLinesPage> {
  List<gtfs.Route> routes = [];
  Map<String, gtfs.Agency> agencies = {};
  bool _loading = true;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Transport Lines')),
      body: routes.isEmpty
          ? Center(
              child: Text(
                'No transport lines found.',
                style: theme.textTheme.bodyLarge,
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: _buildGroupedRouteList(theme),
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

  List<Widget> _buildGroupedRouteList(ThemeData theme) {
    final grouped = _groupRoutes();
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
      final typeLabel = type;
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            typeLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

      final agenciesMap = grouped[type]!;
      final agencyIds = agenciesMap.keys.toList()
        ..sort((a, b) => _agencyName(a).compareTo(_agencyName(b)));
      for (var i = 0; i < agencyIds.length; i++) {
        if (i > 0) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: theme.colorScheme.outlineVariant),
            ),
          );
        }
        final agencyId = agencyIds[i];
        final agencyName = _agencyName(agencyId);
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              agencyName,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );

        final agencyRoutes = agenciesMap[agencyId]!;
        for (final route in agencyRoutes) {
          widgets.add(
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _colorFromHexOr(route.color, Colors.blue),
                child: Text(
                  route.shortName,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(route.longName),
              subtitle: Text(_routeSubtitle(route)),
            ),
          );
        }
      }
    }
    return widgets;
  }

  Map<String, Map<String, List<gtfs.Route>>> _groupRoutes() {
    final map = <String, Map<String, List<gtfs.Route>>>{};
    for (final route in routes) {
      final typeKey = _transportCategory(route);
      final agencyKey = route.agencyId.isEmpty ? 'unknown' : route.agencyId;
      map.putIfAbsent(typeKey, () => <String, List<gtfs.Route>>{});
      final agencyMap = map[typeKey]!;
      agencyMap.putIfAbsent(agencyKey, () => <gtfs.Route>[]);
      agencyMap[agencyKey]!.add(route);
    }

    for (final agenciesMap in map.values) {
      for (final routeList in agenciesMap.values) {
        routeList.sort((a, b) => a.longName.compareTo(b.longName));
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

  String _routeSubtitle(gtfs.Route route) {
    final prefixes = route.linePrefixes
        .where((prefix) => prefix.isNotEmpty)
        .toList();
    final parts = <String>[
      if (route.shortName.isNotEmpty) 'Line ${route.shortName}',
      if (prefixes.isNotEmpty) 'Codes: ${prefixes.join(', ')}',
      _agencyName(route.agencyId),
    ];
    return parts.where((part) => part.isNotEmpty).join(' • ');
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
