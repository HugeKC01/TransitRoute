import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:route/pages/about_page.dart';
import 'package:route/services/gtfs_sync_service.dart';

class Profile {
  final String username;
  final String name;
  final String joinedDate;
  final String profileImageUrl;

  const Profile({
    required this.username,
    required this.name,
    required this.joinedDate,
    required this.profileImageUrl,
  });

  Profile copyWith({
    String? username,
    String? name,
    String? joinedDate,
    String? profileImageUrl,
  }) {
    return Profile(
      username: username ?? this.username,
      name: name ?? this.name,
      joinedDate: joinedDate ?? this.joinedDate,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'name': name,
      'joinedDate': joinedDate,
      'profileImageUrl': profileImageUrl,
    };
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      joinedDate: json['joinedDate'] ?? '',
      profileImageUrl: json['profileImageUrl'] ?? '',
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
    required this.profile,
    required this.onProfileUpdated,
    required this.currentAccentColor,
    required this.onAccentColorChanged,
  });

  final VoidCallback onOpenTransportLines;
  final VoidCallback onOpenTransitUpdates;
  final VoidCallback onOpenGraphicMap;
  final VoidCallback onOpenCards;
  final Profile profile;
  final ValueChanged<Profile> onProfileUpdated;

  final Color currentAccentColor;
  final ValueChanged<Color> onAccentColorChanged;

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
                      GestureDetector(
                        onTap: () {
                          Color tempColor = currentAccentColor;
                          showDialog(
                            context: context,
                            builder: (context) => StatefulBuilder(
                              builder: (context, setState) => AlertDialog(
                                title: const Text('Custom Color'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: tempColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Slider(
                                      value: (tempColor.r * 255.0)
                                          .round()
                                          .toDouble(),
                                      min: 0,
                                      max: 255,
                                      activeColor: Colors.red,
                                      onChanged: (v) => setState(
                                        () => tempColor = Color.fromARGB(
                                          (tempColor.a * 255).round(),
                                          v.toInt(),
                                          (tempColor.g * 255).round(),
                                          (tempColor.b * 255).round(),
                                        ),
                                      ),
                                    ),
                                    Slider(
                                      value: (tempColor.g * 255.0)
                                          .round()
                                          .toDouble(),
                                      min: 0,
                                      max: 255,
                                      activeColor: Colors.green,
                                      onChanged: (v) => setState(
                                        () => tempColor = Color.fromARGB(
                                          (tempColor.a * 255).round(),
                                          (tempColor.r * 255).round(),
                                          v.toInt(),
                                          (tempColor.b * 255).round(),
                                        ),
                                      ),
                                    ),
                                    Slider(
                                      value: (tempColor.b * 255.0)
                                          .round()
                                          .toDouble(),
                                      min: 0,
                                      max: 255,
                                      activeColor: Colors.blue,
                                      onChanged: (v) => setState(
                                        () => tempColor = Color.fromARGB(
                                          (tempColor.a * 255).round(),
                                          (tempColor.r * 255).round(),
                                          (tempColor.g * 255).round(),
                                          v.toInt(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      onAccentColorChanged(tempColor);
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.onSurface,
                              width: 2,
                            ),
                          ),
                          child: const Icon(Icons.add, size: 16),
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
              const ListTile(
                leading: Icon(Icons.help_outline),
                title: Text('Help & feedback'),
                subtitle: Text('FAQs, chat with support'),
                trailing: Icon(Icons.chevron_right),
              ),
              const Divider(height: 1),
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
