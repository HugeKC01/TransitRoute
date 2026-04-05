import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync();
  
  final oldStr = '''
  Widget _buildWideLayout(BuildContext context, Widget headerOverlay) {
    final width = MediaQuery.of(context).size.width;
    final hasRoutes = directionOptions.isNotEmpty;
    // ensure the side panel is at least 320px wide so route options text does not overflow
''';
  final newStr = '''
  Widget _buildWideLayout(BuildContext context, Widget headerOverlay) {
    final width = MediaQuery.of(context).size.width;
    final hasRoutes = directionOptions.isNotEmpty;
    final hasStopDetails = _viewingStopDetails != null && !hasRoutes;
    // ensure the side panel is at least 320px wide so route options text does not overflow
''';
  
  content = content.replaceAll(oldStr, newStr);

  file.writeAsStringSync(content);
}
