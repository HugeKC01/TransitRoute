import re

with open('lib/main.dart', 'r') as f:
    text = f.read()

print("viewBuilder" in text)
