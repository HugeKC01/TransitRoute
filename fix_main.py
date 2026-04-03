import re

with open('lib/main.dart', 'r') as f:
    content = f.read()

# Add _viewingDetailsOption to State
if 'DirectionOption? _viewingDetailsOption;' not in content:
    content = content.replace('List<DirectionOption> directionOptions = [];', 'List<DirectionOption> directionOptions = [];\n  DirectionOption? _viewingDetailsOption;')

# Change the RouteOptionsPanel call
old_call = '''    return RouteOptionsPanel(
      options: directionOptions,
      selectedIndex: selectedDirectionIndex,
      onSelectOption: _selectRouteOption,
      onViewDetails: (option) => showRouteDetailsSheet(
        context: context,
        option: option,
        lineNameResolver: _getLineName,
        lineColorResolver: _getLineColor,
        lineColors: lineColors,
      ),
      onStartNavigation: _openNavigation,
      lineNameResolver: _getLineName,
      lineColors: lineColors,
    );'''
    
new_call = '''    if (_viewingDetailsOption != null) {
      return RouteDetailsSheet(
        option: _viewingDetailsOption!,
        onBack: () {
          setState(() {
            _viewingDetailsOption = null;
          });
        },
        lineNameResolver: _getLineName,
        lineColorResolver: _getLineColor,
        lineColors: lineColors,
      );
    }
    
    return RouteOptionsPanel(
      options: directionOptions,
      selectedIndex: selectedDirectionIndex,
      onSelectOption: _selectRouteOption,
      onViewDetails: (option) {
        setState(() {
          _viewingDetailsOption = option;
        });
      },
      onStartNavigation: _openNavigation,
      lineNameResolver: _getLineName,
      lineColors: lineColors,
    );'''

if old_call in content:
    content = content.replace(old_call, new_call)
else:
    print("WARNING: Could not find old_call")

# Also, when clear options or find direction, reset _viewingDetailsOption
content = content.replace('directionOptions.clear();', 'directionOptions.clear();\n      _viewingDetailsOption = null;')
content = content.replace('directionOptions = routes;', 'directionOptions = routes;\n      _viewingDetailsOption = null;')

with open('lib/main.dart', 'w') as f:
    f.write(content)
