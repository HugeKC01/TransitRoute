with open("lib/services/direction_service.dart", "r") as f:
    content = f.read()

import re
content = re.sub(
    r'routeShortName: currentLineName,',
    r'routeShortName: currentLineName,\n              routeType: currentLineName != null ? getRouteTypeForLine(currentLineName) : null,',
    content
)

# And fix line 684 which has `routeShortName: seg.routeShortName,`
content = re.sub(
    r'routeShortName: seg.routeShortName,',
    r'routeShortName: seg.routeShortName,\n              routeType: seg.routeType,',
    content
)


with open("lib/services/direction_service.dart", "w") as f:
    f.write(content)
