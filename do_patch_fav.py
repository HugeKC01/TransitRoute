import json
import re

with open("lib/main.dart", "r") as f:
    content = f.read()

# 1. Add FavoritePin class inside or before _MyHomePageState
if "class FavoritePin" not in content:
    class_def = """
class FavoritePin {
  final String label;
  final LatLng point;
  FavoritePin(this.label, this.point);
  Map<String, dynamic> toJson() => {
    'label': label,
    'lat': point.latitude,
    'lng': point.longitude,
  };
  factory FavoritePin.fromJson(Map<String, dynamic> json) => FavoritePin(
    json['label'] as String,
    LatLng(json['lat'] as double, json['lng'] as double),
  );
}
"""
    content = content.replace("class _MyHomePageState", class_def + "\nclass _MyHomePageState")

# 2. Add state variable
if "List<FavoritePin> _favoritePins =" not in content:
    state_var = """
  List<FavoritePin> _favoritePins = [];

  Future<void> _loadFavoritePins() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('favorite_pins');
    if (jsonStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        setState(() {
          _favoritePins = decoded.map((e) => FavoritePin.fromJson(e as Map<String, dynamic>)).toList();
        });
      } catch (e) {
        debugPrint('Failed to load favorite pins: $e');
      }
    }
  }

  Future<void> _saveFavoritePins() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_favoritePins.map((e) => e.toJson()).toList());
    await prefs.setString('favorite_pins', jsonStr);
  }
"""
    content = content.replace("final MapController _mapController = MapController();", "final MapController _mapController = MapController();\n" + state_var)

# 3. Call _loadFavoritePins in initState
if "_loadFavoritePins();" not in content:
    content = content.replace("super.initState();\n", "super.initState();\n    _loadFavoritePins();\n")

# 4. Modify _showDroppedPinDetails to allow adding to favorites
if "_saveFavoriteCustomPoint" not in content and "_promptSaveFavorite" not in content:
    add_fav_btn = """
                  quickAction(
                    icon: Icons.favorite_border,
                    title: 'Save to Favorites',
                    subtitle: 'Save this location as a favorite pin',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _promptSaveFavorite(point);
                    },
                  ),
"""
    content = content.replace("                  quickAction(\n                    icon: Icons.trip_origin,", add_fav_btn + "                  quickAction(\n                    icon: Icons.trip_origin,")

    prompt_fun = """
  void _promptSaveFavorite(LatLng point) {
    String label = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save Favorite Pin'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Label'),
            onChanged: (val) => label = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (label.isNotEmpty) {
                  setState(() {
                    _favoritePins.add(FavoritePin(label, point));
                  });
                  _saveFavoritePins();
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
"""
    content = content.replace("void _showDroppedPinDetails", prompt_fun + "\n  void _showDroppedPinDetails")

# 5. Render markers for favorites
if "_favoritePins.map(" not in content:
    fav_markers = """
              if (_favoritePins.isNotEmpty)
                MarkerLayer(
                  markers: _favoritePins.map((pin) => Marker(
                    point: pin.point,
                    width: 100,
                    height: 50,
                    child: Column(
                      children: [
                        const Icon(Icons.favorite, color: Colors.pink, size: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                          child: Text(pin.label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink, fontSize: 10)),
                        )
                      ],
                    ),
                  )).toList(),
                ),
"""
    content = content.replace("if (showBusStops)", fav_markers + "\n              if (showBusStops)")

with open("lib/main.dart", "w") as f:
    f.write(content)
print("Patched main.dart successfully.")
