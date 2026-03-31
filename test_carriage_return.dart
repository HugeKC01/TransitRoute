import 'dart:io';

void main() async {
  final text = await File('assets/gtfs_data/shapes.txt').readAsString();
  final lines = text.split('\n').map((l) => l.trimRight()).where((l) => l.isNotEmpty).toList();
  for(final l in lines) {
    if(l.contains('PK_MAIN') && l.contains('PK01')) {
      final name = l.split(',')[4];
      print('name: \$name, length: \${name.length}');
    }
  }
}
