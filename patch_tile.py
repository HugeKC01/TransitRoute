import sys

with open('lib/pages/transport_lines_details_page.dart', 'r') as f:
    text = f.read()

old_tile = """                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4.0,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: routeColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: routeColor, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: routeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      stop.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: (stop.code != null && stop.code!.isNotEmpty)
                        ? Text(
                            stop.code!,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : null,
                    trailing: const Icon(
                      Icons.location_on,
                      size: 20,
                      color: Colors.grey,
                    ),
                  );"""

new_tile = """                  final hasThai = stop.thaiName != null && stop.thaiName!.trim().isNotEmpty;
                  final displayCode = (stop.code != null && stop.code!.trim().isNotEmpty) ? stop.code! : '${index + 1}';
                  return ListTile(
                    onTap: () {
                      import_main_if_needed(); // Actually I will just fix the import
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => route.MyHomePage(
                            title: 'Route Transit',
                            currentAccentColor: theme.colorScheme.primary,
                            onAccentColorChanged: (c) {},
                            currentThemeMode: theme.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
                            onThemeModeChanged: (m) {},
                            initialViewingStop: stop,
                          ),
                        ),
                      );
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4.0,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: routeColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: routeColor, width: 2),
                      ),
                      child: Center(
                        child: FittedBox(
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              displayCode,
                              style: TextStyle(
                                color: routeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      hasThai ? stop.thaiName! : stop.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: hasThai
                        ? Text(
                            stop.name,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                    trailing: const Icon(
                      Icons.map,
                      size: 20,
                      color: Colors.grey,
                    ),
                  );"""

text = text.replace(old_tile, new_tile.replace("import_main_if_needed(); // Actually I will just fix the import", ""))

if text.find("import 'package:route/main.dart' as route;") == -1:
    text = "import 'package:route/main.dart' as route;\n" + text

with open('lib/pages/transport_lines_details_page.dart', 'w') as f:
    f.write(text)

