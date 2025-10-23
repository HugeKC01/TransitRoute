import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
      debugPrint('Loaded routes.txt content:\n$content');
      final lines = content.split('\n');
      debugPrint('Parsed lines count: ${lines.length}');
      if (lines.length <= 1) return;
      final loadedRoutes = <gtfs.Route>[];
      for (var i = 1; i < lines.length; i++) {
        final row = lines[i].split(',');
        debugPrint('Row $i: $row');
        if (row.length < 5) continue;
        loadedRoutes.add(gtfs.Route(
          routeId: row[0],
          agencyId: row[1],
          shortName: row[2],
          longName: row[3],
          type: row[4],
          color: row.length > 5 ? row[5] : null,
          textColor: row.length > 6 ? row[6] : null,
        ));
      }
      debugPrint('Loaded routes count: ${loadedRoutes.length}');
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
              backgroundColor: route.color != null && route.color!.isNotEmpty
                  ? Color(int.parse('0xFF${route.color}'))
                  : Colors.blue,
              child: Text(route.shortName, style: const TextStyle(color: Colors.white)),
            ),
            title: Text(route.longName),
            subtitle: Text(route.type),
          );
        },
      ),
    );
  }
}
