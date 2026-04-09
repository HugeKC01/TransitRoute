import os

with open("lib/pages/station_details_page.dart", "r") as f:
    text = f.read()

text = text.replace("class StationDetailsPage extends StatelessWidget {", "class StationDetailsPage extends StatefulWidget {")
text = text.replace("  final void Function(gtfs.Stop stop)? onTransferStationSelected;\n", "  final void Function(gtfs.Stop stop)? onTransferStationSelected;\n\n  @override\n  State<StationDetailsPage> createState() => _StationDetailsPageState();\n}\n\nclass _StationDetailsPageState extends State<StationDetailsPage> {\n  late bool _isFavorite;\n\n  @override\n  void initState() {\n    super.initState();\n    _isFavorite = widget.isFavorite;\n  }\n")
text = text.replace("stop.thaiName != null && stop.thaiName!.trim().isNotEmpty;", "widget.stop.thaiName != null && widget.stop.thaiName!.trim().isNotEmpty;")
text = text.replace("      stop: stop,", "      stop: widget.stop,")
text = text.replace("      lineColor: lineColor,", "      lineColor: widget.lineColor,")
text = text.replace("      lineName: lineName,", "      lineName: widget.lineName,")
text = text.replace("      onSelectAsStart: () {\n        onSelectAsStart();\n", "      onSelectAsStart: () {\n        widget.onSelectAsStart();\n")
text = text.replace("      onSelectAsDestination: () {\n        onSelectAsDestination();\n", "      onSelectAsDestination: () {\n        widget.onSelectAsDestination();\n")
text = text.replace("      transferStops: transferStops,", "      transferStops: widget.transferStops,")
text = text.replace("      lineNameResolver: lineNameResolver,", "      lineNameResolver: widget.lineNameResolver,")
text = text.replace("      lineColorResolver: lineColorResolver,", "      lineColorResolver: widget.lineColorResolver,")
text = text.replace("      lineColorByName: lineColorByName,", "      lineColorByName: widget.lineColorByName,")
text = text.replace("      routeIconByName: routeIconByName,", "      routeIconByName: widget.routeIconByName,")
text = text.replace("      isFavorite: isFavorite,", "      isFavorite: _isFavorite,")
text = text.replace("      onToggleFavorite: onToggleFavorite,", "      onToggleFavorite: () {\n        setState(() {\n          _isFavorite = !_isFavorite;\n        });\n        if (widget.onToggleFavorite != null) {\n          widget.onToggleFavorite!();\n        }\n      },")
text = text.replace("      onTransferStationSelected: (tStop) {\n        if (onTransferStationSelected != null) {\n          onTransferStationSelected!(tStop);\n        }", "      onTransferStationSelected: (tStop) {\n        if (widget.onTransferStationSelected != null) {\n          widget.onTransferStationSelected!(tStop);\n        }")
text = text.replace("      title: Text(stop.name),", "      title: Text(widget.stop.name),")
text = text.replace("  Widget build(BuildContext context) {", "  @override\n  Widget build(BuildContext context) {")
text = text.replace("  final gtfs.Stop stop;", "  // final gtfs.Stop stop;") # we already replaced class sig, wait, the class fields should be widget. fields.

with open("lib/pages/station_details_page.dart", "w") as f:
    f.write(text)
