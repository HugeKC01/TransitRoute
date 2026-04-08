import sys
import re

with open('lib/main.dart', 'r') as f:
    text = f.read()

# Replacement 1: Main Search (Where to?)
old_1 = """                viewTrailing: [
                  if (_collapsedSearchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _collapsedSearchController.clear();
                          if (_collapsedSearchController.isOpen) _collapsedSearchController.closeView('');
                          _collapsedSearchFocus.unfocus();
                        });
                      },
                    ),
                ],"""
new_1 = """                viewTrailing: [
                  ListenableBuilder(
                    listenable: _collapsedSearchController,
                    builder: (context, _) {
                      if (_collapsedSearchController.text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _collapsedSearchController.clear();
                            if (_collapsedSearchController.isOpen) _collapsedSearchController.closeView('');
                            _collapsedSearchFocus.unfocus();
                          });
                        },
                      );
                    },
                  ),
                ],"""
text = text.replace(old_1, new_1)

# Replacement 2: Origin / Dest search
old_2 = """              viewTrailing: [
                if (controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        controller.clear();
                        if (controller.isOpen) controller.closeView('');
                        focusNode.unfocus();
                        if (asStart) {
                          selectedStartStopId = null;
                          _customStartPoint = null;
                        } else {
                          selectedDestinationStopId = null;
                          _customDestPoint = null;
                        }
                        directionOptions = [];
                        selectedDirectionIndex = 0;
                        _headerCollapsed.value = false;
                        _recalculateMapLayers();
                      });
                    },
                  ),
              ],"""
new_2 = """              viewTrailing: [
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    if (controller.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          controller.clear();
                          if (controller.isOpen) controller.closeView('');
                          focusNode.unfocus();
                          if (asStart) {
                            selectedStartStopId = null;
                            _customStartPoint = null;
                          } else {
                            selectedDestinationStopId = null;
                            _customDestPoint = null;
                          }
                          directionOptions = [];
                          selectedDirectionIndex = 0;
                          _headerCollapsed.value = false;
                          _recalculateMapLayers();
                        });
                      },
                    );
                  },
                ),
              ],"""
text = text.replace(old_2, new_2)


with open('lib/main.dart', 'w') as f:
    f.write(text)
