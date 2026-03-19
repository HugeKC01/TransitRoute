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
    final hasThaiName = stop.thaiName != null && stop.thaiName!.trim().isNotEmpty;
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(hasThaiName ? stop.thaiName! : stop.name),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 600 : double.infinity),
          child: StationDetailsContent(
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
          ),
        ),
      ),
    );
  }
}
