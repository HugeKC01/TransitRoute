import re

with open('lib/widgets/search_tabs.dart', 'r') as f:
    text = f.read()

old_return = """    return Align(
      alignment: isWideWindow ? Alignment.topLeft : Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isWideWindow ? 400 : double.infinity,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: isWideWindow ? 24.0 : 0,
            top: 8.0,
            bottom: 16.0,
          ),
          child: mainContent,
        ),
      ),
    );"""

new_return = """    return Padding(
      padding: const EdgeInsets.only(
        top: 8.0,
        bottom: 16.0,
      ),
      child: mainContent,
    );"""

text = text.replace(old_return, new_return)

with open('lib/widgets/search_tabs.dart', 'w') as f:
    f.write(text)
