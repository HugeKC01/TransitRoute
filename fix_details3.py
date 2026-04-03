import re
import sys

def modify():
    with open('lib/widgets/route_details_sheet.dart', 'r') as f:
        orig = f.read()

    # 1. Remove the entire `Future<void> showRouteDetailsSheet(` block.
    # We will search for Future<void> showRouteDetailsSheet and replace it until class RouteDetailsSheet
    content = re.sub(r'Future<void>\s+showRouteDetailsSheet.*?class RouteDetailsSheet', 'class RouteDetailsSheet', orig, flags=re.DOTALL)

    # 2. Add an `onBack` callback to `RouteDetailsSheet` and remove `scrollController`.
    content = content.replace('required this.scrollController,', 'required this.onBack,')
    content = content.replace('final ScrollController scrollController;', 'final VoidCallback onBack;')

    # 3. Change `return ListView(` to `return Padding(` / `Column`
    # Replace the exact block
    list_view_str = '''return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      children: ['''
      
    if list_view_str not in content:
        # let's try another whitespace pattern
        list_view_str2 = '''return ListView(
      controller: scrollController,'''
        content = content.replace(list_view_str2, '''return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [''')
        
        # also we need to remove the internal padding
        content = re.sub(r'padding: EdgeInsets\.fromLTRB\([^)]+\),', '', content, count=1, flags=re.DOTALL)
    else:
        content = content.replace(list_view_str, '''return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [''')

    # 4. Insert the back button into the first Row
    row_children = '''children: [
            Expanded(
              child: Text('''
              
    content = content.replace(row_children, '''children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
              tooltip: 'Back to options',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(''')

    # Since it's no longer a List View but a Column, the list view array closes with `]`. But Column also closes with `]`. 
    # But Column is inside Padding, we have to close the padding at the end of the method!
    # Wait, the end of the method is `  }\n}`.
    # Let's just find the last `    );\n  }\n}` and change to `    ),\n      ),\n    );\n  }\n}`? 
    # Let's just do a string replace from the tail.
    # The end of `Widget build` is:
    # `    );\n  }\n}`. But `return Padding(child: Column(...));` requires one more closing brace.
    if content != orig:
        content = re.sub(r'(\]?,?\s*)\);\s*\}\s*\}', r'\1\n      ),\n    );\n  }\n}', content)

    with open('lib/widgets/route_details_sheet.dart', 'w') as f:
        f.write(content)

modify()
