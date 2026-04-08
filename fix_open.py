import re

def patch(fp):
    with open(fp, "r") as f:
        c = f.read()

    # replace !isWide && _collapsedSearchController.isOpen
    c = c.replace('!isWide && _collapsedSearchController.isOpen', '!isWide && _collapsedSearchController.isAttached && _collapsedSearchController.isOpen')
    c = c.replace('!isWide && !_collapsedSearchController.isOpen', '!isWide && _collapsedSearchController.isAttached && !_collapsedSearchController.isOpen')
    c = c.replace('_startSearchController.isOpen', '(_startSearchController.isAttached && _startSearchController.isOpen)')
    c = c.replace('_destSearchController.isOpen', '(_destSearchController.isAttached && _destSearchController.isOpen)')
    
    # replace ctrl.isOpen in _buildSearchAnchor
    c = c.replace('if (!ctrl.isOpen)', 'if (ctrl.isAttached && !ctrl.isOpen)')
    
    with open(fp, "w") as f:
        f.write(c)

patch("lib/main.dart")
