import re

with open("lib/main.dart", "r") as f:
    text = f.read()

m = re.search(r"class FavoritePin \{.*\}", text, re.DOTALL)
if m:
    print(m.group(0)[:500])
