import re
with open("lib/graphic_map_page.dart", "r") as f:
    c = f.read()

# remove _parseColor
c = re.sub(r'Color _parseColor.*?\}\n', '', c, flags=re.DOTALL)

# fix deprecated Matrix4 methods
c = c.replace("_transformationController.value = Matrix4.identity()\n        ..translate(dx, dy, 0.0)\n        ..scale(1.0, 1.0, 1.0);", 
"_transformationController.value = Matrix4.identity()\n        ..translate(dx, dy, 0.0);")

with open("lib/graphic_map_page.dart", "w") as f:
    f.write(c)
