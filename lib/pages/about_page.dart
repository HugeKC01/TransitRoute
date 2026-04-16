import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.directions_transit,
                      size: 40,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TransitRoute',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.new_releases_outlined,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Version 1.0.0',
                              style: theme.textTheme.bodyMedium?.copyWith(
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
          const SizedBox(height: 32),

          // Disclaimer
          Card(
            clipBehavior: Clip.antiAlias,
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Disclaimer of Government Affiliation',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'TransitRoute is an independent academic prototype developed solely as a student senior project. This application does not represent, nor is it affiliated with, endorsed by, sponsored by, or officially connected to the Thai government or any of the aforementioned government agencies or private transit corporations. The data in this application covers the Bangkok metropolitan area and may contain inaccuracies or incomplete information. Travel times, routes, and fare data are partially estimated and may be outdated due to real-world transit changes. Users should always verify routes, schedules, and fares with official transit staff and official government announcements for the most accurate information.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Welcome Text
          Card(
            clipBehavior: Clip.antiAlias,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Welcome / ยินดีต้อนรับ',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'TransitRoute is an independent prototype developed as part of a senior project by students at King Mongkut\'s University of Technology Thonburi (KMUTT). This app does not represent, nor is it affiliated with, endorsed by, or officially connected to the Thai government, or any government agency.\n\n'
                    'The data in this app covers only the Bangkok metropolitan area and may contain inaccuracies or incomplete information. For example, travel time and fare data are partially estimated and may be outdated. Users should verify with official staff for the most accurate information.\n\n'
                    '---\n\n'
                    'TransitRoute เป็นเพียงต้นแบบที่พัฒนาขึ้นเพื่อเป็นส่วนหนึ่งของโครงงานก่อนจบการศึกษาของนักศึกษามหาวิทยาลัยเทคโนโลยีพระจอมเกล้าธนบุรี (KMUTT) แอปนี้ไม่ได้เป็นตัวแทน และไม่มีความเกี่ยวข้อง ไม่ได้รับการรับรอง หรือมีความเชื่อมโยงอย่างเป็นทางการกับรัฐบาลไทยหรือหน่วยงานรัฐบาล\n\n'
                    'ข้อมูลในแอปนี้ครอบคลุมเฉพาะพื้นที่กรุงเทพมหานครเท่านั้น และอาจมีความคลาดเคลื่อนหรือไม่สมบูรณ์ของข้อมูล อาทิ ข้อมูลเวลาเดินทางและค่าโดยสารมีการใช้ประมาณเป็นบางส่วนอาจมีความคลาดเคลื่อนและไม่เป็นปัจจุบัน ผู้ใช้ควรสอบถามกับเจ้าหน้าที่อีกครั้งเพื่อความถูกต้องของข้อมูล',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Data Credits
          Text(
            'Data Sources',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'The transit data, route information, and fare calculations used in this application are sourced from public information provided by:',
                  ),
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                ListTile(
                  title: const Text('Mobility Database (GTFS)'),
                  subtitle: const Text(
                    'https://mobilitydatabase.org/feeds/gtfs/mdb-1831',
                  ),
                  trailing: const Icon(Icons.open_in_browser),
                  onTap: () async {
                    final uri = Uri.parse(
                      'https://mobilitydatabase.org/feeds/gtfs/mdb-1831',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                ListTile(
                  title: const Text('License: CC-BY-4.0'),
                  subtitle: const Text(
                    'https://creativecommons.org/licenses/by/4.0/',
                  ),
                  trailing: const Icon(Icons.open_in_browser),
                  onTap: () async {
                    final uri = Uri.parse(
                      'https://creativecommons.org/licenses/by/4.0/',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                ListTile(
                  title: const Text('OpenStreetMap'),
                  subtitle: const Text('https://www.openstreetmap.org/'),
                  trailing: const Icon(Icons.open_in_browser),
                  onTap: () async {
                    final uri = Uri.parse('https://www.openstreetmap.org/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Overpass Turbo'),
                  subtitle: const Text('https://overpass-turbo.eu/'),
                  trailing: const Icon(Icons.open_in_browser),
                  onTap: () async {
                    final uri = Uri.parse('https://overpass-turbo.eu/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Chao Phraya Express Boat'),
                  subtitle: const Text(
                    'https://www.chaophrayaexpressboat.com/chaophrayaexpressboat',
                  ),
                  trailing: const Icon(Icons.open_in_browser),
                  onTap: () async {
                    final uri = Uri.parse(
                      'https://www.chaophrayaexpressboat.com/chaophrayaexpressboat',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Bangkok Mass Transit Authority (BMTA)'),
                  subtitle: const Text('https://www.bmta.co.th/bus-lines'),
                  trailing: const Icon(Icons.open_in_browser),
                  onTap: () async {
                    final uri = Uri.parse('https://www.bmta.co.th/bus-lines');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Bangkok Expressway and Metro Public Company Limited (BEM)'),
                  subtitle: const Text('https://metro.bemplc.co.th/?lang=th'),
                  trailing: const Icon(Icons.open_in_browser),
                  onTap: () async {
                    final uri = Uri.parse(
                      'https://metro.bemplc.co.th/?lang=th',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Bangkok Mass Transit System Public Company Limited (BTSC)'),
                  subtitle: const Text('https://www.bts.co.th/'),
                  trailing: const Icon(Icons.open_in_browser),
                  onTap: () async {
                    final uri = Uri.parse('https://www.bts.co.th/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Mass Rapid Transit Authority of Thailand (MRTA)'),
                  subtitle: const Text('https://www.mrta.co.th/'),
                  trailing: const Icon(Icons.open_in_browser),
                  onTap: () async {
                    final uri = Uri.parse('https://www.mrta.co.th/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Thai Smile Group'),
                  subtitle: const Text('https://thaismilegroup.com/'),
                  trailing: const Icon(Icons.open_in_browser),
                  onTap: () async {
                    final uri = Uri.parse('https://thaismilegroup.com/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                ListTile(
                  title: const Text(
                    'Office of Transport and Traffic Policy and Planning (OTP), Ministry of Transport',
                  ),
                  subtitle: const Text('https://www.otp.go.th'),
                  trailing: const Icon(Icons.open_in_browser),
                  onTap: () async {
                    final uri = Uri.parse('https://www.otp.go.th');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // GTFS License
          Text(
            'GTFS License',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Except as otherwise noted, the content of this site is licensed under the Creative Commons Attribution 3.0 License, and code samples are licensed under the Apache 2.0 License.',
                  ),
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.open_in_browser),
                  title: const Text('GTFS About Page'),
                  subtitle: const Text('https://gtfs.org/about/'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final uri = Uri.parse('https://gtfs.org/about/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // OpenStreetMap License
          Text(
            'OpenStreetMap License',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'OpenStreetMap® is open data, licensed under the Open Data Commons Open Database License (ODbL) by the OpenStreetMap Foundation (OSMF).',
                  ),
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.open_in_browser),
                  title: const Text('OpenStreetMap Copyright and License'),
                  subtitle: const Text('https://www.openstreetmap.org/copyright'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final uri = Uri.parse('https://www.openstreetmap.org/copyright');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Asset Credits
          Text(
            'Assets & Design',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Icons and UI elements use Material Design, Cupertino Icons, and custom SVG assets. Map imagery and tiles are rendered via Flutter Map and OpenStreetMap.',
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Trademarks & Image Credits
          Text(
            'Trademarks & Image Credits',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'The transit system logos and icons used within this application are registered trademarks of their respective owners:\n'
                '• MRT: Mass Rapid Transit Authority of Thailand (MRTA)\n'
                '• BTS: Bangkok Mass Transit System Public Company Limited (BTSC)\n'
                '• SRT Red Lines & ARL: State Railway of Thailand (SRT)\n'
                '• Bangkok BRT: Bangkok Metropolitan Administration (BMA)\n\n'
                'These logo images were sourced from Wikimedia Commons (Public Domain) and are used strictly for nominative identification purposes to assist users in navigating the transit systems.',
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Open Source Packages
          Text(
            'Open Source Packages',
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
                  title: Text('Flutter Packages'),
                  subtitle: Text(
                    'archive, cloud_firestore, collection, cupertino_icons, firebase_core, firebase_storage, flutter_map, flutter_svg, google_fonts, http, latlong2, location, path_provider, shared_preferences, sqflite, url_launcher.',
                  ),
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
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
