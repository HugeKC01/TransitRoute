import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync();
  content = content.replaceFirst('SingleChildScrollView(\n                                            child: SingleChildScrollView(\n                                              child: _buildStopDetailsContent(\n                                                context,\n                                                false,\n                                              ),\n                                            ),\n                                          )', 'SingleChildScrollView(\n                                            child: _buildStopDetailsContent(\n                                                context,\n                                                false,\n                                              ),\n                                          )');
  file.writeAsStringSync(content);
}
