import re

with open('lib/widgets/route_details_sheet.dart', 'r') as f:
    content = f.read()

# Remove the showRouteDetailsSheet function
content = re.sub(r'Future<void> showRouteDetailsSheet\(\{.*?\}\) \{.*?return showModalBottomSheet<void>\(.*?\);\s*\}\s*\},?\s*\);\s*\}\s*\},?\s*\);\s*\}', '', content, flags=re.DOTALL)

# Also remove stray braces at the top
content = re.sub(r'\},?\s*\);\s*\}\s*\},?\s*\);\s*\}', '', content, flags=re.DOTALL)

with open('lib/widgets/route_details_sheet.dart', 'w') as f:
    f.write(content)
