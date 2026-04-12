import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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


    final mapWidget = FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(widget.stop.lat, widget.stop.lon),
        initialZoom: 16.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.transit_route',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(widget.stop.lat, widget.stop.lon),
              width: 24,
              height: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.lineColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isFavorite
                    ? const Center(
                        child: Icon(Icons.favorite, size: 14, color: Colors.white),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );

    if (isWide) {
      return Scaffold(
        appBar: AppBar(
          title: Text(hasThaiName ? widget.stop.thaiName! : widget.stop.name),
          centerTitle: true,
        ),
        body: Row(
          children: [
            Expanded(
              flex: 4,
              child: content,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              flex: 6,
              child: mapWidget,
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
      body: Column(
        children: [
          SizedBox(
            height: 250,
            child: mapWidget,
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}
