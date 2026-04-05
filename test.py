with open('lib/main.dart', 'r') as f:
    text = f.read()
if "_buildStopDetailsContent(context, false)" in text:
    print("Found _buildStopDetailsContent(context, false)")
