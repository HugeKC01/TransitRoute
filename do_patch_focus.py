import re

def patch(fp):
    with open(fp, "r") as f:
        c = f.read()

    old_decl = """  late final SearchController _startSearchController;
  static bool _hasShownWelcome = false;
  late final SearchController _destSearchController;
  late final SearchController _collapsedSearchController;
  late final FocusNode _collapsedSearchFocus;"""
    new_decl = """  late final SearchController _startSearchController;
  late final FocusNode _startSearchFocus;
  static bool _hasShownWelcome = false;
  late final SearchController _destSearchController;
  late final FocusNode _destSearchFocus;
  late final SearchController _collapsedSearchController;
  late final FocusNode _collapsedSearchFocus;"""
    c = c.replace(old_decl, new_decl)

    old_init = """    _startSearchController = SearchController();
    _destSearchController = SearchController();
    _collapsedSearchController = SearchController();
    _collapsedSearchController.addListener(() => setState(() {}));
    _collapsedSearchFocus = FocusNode();
    _collapsedSearchFocus.addListener(() => setState(() {}));"""
    new_init = """    _startSearchController = SearchController();
    _startSearchController.addListener(() => setState(() {}));
    _startSearchFocus = FocusNode();
    _startSearchFocus.addListener(() => setState(() {}));
    _destSearchController = SearchController();
    _destSearchController.addListener(() => setState(() {}));
    _destSearchFocus = FocusNode();
    _destSearchFocus.addListener(() => setState(() {}));
    _collapsedSearchController = SearchController();
    _collapsedSearchController.addListener(() => setState(() {}));
    _collapsedSearchFocus = FocusNode();
    _collapsedSearchFocus.addListener(() => setState(() {}));"""
    c = c.replace(old_init, new_init)

    old_disp = """    _startSearchController.dispose();
    _destSearchController.dispose();
    _collapsedSearchController.dispose();
    _collapsedSearchFocus.dispose();"""
    new_disp = """    _startSearchController.dispose();
    _startSearchFocus.dispose();
    _destSearchController.dispose();
    _destSearchFocus.dispose();
    _collapsedSearchController.dispose();
    _collapsedSearchFocus.dispose();"""
    c = c.replace(old_disp, new_disp)

    old_blur = """              _startSearchController,
              _destSearchController,
              _collapsedSearchFocus,
            ]),"""
    new_blur = """              _startSearchController,
              _destSearchController,
              _collapsedSearchFocus,
              _startSearchFocus,
              _destSearchFocus,
            ]),"""
    c = c.replace(old_blur, new_blur)

    old_blur_log = """              if ((!isWide && _collapsedSearchController.isAttached && _collapsedSearchController.isOpen) ||
                  (_startSearchController.isAttached && _startSearchController.isOpen) ||
                  (_destSearchController.isAttached && _destSearchController.isOpen) ||
                  (isWide && (_collapsedSearchFocus.hasFocus || _collapsedSearchController.text.isNotEmpty))) {"""
    new_blur_log = """              if ((!isWide && _collapsedSearchController.isAttached && _collapsedSearchController.isOpen) ||
                  (!isWide && _startSearchController.isAttached && _startSearchController.isOpen) ||
                  (!isWide && _destSearchController.isAttached && _destSearchController.isOpen) ||
                  (isWide && (_collapsedSearchFocus.hasFocus || _collapsedSearchController.text.isNotEmpty || _startSearchFocus.hasFocus || _startSearchController.text.isNotEmpty || _destSearchFocus.hasFocus || _destSearchController.text.isNotEmpty))) {"""
    c = c.replace(old_blur_log, new_blur_log)

    with open(fp, "w") as f:
        f.write(c)

if __name__ == "__main__":
    patch("lib/main.dart")