import 'package:flutter/material.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;
import 'package:route/widgets/station_details_content.dart';

class StationDetailsPage extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

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
    this.routeIconByName,
    this.onTransferStationSelected,
    this.isFavorite = false,
    this.onToggleFavorite,
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
  final String? Function(String lineName)? routeIconByName;
  final void Function(gtfs.Stop stop)? onTransferStationSelected;

  @override
  State<StationDetailsPage> createState() => _StationDetailsPageState();
}

class _StationDetailsPageState extends State<StationDetailsPage> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
  }

  @override
  Widget build(BuildContext context) {
    final hasThaiName =
        widget.stop.thaiName != null && widget.stop.thaiName!.trim().isNotEmpty;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600 && size.width > size.height;

    final content = StationDetailsContent(
      stop: widget.stop,
      lineColor: widget.lineColor,
      lineName: widget.lineName,
      onSelectAsStart: () {
        widget.onSelectAsStart();
        Navigator.pop(context);
      },
      onSelectAsDestination: () {
        widget.onSelectAsDestination();
        Navigator.pop(context);
      },
      transferStops: widget.transferStops,
      lineNameResolver: widget.lineNameResolver,
      lineColorResolver: widget.lineColorResolver,
      lineColorByName: widget.lineColorByName,
      routeIconByName: widget.routeIconByName,
      onTransferStationSelected: (tStop) {
        if (widget.onTransferStationSelected != null) {
          widget.onTransferStationSelected!(tStop);
        }
      },
      isBottomSheet: false,
      isFavorite: _isFavorite,
      onToggleFavorite: () {
        setState(() {
          _isFavorite = !_isFavorite;
        });
        if (widget.onToggleFavorite != null) {
          widget.onToggleFavorite!();
        }
      },
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
                      title: Text(hasThaiName ? widget.stop.thaiName! : widget.stop.name),
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
        title: Text(hasThaiName ? widget.stop.thaiName! : widget.stop.name),
        centerTitle: true,
      ),
      body: content,
    );
  }
}
