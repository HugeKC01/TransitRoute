import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    'child: hasRoutes\n                      ? Padding(',
    'child: (hasRoutes || hasStopDetails)\n                      ? Padding('
  );
  
  content = content.replaceAll(
    'child: _buildRouteOptionsSection(context),\n                                  ),',
    'child: hasRoutes ? _buildRouteOptionsSection(context) : _buildStopDetailsContent(context, false),\n                                  ),'
  );

  file.writeAsStringSync(content);
}
