sed -i '' -e 's/final routesFuture = rootBundle.loadString('\''assets\/gtfs_data\/routes.txt'\'');/final loadedRoutes = <gtfs.Route>[];/' lib/transport_lines_page.dart
