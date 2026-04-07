with open("lib/main.dart", "r") as f:
    text = f.read()

old_button = """                quickAction(
                  icon: Icons.trip_origin,
                  title: 'Set as origin',"""

new_button = """                quickAction(
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

with open("lib/main.dart", "w") as f:
    f.write(text)
