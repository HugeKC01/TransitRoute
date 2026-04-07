import sys

with open('lib/main.dart', 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "Widget build(BuildContext context) {" in line and "final theme = Theme.of(context);" in lines[i+1]:
        lines.insert(i+1, """    if (!_isDataLoaded) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Parsing Transit Data...'),
            ],
          ),
        ),
      );
    }
""")
        break

with open('lib/main.dart', 'w') as f:
    f.writelines(lines)
