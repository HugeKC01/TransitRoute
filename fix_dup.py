with open("lib/services/direction_service.dart", "r") as f:
    content = f.read()

import re
content = re.sub(r' +routeType: seg\.routeType,\n *(routeType: seg\.routeType,)', r'              routeType: seg.routeType,', content)
content = re.sub(
    r'( +)routeType: currentLineName != null \? getRouteTypeForLine\(currentLineName\) : null,\n +\1routeType: currentLineName != null \? getRouteTypeForLine\(currentLineName\) : null,',
    r'\1routeType: currentLineName != null ? getRouteTypeForLine(currentLineName) : null,',
    content
)

with open("lib/services/direction_service.dart", "w") as f:
    f.write(content)
