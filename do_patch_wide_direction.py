import re

def patch(fp):
    with open(fp, "r") as f:
        c = f.read()

    old_wide = """    final isWideSearching = _headerCollapsed.value && (_collapsedSearchFocus.hasFocus || _collapsedSearchController.text.isNotEmpty);
    // If we have search results from the side panel, we want to show it. Wait, if viewingStop != null, the route planner obscures it. We switch between them.
    final hasPanelContent = directionOptions.isNotEmpty || _viewingStop != null || isWideSearching;"""

    new_wide = """    final isWideSearching = _headerCollapsed.value && (_collapsedSearchFocus.hasFocus || _collapsedSearchController.text.isNotEmpty);
    final isWideStartSearching = !_headerCollapsed.value && (_startSearchFocus.hasFocus || _startSearchController.text.isNotEmpty);
    final isWideDestSearching = !_headerCollapsed.value && (_destSearchFocus.hasFocus || _destSearchController.text.isNotEmpty);
    final isAnyWideSearching = isWideSearching || isWideStartSearching || isWideDestSearching;
    
    // If we have search results from the side panel, we want to show it. Wait, if viewingStop != null, the route planner obscures it. We switch between them.
    final hasPanelContent = directionOptions.isNotEmpty || _viewingStop != null || isAnyWideSearching;"""
    c = c.replace(old_wide, new_wide)

    old_switcher = """                      ? Padding(
                          key: ValueKey('panel_content_${isWideSearching ? "search" : "route"}'),"""
    
    new_switcher = """                      ? Padding(
                          key: ValueKey('panel_content_${isAnyWideSearching ? "search" : "route"}'),"""
    c = c.replace(old_switcher, new_switcher)

    old_switcher_content = """                                  child: isWideSearching
                                      ? _buildWideSearchResults(context)
                                      : (_viewingStop != null
                                          ? _buildStopViewer(context)
                                          : _buildDirectionOptionsList(context)),"""

    new_switcher_content = """                                  child: isWideSearching
                                      ? _buildWideSearchResults(context)
                                      : (_viewingStop != null
                                          ? _buildStopViewer(context)
                                          : _buildDirectionOptionsList(context)),"""
    # Wait, we need to modify _buildDirectionOptionsList instead to swap out the bottom part when start/dest is focused.
    # Alternatively, we could replace the whole panel with the search, but then the search bars would disappear if they are in the header!
    # Wait, start and dest search fields are in _buildSelectionSummaryCard, which is part of _buildHomeHeader!
    # Yes! The inputs are in the header overlay! So they are NOT in the floating panel! 
    # Therefore, replacing the panel contents with search results works perfectly!
    
    new_switcher_content_real = """                                  child: isAnyWideSearching
                                      ? (isWideSearching ? _buildWideSearchResults(context) : _buildWideDirectionSearchResults(context))
                                      : (_viewingStop != null
                                          ? _buildStopViewer(context)
                                          : _buildDirectionOptionsList(context)),"""
    c = c.replace(old_switcher_content, new_switcher_content_real)

    # Let's add the _buildWideDirectionSearchResults method right before `_buildWideSearchResults`
    old_method = """  Widget _buildWideSearchResults(BuildContext context) {"""
    new_method = """  Widget _buildWideDirectionSearchResults(BuildContext context) {
    final isStart = _startSearchFocus.hasFocus || _startSearchController.text.isNotEmpty;
    final ctrl = isStart ? _startSearchController : _destSearchController;
    final text = ctrl.text;

    closeAndSelect(stop) {
      if (isStart) _startSearchFocus.unfocus();
      if (!isStart) _destSearchFocus.unfocus();
      _selectStopFromSearch(stop, asStart: isStart);
    }

    if (text.isEmpty) {
      return ServiceTabs(
        allStops: allStops,
        busStops: busStops,
        linePrefixes: linePrefixes,
        lineColors: lineColors,
        getLineName: _getLineName,
        getLineNames: _getLineNames,
        getServicePriority: _getServicePriority,
        onSelect: closeAndSelect,
      );
    }

    final results = _filterStops(text);
    if (results.isEmpty) {
      return ListView(
        shrinkWrap: true,
        children: const [
          ListTile(
            leading: Icon(Icons.search_off),
            title: Text('No stations found'),
          ),
        ],
      );
    }
    return ListView(
      shrinkWrap: true,
      children: results.map((stop) => _buildSearchSuggestionTile(stop, () => closeAndSelect(stop))).toList(),
    );
  }

  Widget _buildWideSearchResults(BuildContext context) {"""

    c = c.replace(old_method, new_method)

    old_stop_search = """  Widget _buildStopSearchField(
    BuildContext context, {
    required String label,
    required IconData icon,
    Color? iconColor,
    required bool asStart,
    Widget? trailingAction,
  }) {
    final theme = Theme.of(context);
    final controller = asStart ? _startSearchController : _destSearchController;

    final isWide = MediaQuery.of(context).size.width > 600;
    return SearchAnchor(
      viewConstraints: isWide
          ? const BoxConstraints(maxHeight: 500)
          : null,
      viewShape: isWide
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            )
          : null,
      viewBackgroundColor: isWide
          ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.9)
          : null,
      viewElevation: isWide ? 8 : null,
      dividerColor: Colors.transparent,
      isFullScreen: !isWide,
      searchController: controller,
      viewHintText: 'Search $label',
      builder: (context, ctrl) {
        final trailingWidgets = <Widget>[];
        if (ctrl.text.isNotEmpty) {
          trailingWidgets.add(
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Clear $label',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() {
                  ctrl.clear();
                  if (asStart) {
                    selectedStartStopId = null;
                    _customStartPoint = null;
                  } else {
                    selectedDestinationStopId = null;
                    _customDestPoint = null;
                  }
                  _recalculateMapLayers();
                });
              },
            ),
          );
        }
        if (trailingAction != null) {
          trailingWidgets.add(trailingAction);
        }

        return SearchBar(
          controller: ctrl,
          constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
          leading: Icon(icon, color: iconColor),
          hintText: 'Search $label',
          hintStyle: WidgetStatePropertyAll(
            TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          elevation: const WidgetStatePropertyAll<double>(0),
          backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
          ),
          onTap: ctrl.openView,
          onChanged: (value) {
            if (ctrl.isAttached && !ctrl.isOpen) {
              ctrl.openView();
            }
            setState(() {});
          },
          trailing: trailingWidgets,
        );
      },
      suggestionsBuilder: (context, ctrl) {
        if (ctrl.text.isEmpty) {
          return [
            ServiceTabs(
              allStops: allStops,
              busStops: busStops,
              linePrefixes: linePrefixes,
              lineColors: lineColors,
              getLineName: _getLineName,
              getLineNames: _getLineNames,
              getServicePriority: _getServicePriority,
              onSelect: (stop) {
                ctrl.closeView(stop.name);
                _selectStopFromSearch(stop, asStart: asStart);
              },
            ),
          ];
        }

        final results = _filterStops(ctrl.text);
        if (results.isEmpty) {
          return [
            const ListTile(
              leading: Icon(Icons.search_off),
              title: Text('No stations found'),
            ),
          ];
        }
        return results.map(
          (stop) => _buildSearchSuggestionTile(stop, () {
            ctrl.closeView(stop.name);
            _selectStopFromSearch(stop, asStart: asStart);
          }),
        );
      },
    );
  }"""

    new_stop_search = """  Widget _buildStopSearchField(
    BuildContext context, {
    required String label,
    required IconData icon,
    Color? iconColor,
    required bool asStart,
    Widget? trailingAction,
  }) {
    final theme = Theme.of(context);
    final controller = asStart ? _startSearchController : _destSearchController;
    final focus = asStart ? _startSearchFocus : _destSearchFocus;

    final isWide = MediaQuery.of(context).size.width > 600;
    
    final searchBar = SearchBar(
      controller: controller,
      focusNode: isWide ? focus : null,
      constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
      leading: Icon(icon, color: iconColor),
      hintText: 'Search $label',
      hintStyle: WidgetStatePropertyAll(
        TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      elevation: const WidgetStatePropertyAll<double>(0),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      onTap: () {
        if (!isWide && !controller.isOpen) {
          controller.openView();
        }
        if (isWide) {
          focus.requestFocus();
          if (_expandedRouteDetails != null) {
            setState(() => _expandedRouteDetails = null);
          }
        }
      },
      onChanged: (value) {
        if (!isWide && !controller.isOpen) {
          controller.openView();
        }
        setState(() {});
      },
      trailing: [
        if (controller.text.isNotEmpty)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Clear $label',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              setState(() {
                controller.clear();
                if (asStart) {
                  selectedStartStopId = null;
                  _customStartPoint = null;
                } else {
                  selectedDestinationStopId = null;
                  _customDestPoint = null;
                }
                _recalculateMapLayers();
              });
            },
          ),
        if (trailingAction != null) trailingAction,
      ],
    );

    return isWide 
        ? searchBar 
        : SearchAnchor(
      dividerColor: Colors.transparent,
      isFullScreen: true,
      searchController: controller,
      viewHintText: 'Search $label',
      builder: (context, ctrl) => searchBar,
      suggestionsBuilder: (context, ctrl) {
        if (ctrl.text.isEmpty) {
          return [
            ServiceTabs(
              allStops: allStops,
              busStops: busStops,
              linePrefixes: linePrefixes,
              lineColors: lineColors,
              getLineName: _getLineName,
              getLineNames: _getLineNames,
              getServicePriority: _getServicePriority,
              onSelect: (stop) {
                ctrl.closeView(stop.name);
                _selectStopFromSearch(stop, asStart: asStart);
              },
            ),
          ];
        }

        final results = _filterStops(ctrl.text);
        if (results.isEmpty) {
          return [
            const ListTile(
              leading: Icon(Icons.search_off),
              title: Text('No stations found'),
            ),
          ];
        }
        return results.map(
          (stop) => _buildSearchSuggestionTile(stop, () {
            ctrl.closeView(stop.name);
            _selectStopFromSearch(stop, asStart: asStart);
          }),
        );
      },
    );
  }"""
    c = c.replace(old_stop_search, new_stop_search)

    with open(fp, "w") as f:
        f.write(c)

if __name__ == "__main__":
    patch("lib/main.dart")