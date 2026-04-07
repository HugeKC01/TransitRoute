import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // App Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.directions_transit,
                    size: 48,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'TransitRoute',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Data Credits
          Text(
            'Data Sources',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Transit data (routes, stops, timetables) is sourced from public GTFS data and individual transit agency websites. We credit the local transit authorities and agencies for making their data available on the web.',
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  title: Text('Mobility Database (GTFS)'),
                  subtitle: Text(
                    'https://mobilitydatabase.org/feeds/gtfs/mdb-1831',
                  ),
                ),
                ListTile(
                  title: Text('Chao Phraya Express Boat'),
                  subtitle: Text(
                    'https://www.chaophrayaexpressboat.com/chaophrayaexpressboat',
                  ),
                ),
                ListTile(
                  title: Text('BMTA'),
                  subtitle: Text('https://www.bmta.co.th/bus-lines'),
                ),
                ListTile(
                  title: Text('BEM Metro'),
                  subtitle: Text('https://metro.bemplc.co.th/?lang=th'),
                ),
                ListTile(
                  title: Text('BTS SkyTrain'),
                  subtitle: Text('https://www.bts.co.th/'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Asset Credits
          Text(
            'Assets & Design',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Icons and UI elements use Material Design, Cupertino Icons, and custom SVG assets. Map imagery and tiles are rendered via Flutter Map and OpenStreetMap.',
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Open Source Packages
          Text(
            'Open Source Packages',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const ListTile(
                  title: Text('Flutter Packages'),
                  subtitle: Text(
                    'archive, cloud_firestore, collection, cupertino_icons, firebase_core, firebase_storage, flutter_map, flutter_svg, google_fonts, http, latlong2, location, path_provider, shared_preferences, sqflite.',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('View OSS Licenses'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'TransitRoute',
                      applicationVersion: '1.0.0',
                      applicationIcon: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Icon(
                          Icons.directions_transit,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Center(
            child: Text(
              'Made with ❤️ for transit riders',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
