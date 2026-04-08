import re

with open('lib/widgets/search_tabs.dart', 'r') as f:
    c = f.read()

c = c.replace(
"""                    } else if (item.stop != null) {
                      return _buildStopTile(context, item.stop!, item.line);""",
"""                    } else if (item.stop != null) {
                      return _buildStopTile(context, item.stop!, item.line, widget.getServicePriority(item.stop!));"""
)

with open('lib/widgets/search_tabs.dart', 'w') as f:
    f.write(c)
