import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('assets/gtfs_data/ferry_stop.txt');
  if (!file.existsSync()) {
    print('ferry_stop.txt not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  final stopNamesToQuery = [];

  for (var line in lines) {
    if (line.startsWith('F_CR_') || line.startsWith('F_KSS_') || line.startsWith('F_KPK_')) {
      final parts = line.split(',');
      if (parts.length > 2) {
        stopNamesToQuery.add({'id': parts[0], 'name': parts[1]});
      }
    }
  }

  print('Found ${stopNamesToQuery.length} stops to update.');
  
  Map<String, Map<String, double>> newCoords = {};
  
  var client = HttpClient();

  // To avoid hitting Nominatim rate limits (1 per sec) too hard, process slower
  for (var i = 0; i < stopNamesToQuery.length; i++) {
    final stop = stopNamesToQuery[i];
    final String originalName = stop['name'].toString();
    final name = originalName.replaceAll(' (Thonburi)', '').replaceAll(' Pier', '').replaceAll(' Market', '');
    
    // query Nominatim
    final q = Uri.encodeComponent(name + " pier Bangkok");
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$q&format=json&limit=1');
    
    try {
      final req = await client.getUrl(url);
      req.headers.set('User-Agent', 'Dart/2.x Transit GTFS builder script');
      final response = await req.close();
      
      final resBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(resBody) as List;
      
      if (data.isNotEmpty) {
        newCoords[stop['id']!] = {
          'lat': double.parse(data[0]['lat'].toString()),
          'lon': double.parse(data[0]['lon'].toString()),
        };
        print('[${i+1}/${stopNamesToQuery.length}] Found $name: ${data[0]['lat']}, ${data[0]['lon']}');
      } else {
        // try without pier
        final q2 = Uri.encodeComponent(name + " Bangkok");
        final url2 = Uri.parse('https://nominatim.openstreetmap.org/search?q=$q2&format=json&limit=1');
        
        final req2 = await client.getUrl(url2);
        req2.headers.set('User-Agent', 'Dart/2.x Transit GTFS builder script');
        final response2 = await req2.close();
        
        final resBody2 = await response2.transform(utf8.decoder).join();
        final data2 = jsonDecode(resBody2) as List;
        if (data2.isNotEmpty) {
           newCoords[stop['id']!] = {
            'lat': double.parse(data2[0]['lat'].toString()),
            'lon': double.parse(data2[0]['lon'].toString()),
          };
          print('[${i+1}/${stopNamesToQuery.length}] Found $name (no pier keyword): ${data2[0]['lat']}, ${data2[0]['lon']}');
        } else {
           print('[${i+1}/${stopNamesToQuery.length}] NOT FOUND: $name');
        }
      }
    } catch (e) {
      print('Error querying $name: $e');
    }
    
    await Future.delayed(Duration(milliseconds: 1100)); // Be nice to Nominatim
  }
  
  client.close();

  // Update file
  List<String> newLines = [];
  int updated = 0;
  for (var line in lines) {
    var parts = line.split(',');
    if (parts.length > 4 && newCoords.containsKey(parts[0])) {
      parts[3] = newCoords[parts[0]]!['lat'].toString();
      parts[4] = newCoords[parts[0]]!['lon'].toString();
      newLines.add(parts.join(','));
      updated++;
    } else {
      newLines.add(line);
    }
  }
  
  file.writeAsStringSync(newLines.join('\n') + '\n');
  print('Updated $updated stops with new OSM coordinates.');
}
