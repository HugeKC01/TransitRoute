import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'gtfs_models.dart' as gtfs;

class TransportLinesPage extends StatefulWidget {
  const TransportLinesPage({super.key});

  @override
  State<TransportLinesPage> createState() => _TransportLinesPageState();
}

class _TransportLinesPageState extends State<TransportLinesPage> {
  List<gtfs.Route> routes = [];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final content = await rootBundle.loadString('assets/gtfs_data/routes.txt');
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return;
      final loadedRoutes = <gtfs.Route>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = _parseCsvLine(line);
        if (row.length < 7) continue;
        final linePrefixes = row.length > 7
            ? row.sublist(7).map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
            : <String>[];
        loadedRoutes.add(gtfs.Route(
          routeId: row[0].trim(),
          agencyId: row[1].trim(),
          shortName: row[2].trim(),
          longName: row[3].trim(),
          type: row[4].trim(),
          color: row.length > 5 ? _cleanHex(row[5]) : null,
          textColor: row.length > 6 ? _cleanHex(row[6]) : null,
          linePrefixes: linePrefixes,
        ));
      }
      setState(() {
        routes = loadedRoutes;
      });
    } catch (e) {
      debugPrint('Error loading routes.txt: $e');
      setState(() {
        routes = [];
      });
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Lines'),
      ),
      body: ListView.builder(
        itemCount: routes.length,
        itemBuilder: (context, index) {
          final route = routes[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _colorFromHexOr(route.color, Colors.blue),
              child: Text(route.shortName, style: const TextStyle(color: Colors.white)),
            ),
            title: Text(route.longName),
            subtitle: Text(route.type),
          );
        },
      ),
    );
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
