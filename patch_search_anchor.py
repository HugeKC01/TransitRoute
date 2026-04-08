import sys

with open('lib/main.dart', 'r') as f:
    text = f.read()

# I will check if we can add viewBackgroundColor and viewElevation to make it transparent
# so the blurring in ServiceTabs can work.
