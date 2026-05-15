import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter/material.dart';
import 'package:route/pages/about_page.dart';
import 'package:route/services/gtfs_sync_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;

class Profile {
  final String username;
  final String name;
  final String joinedDate;
  final String profileImageUrl;
  final List<dynamic>? favoritePins;

  const Profile({
    required this.username,
    required this.name,
    required this.joinedDate,
    required this.profileImageUrl,
    this.favoritePins,
  });

  Profile copyWith({
    String? username,
    String? name,
    String? joinedDate,
    String? profileImageUrl,
    List<dynamic>? favoritePins,
  }) {
    return Profile(
      username: username ?? this.username,
      name: name ?? this.name,
      joinedDate: joinedDate ?? this.joinedDate,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      favoritePins: favoritePins ?? this.favoritePins,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'name': name,
      'joinedDate': joinedDate,
      'profileImageUrl': profileImageUrl,
      'favoritePins': favoritePins,
    };
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      joinedDate: json['joinedDate'] ?? '',
      profileImageUrl: json['profileImageUrl'] ?? '',
      favoritePins: json['favoritePins'] as List<dynamic>?,
    );
  }
}

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.onOpenTransportLines,
    required this.onOpenTransitUpdates,
    required this.onOpenGraphicMap,
    required this.onOpenCards,
    required this.onSelectFavoritePin,
    required this.profile,
    required this.onProfileUpdated,
    required this.currentAccentColor,
    required this.onAccentColorChanged,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
    required this.allStops,
    required this.routeIconByName,
    required this.lineColorByName,
    required this.stopToLinesMap,
  });

  final VoidCallback onOpenTransportLines;
  final VoidCallback onOpenTransitUpdates;
  final VoidCallback onOpenGraphicMap;
  final VoidCallback onOpenCards;
  final void Function(double lat, double lon) onSelectFavoritePin;
  final Profile profile;
  final ValueChanged<Profile> onProfileUpdated;

  final Color currentAccentColor;
  final ValueChanged<Color> onAccentColorChanged;
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  final List<gtfs.Stop> allStops;
  final String? Function(String) routeIconByName;
  final Color Function(String) lineColorByName;
  final Map<String, Set<String>> stopToLinesMap;

  void _showEditProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _EditProfileDialog(
        currentProfile: profile,
        onProfileUpdated: onProfileUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, topInset + 20, 16, bottomInset + 16),
      children: [
        // Dynamic profile card
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: profile.profileImageUrl.isNotEmpty
                      ? NetworkImage(profile.profileImageUrl)
                      : null,
                  child: profile.profileImageUrl.isEmpty
                      ? const Icon(Icons.person, size: 32)
                      : null,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.username,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Joined ${profile.joinedDate}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: theme.colorScheme.outline,
                  onPressed: () => _showEditProfileDialog(context),
                ),
              ],
            ),
          ),
        ),
        Text(
          'More options',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.list_alt_rounded),
                title: const Text('Transit lines'),
                subtitle: const Text('Browse every available line'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenTransportLines,
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              ListTile(
                leading: const Icon(Icons.report_gmailerrorred_outlined),
                title: const Text('Report transit issue'),
                subtitle: const Text('Share outages or disruptions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenTransitUpdates,
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              ListTile(
                leading: const Icon(Icons.credit_card_outlined),
                title: const Text('My Transit Cards'),
                subtitle: const Text('Manage cards'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenCards,
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              ListTile(
                leading: const Icon(Icons.favorite_outline_rounded),
                title: const Text('Saved locations'),
                subtitle: const Text('View and manage favorited pins'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _FavoritedPinsPage(
                        profile: profile,
                        onProfileUpdated: onProfileUpdated,
                        onPinSelected: onSelectFavoritePin,
                        allStops: allStops,
                        routeIconByName: routeIconByName,
                        lineColorByName: lineColorByName,
                        stopToLinesMap: stopToLinesMap,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'App settings',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              const _GtfsVersionTile(),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Theme Mode'),
                subtitle: const Text('Select application theme'),
                trailing: DropdownButton<ThemeMode>(
                  value: currentThemeMode,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) {
                      onThemeModeChanged(mode);
                    }
                  },
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Theme Color'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...[
                        Colors.blue,
                        Colors.red,
                        Colors.green,
                        Colors.purple,
                        Colors.orange,
                        Colors.teal,
                        Colors.indigo,
                      ].map(
                        (color) => GestureDetector(
                          onTap: () => onAccentColorChanged(color),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: currentAccentColor == color
                                  ? Border.all(
                                      color: theme.colorScheme.onSurface,
                                      width: 2,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Support',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                subtitle: const Text('Version 1.0.0 • OSS licenses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AboutPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GtfsVersionTile extends StatefulWidget {
  const _GtfsVersionTile();

  @override
  State<_GtfsVersionTile> createState() => _GtfsVersionTileState();
}

class _GtfsVersionTileState extends State<_GtfsVersionTile> {
  int _currentVersion = 0;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final ver = await gtfsSyncService.getLocalVersion();
    if (mounted) {
      setState(() {
        _currentVersion = ver;
      });
    }
  }

  Future<void> _handleCheckUpdates() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
    });

    final message = await gtfsSyncService.manualUpdateCheck();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _isChecking = false;
      });
      await _loadVersion();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.system_update_alt_outlined),
      title: const Text('Transit Data Package'),
      subtitle: Text('Local version: $_currentVersion (Tap to check)'),
      trailing: _isChecking
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _handleCheckUpdates,
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final Profile currentProfile;
  final ValueChanged<Profile> onProfileUpdated;

  const _EditProfileDialog({
    required this.currentProfile,
    required this.onProfileUpdated,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _usernameController;
  late final TextEditingController _nameController;
  late final TextEditingController _avatarUrlController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.currentProfile.username,
    );
    _nameController = TextEditingController(text: widget.currentProfile.name);
    _avatarUrlController = TextEditingController(
      text: widget.currentProfile.profileImageUrl,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _save() {
    final newProfile = widget.currentProfile.copyWith(
      username: _usernameController.text.trim(),
      name: _nameController.text.trim(),
      profileImageUrl: _avatarUrlController.text.trim(),
    );
    widget.onProfileUpdated(newProfile);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _avatarUrlController,
              decoration: const InputDecoration(labelText: 'Avatar URL'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _FavoritedPinsPage extends StatefulWidget {
  final Profile profile;
  final ValueChanged<Profile> onProfileUpdated;
  final void Function(double lat, double lon) onPinSelected;
  final List<gtfs.Stop> allStops;
  final String? Function(String) routeIconByName;
  final Color Function(String) lineColorByName;
  final Map<String, Set<String>> stopToLinesMap;

  const _FavoritedPinsPage({
    required this.profile,
    required this.onProfileUpdated,
    required this.onPinSelected,
    required this.allStops,
    required this.routeIconByName,
    required this.lineColorByName,
    required this.stopToLinesMap,
  });

  @override
  State<_FavoritedPinsPage> createState() => _FavoritedPinsPageState();
}

class _FavoritedPinsPageState extends State<_FavoritedPinsPage> {
  @override
  Widget build(BuildContext context) {
    final pins = widget.profile.favoritePins ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Saved locations')),
      body: pins.isEmpty
          ? const Center(child: Text('No saved locations yet.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
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

                gtfs.Stop? matchedStop;
                try {
                  matchedStop = widget.allStops.firstWhere(
                    (s) => s.lat == lat && s.lon == lng,
                  );
                } catch (_) {}

                final lines =
                    (matchedStop != null &&
                        widget.stopToLinesMap.containsKey(matchedStop.stopId))
                    ? widget.stopToLinesMap[matchedStop.stopId]!
                    : <String>{};

                String displayTitle = label;
                if (matchedStop != null && matchedStop.name.isNotEmpty) {
                  displayTitle = matchedStop.name;
                }

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
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'app.transitroute.user',
                                  maxNativeZoom: 19,
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(lat, lng),
                                      width: 24,
                                      height: 24,
                                      child: matchedStop != null
                                          ? Container(
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade700,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.directions_bus,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                            )
                                          : Container(
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
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
                              if (matchedStop != null &&
                                  matchedStop.code?.isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          matchedStop.code ?? '',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (lines.isNotEmpty)
                                        Expanded(
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: lines.map((shortName) {
                                                final iconSvg = widget
                                                    .routeIconByName(shortName);
                                                final color = widget
                                                    .lineColorByName(shortName);

                                                if (iconSvg != null) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 4.0,
                                                        ),
                                                    child: SvgPicture.string(
                                                      iconSvg,
                                                      width: 16,
                                                      height: 16,
                                                      placeholderBuilder:
                                                          (
                                                            BuildContext
                                                            context,
                                                          ) => Container(
                                                            width: 16,
                                                            height: 16,
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: color,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                          ),
                                                    ),
                                                  );
                                                } else {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 4.0,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: color,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        shortName,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              Text(
                                displayTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
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
