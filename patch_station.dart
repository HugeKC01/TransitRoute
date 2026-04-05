import 'dart:io';

void main() {
  final file = File('lib/pages/station_details_page.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceFirst(
    '      appBar: AppBar(\n        title: Text(hasThaiName ? stop.thaiName! : stop.name),\n        centerTitle: true,\n      ),',
    '      appBar: AppBar(\n        leading: const BackButton(),\n        title: Text(hasThaiName ? stop.thaiName! : stop.name),\n        centerTitle: true,\n      ),'
  );
  
  file.writeAsStringSync(content);
}
