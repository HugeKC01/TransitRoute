import 'package:flutter/material.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;
import 'package:route/widgets/station_details_content.dart';

class StationDetailsPage extends StatelessWidget {
  const StationDetailsPage({
    super.key,
    required this.stop,
    required this.lineColor,
    this.lineName,
    required this.onSelectAsStart,
    required this.onSelectAsDestination,
    this.transferStops = const [],
    this.lineNameResolver,
    this.lineColorResolver,
    this.lineColorByName,
    this.onTransferStationSelected,
  });

  final gtfs.Stop stop;
  final Color lineColor;
  final String? lineName;
  final VoidCallback onSelectAsStart;
  final VoidCallback onSelectAsDestination;
  final List<gtfs.Stop> transferStops;
  final String? Function(String stopId)? lineNameResolver;
  final Color Function(String stopId)? lineColorResolver;
  final Color Function(String lineName)? lineColorByName;
  final void Function(gtfs.Stop stop)? onTransferStationSelected;

  @override
  Widget build(BuildContext context) {
    final hasThaiName =
        stop.thaiName != null && stop.thaiName!.trim().isNotEmpty;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600 && size.width > size.height;

    final content = StationDetailsContent(
      stop: stop,
      lineColor: lineColor,
      lineName: lineName,
      onSelectAsStart: () {
        onSelectAsStart();
        Navigator.pop(context);
      },
      onSelectAsDestination: () {
        onSelectAsDestination();
        Navigator.pop(context);
      },
      transferStops: transferStops,
      lineNameResolver: lineNameResolver,
      lineColorResolver: lineColorResolver,
      lineColorByName: lineColorByName,
      onTransferStationSelected: (tStop) {
        if (onTransferStationSelected != null) {
          onTransferStationSelected!(tStop);
        }
      },
      isBottomSheet: false,
    );

    if (isWide) {
      return Scaffold(
        backgroundColor: Colors
            .transparent, // Make background transparent to show map underneath
        body: Stack(
          children: [
            // Detect taps outside the panel to close it
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
            // Right-aligned side panel
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 420,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(-2, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    AppBar(
                      title: Text(hasThaiName ? stop.thaiName! : stop.name),
                      centerTitle: true,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                    ),
                    Expanded(child: content),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(hasThaiName ? stop.thaiName! : stop.name),
        centerTitle: true,
      ),
      body: content,
    );
  }
}
