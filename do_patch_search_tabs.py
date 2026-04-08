import sys

def main():
    with open('lib/widgets/search_tabs.dart', 'r') as f:
        content = f.read()

    new_content = content.replace(
        "Widget _buildStopTile(BuildContext context, gtfs.Stop stop, String lineName) {",
        "Widget _buildStopTile(BuildContext context, gtfs.Stop stop, String lineName, int serviceType) {"
    )

    with open('lib/widgets/search_tabs.dart', 'w') as f:
        f.write(new_content)

main()
