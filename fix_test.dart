import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'lib/services/gtfs_models.dart' as gtfs;

void main() async {
  final routes = <gtfs.Route>[];
  final f = File('assets/gtfs_data/routes.txt').readAsStringSync();
  final lines = const LineSplitter().convert(f);
  print('Headers: \${lines[0]}');
  for (int i=1; i<lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    final r = lines[i].split(',');
    if (r.length > 4) {
      if (r[0] == 'SNNE') {
        print('SNNE route type is: "\${r[4]}"');
      }
    }
  }
}
