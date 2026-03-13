import 'dart:io';

void main() async {
  final lines = await File('assets/gtfs_data/shapes.txt').readAsLines();
  final header = lines.first.split(',');
  int c = 0;
  for(int i=1; i<lines.length; i++) {
    final cols = lines[i].split(',');
    if(cols.length > 4 && cols[4].trim().isNotEmpty) {
      c++;
    }
  }
  print('Total shapes points with names: $c');
}
