with open("lib/main.dart", "r") as f:
    text = f.read()

# Fix 1: Remove `_loadFavoritePins();` inside `_MyAppState`
if "class _MyAppState" in text:
    myapp_idx = text.find("class _MyAppState")
    init_state_idx = text.find("void initState()", myapp_idx)
    init_end = text.find("}", init_state_idx)
    myapp_init = text[init_state_idx:init_end]
    myapp_init_new = myapp_init.replace("    _loadFavoritePins();\n", "")
    text = text[:init_state_idx] + myapp_init_new + text[init_end:]


# Fix 2: Add `_promptSaveFavorite` button to `_showDroppedPinDetails`
old_button = """quickAction(
                    icon: Icons.trip_origin,
                    title: 'Set as origin',"""
new_button = """quickAction(
                    icon: Icons.favorite_border,
                    title: 'Save to Favorites',
                    subtitle: 'Save this location as a favorite pin',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _promptSaveFavorite(point);
                    },
                  ),
                  quickAction(
                    icon: Icons.trip_origin,
                    title: 'Set as origin',"""

if "Save to Favorites" not in text:
    text = text.replace(old_button, new_button)

print("Has favorite markers layer:", "if (_favoritePins.isNotEmpty)" in text)

with open("lib/main.dart", "w") as f:
    f.write(text)
