import re

with open('lib/services/gtfs_shapes.dart', 'r') as f:
    text = f.read()

# Let's see if we can use flutter/foundation.dart to import compute
if "import 'package:flutter/foundation.dart';" not in text:
    text = "import 'package:flutter/foundation.dart';\n" + text

def modify_parseShapes(t):
    pass

