import os

code_to_add = """
class _FavoritedPinsPage extends StatefulWidget {
  final Profile profile;
  final ValueChanged<Profile> onProfileUpdated;
  final void Function(double lat, double lon) onPinSelected;

  const _FavoritedPinsPage({
    required this.profile,
    required this.onProfileUpdated,
    required this.onPinSelected,
  });

  @override
  State<_FavoritedPinsPage> createState() => _FavoritedPinsPageState();
}

class _FavoritedPinsPageState extends State<_FavoritedPinsPage> {
  @override
  Widget build(BuildContext context) {
    final pins = widget.profile.favoritePins ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved locations'),
      ),
      body: pins.isEmpty
          ? const Center(child: Text('No saved locations yet.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: pins.length,
              itemBuilder: (context, index) {
                final pin = pins[index] as Map<String, dynamic>;
                final label = pin['label'] as String? ?? 'Saved Pin';
                final lat = pin['lat'] as double? ?? 0.0;
                final lng = pin['lng'] as double? ?? 0.0;

                return Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onPinSelected(lat, lng);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: IgnorePointer(
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(lat, lng),
                                initialZoom: 15,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.example.transitroute',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(lat, lng),
                                      width: 24,
                                      height: 24,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.favorite,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                LAT_LNG_TXT,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
"""

dart_code = code_to_add.replace("LAT_LNG_TXT", "'${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'")

with open("/Users/hugekc/Coding/TransitRoute/lib/pages/more_page.dart", "r") as f:
    content = f.read()

if "class _FavoritedPinsPage" not in content:
    with open("/Users/hugekc/Coding/TransitRoute/lib/pages/more_page.dart", "a") as f:
        f.write(dart_code)
