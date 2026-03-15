import 'package:flutter/material.dart';

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
}

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.onOpenTransportLines,
    required this.onOpenTransitUpdates,
    required this.onOpenGraphicMap,
    required this.onOpenCards,
    required this.profile,
    required this.currentAccentColor,
    required this.onAccentColorChanged,
  });

  final VoidCallback onOpenTransportLines;
  final VoidCallback onOpenTransitUpdates;
  final VoidCallback onOpenGraphicMap;
  final VoidCallback onOpenCards;
  final Profile profile;
  
  final Color currentAccentColor;
  final ValueChanged<Color> onAccentColorChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, topInset + 20, 16, 20),
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
                  backgroundImage: NetworkImage(profile.profileImageUrl),
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
                leading: const Icon(Icons.map_outlined),
                title: const Text('Transit System Map'),
                subtitle: const Text('View graphic BTS/MRT connection map'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenGraphicMap,
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              ListTile(
                leading: const Icon(Icons.credit_card_outlined),
                title: const Text('My Transit Cards'),
                subtitle: const Text('Manage cards and view promotions'),
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
              const ListTile(
                leading: Icon(Icons.language),
                title: Text('App language'),
                subtitle: Text('English (system default)'),
                trailing: Icon(Icons.chevron_right),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              const ListTile(
                leading: Icon(Icons.translate),
                title: Text('Station name language'),
                subtitle: Text('English + Thai'),
                trailing: Icon(Icons.chevron_right),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              SwitchListTile.adaptive(
                value: true,
                onChanged: (_) {},
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Notifications'),
                subtitle: const Text('Receive disruption and fare alerts'),
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
                        Colors.pink,
                        Colors.indigo,
                        Colors.cyan,
                        Colors.brown,
                        Colors.amber,
                        Colors.deepOrange,
                      ].map((color) => GestureDetector(
                            onTap: () => onAccentColorChanged(color),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: currentAccentColor.value == color.value
                                    ? Border.all(color: theme.colorScheme.onSurface, width: 2)
                                    : null,
                              ),
                            ),
                          )),
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
                                      value: tempColor.red.toDouble(),
                                      min: 0,
                                      max: 255,
                                      activeColor: Colors.red,
                                      onChanged: (v) => setState(() => tempColor = tempColor.withRed(v.toInt())),
                                    ),
                                    Slider(
                                      value: tempColor.green.toDouble(),
                                      min: 0,
                                      max: 255,
                                      activeColor: Colors.green,
                                      onChanged: (v) => setState(() => tempColor = tempColor.withGreen(v.toInt())),
                                    ),
                                    Slider(
                                      value: tempColor.blue.toDouble(),
                                      min: 0,
                                      max: 255,
                                      activeColor: Colors.blue,
                                      onChanged: (v) => setState(() => tempColor = tempColor.withBlue(v.toInt())),
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
                            border: Border.all(color: theme.colorScheme.onSurface, width: 2),
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
            children: const [
              ListTile(
                leading: Icon(Icons.help_outline),
                title: Text('Help & feedback'),
                subtitle: Text('FAQs, chat with support'),
                trailing: Icon(Icons.chevron_right),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('About'),
                subtitle: Text('Version 1.0.0 • OSS licenses'),
                trailing: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
