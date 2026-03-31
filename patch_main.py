import re

with open('lib/main.dart', 'r') as f:
    text = f.read()

text = text.replace(
    'Map<String, String> fareTypeMap = {};',
    'Map<String, String> fareTypeMap = {};\n  Map<String, gtfs.BusRouteInfo> busRouteInfoMap = {};'
)

with open('lib/main.dart', 'w') as f:
    f.write(text)
