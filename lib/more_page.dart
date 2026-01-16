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
    required this.profile,
  });

  final VoidCallback onOpenTransportLines;
  final VoidCallback onOpenTransitUpdates;
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, topInset + 20, 16, 20),
      children: [
        // Dynamic profile card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                          Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.outline),
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
