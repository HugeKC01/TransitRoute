import os
import re

files_to_check = [
    'lib/main.dart',
    'lib/services/direction_service.dart',
    'lib/services/gtfs_shapes.dart',
    'lib/services/route_asset_loader.dart',
    'lib/services/timetable_service.dart'
]

for filepath in files_to_check:
    if os.path.exists(filepath):
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Replace the function call
        content = content.replace("rootBundle.loadString(", "gtfsSyncService.getGtfsFile(")
        
        # Replace the import if it's there
        if "import 'package:flutter/services.dart' show rootBundle;" in content:
            content = content.replace(
                "import 'package:flutter/services.dart' show rootBundle;",
                "import 'package:flutter/services.dart';\nimport 'package:route/services/gtfs_sync_service.dart';"
            )
        elif "import 'package:flutter/services.dart';" in content and "import 'package:route/services/gtfs_sync_service.dart';" not in content:
            content = content.replace(
                "import 'package:flutter/services.dart';",
                "import 'package:flutter/services.dart';\nimport 'package:route/services/gtfs_sync_service.dart';"
            )

        with open(filepath, 'w') as f:
            f.write(content)

print('Replacement complete.')
