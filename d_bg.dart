import 'dart:io';

void main() {
  var d = File('lib/services/direction_service.dart').readAsStringSync();
  var start = d.indexOf('Future<void> _buildGraphs() async {');
  var end = d.indexOf('void _addTransferEdges() {');
  print(d.substring(start, end));
}
