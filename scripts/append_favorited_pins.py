import os

with open("lib/pages/more_page.dart", "r") as f:
    content = f.read()

# remove the imports from the end if they are there
content = content.replace("import 'package:flutter_map/flutter_map.dart';", "")
content = content.replace("import 'package:latlong2/latlong.dart';", "")

imports = "import 'package:flutter_map/flutter_map.dart';\nimport 'package:latlong2/latlong.dart';\n"
content = imports + content

with open("lib/pages/more_page.dart", "w") as f:
    f.write(content)

