import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceFirst(
'''      _cachedActiveDirectionPolylines = [];
      if (directionOptions.isNotEmpty && selectedDirectionIndex < directionOptions.length) {
        _cachedActiveDirectionPolylines = _buildRoutePolylines(
          directionOptions[selectedDirectionIndex].segments,
          hitValue: selectedDirectionIndex,
          isActive: true,
        );
      }''',
'''      _cachedActiveDirectionPolylines = [];
      if (directionOptions.isNotEmpty && selectedDirectionIndex < directionOptions.length) {
        _cachedActiveDirectionPolylines = _buildRoutePolylines(
          directionOptions[selectedDirectionIndex].segments,
          hitValue: selectedDirectionIndex,
          isActive: true,
        );
      }
  }'''
  );
  
  file.writeAsStringSync(content);
}
