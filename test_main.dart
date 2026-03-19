import 'dart:convert';
import 'dart:io';

void main() async {
  final lines = await File('assets/gtfs_data/stops.txt').readAsLines();
  for (final l in lines) {
    if (l.contains('PK')) print(l);
  }
}
