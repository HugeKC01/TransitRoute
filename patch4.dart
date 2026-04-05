import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(RegExp(r'child:\s*hasRoutes\s*\? Padding\('), 'child: (hasRoutes || hasStopDetails) ? Padding(');
  content = content.replaceAll(RegExp(r'child:\s*_buildRouteOptionsSection\(context\),\s*\),'), 'child: hasRoutes ? _buildRouteOptionsSection(context) : _buildStopDetailsContent(context, false), // patched here\n                                  ),');
  
  file.writeAsStringSync(content);
}
