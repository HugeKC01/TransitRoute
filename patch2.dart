import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync();
  
  final oldChild = '''                                    child: Material(
                                      color: Colors.transparent,
                                      child: _buildRouteOptionsSection(context),
                                    ),''';

  final newChild = '''                                    child: Material(
                                      color: Colors.transparent,
                                      child: hasRoutes ? _buildRouteOptionsSection(context) : _buildStopDetailsContent(context, false),
                                    ),''';
  content = content.replaceAll(oldChild, newChild);
  file.writeAsStringSync(content);
}
