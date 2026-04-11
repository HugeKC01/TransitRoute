import 'dart:io';
import 'dart:convert';
void main() async {
  final csv = await File('assets/gtfs_data/ferry_stop.txt').readAsString();
  final lines = const LineSplitter().convert(csv);
  print(lines.take(5).toList());
}
