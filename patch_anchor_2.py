import re

with open('lib/main.dart', 'r') as f:
    text = f.read()

# Pattern for collapsed search bar
old_1 = """            dividerColor: Colors.transparent,
            searchController: _collapsedSearchController,"""

new_1 = """            dividerColor: Colors.transparent,
            isFullScreen: MediaQuery.of(context).size.width <= 600,
            searchController: _collapsedSearchController,"""

text = text.replace(old_1, new_1)

# Pattern for stop search bar
old_2 = """      dividerColor: Colors.transparent,
      searchController: controller,"""

new_2 = """      dividerColor: Colors.transparent,
      isFullScreen: MediaQuery.of(context).size.width <= 600,
      searchController: controller,"""

text = text.replace(old_2, new_2)

with open('lib/main.dart', 'w') as f:
    f.write(text)

