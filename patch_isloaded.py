with open('lib/main.dart', 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "shapeSegments = shapes;" in line and "});" in lines[i+1]:
        lines.insert(i+1, "          _isDataLoaded = true;\n")
        break

with open('lib/main.dart', 'w') as f:
    f.writelines(lines)
