import 'dart:io';
import 'dart:convert';

void main() async {
  final content = File('assets/gtfs_data/routes.txt').readAsStringSync();
  print(content.split('\n')[1]);
}
