import 'dart:io';

void main() {
  final file = File('lib/widgets/upcoming_departures.dart');
  var content = file.readAsStringSync();
  content = content.replaceFirst('            ),\n          ],\n        );\n      },\n    );\n  }\n}', '            );\n      },\n    );\n  }\n}');
  file.writeAsStringSync(content);
}
