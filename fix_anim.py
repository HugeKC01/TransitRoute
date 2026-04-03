import re

with open('lib/main.dart', 'r') as f:
    content = f.read()

old_func = '''  Widget _buildRouteOptionsSection(BuildContext context) {
    if (directionOptions.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_viewingDetailsOption != null) {
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
    );
  }'''

new_func = '''  Widget _buildRouteOptionsSection(BuildContext context) {
    if (directionOptions.isEmpty) {
      return const SizedBox.shrink();
    }
    
    Widget content;
    if (_viewingDetailsOption != null) {
      content = RouteDetailsSheet(
        key: const ValueKey('route_details'),
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
    } else {
      content = RouteOptionsPanel(
        key: const ValueKey('route_options'),
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
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) {
        final isDetails = child.key == const ValueKey('route_details');
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: isDetails ? const Offset(0.05, 0.0) : const Offset(-0.05, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: content,
    );
  }'''

if old_func in content:
    content = content.replace(old_func, new_func)
    with open('lib/main.dart', 'w') as f:
        f.write(content)
    print("Replaced successfully")
else:
    print("Could not find old_func")

