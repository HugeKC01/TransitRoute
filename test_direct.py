import re

with open('lib/services/direction_service.dart', 'r') as f:
    text = f.read()

idx = text.find('_findDirectTrip')
print(text[idx:idx+1500])
