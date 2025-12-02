import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:route/services/csv_utils.dart';
import 'package:route/services/gtfs_models.dart' as gtfs;

class RouteAssetLoader {
  const RouteAssetLoader._();

  static Future<List<gtfs.Route>> loadRoutes(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return [];
      final header = parseCsvLine(lines.first).map((s) => s.trim()).toList();
      final idxRouteId = header.indexOf('route_id');
      final idxAgencyId = header.indexOf('agency_id');
      final idxShortName = header.indexOf('route_short_name');
      final idxLongName = header.indexOf('route_long_name');
      final idxType = header.indexOf('route_type');
      final idxColor = header.indexOf('route_color');
      final idxTextColor = header.indexOf('route_text_color');
      final idxLinePrefixes = header.indexOf('line_prefixes');
      final routes = <gtfs.Route>[];
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = parseCsvLine(line);
        if ([idxRouteId, idxAgencyId, idxShortName, idxLongName, idxType]
            .any((idx) => idx < 0 || idx >= row.length)) {
          continue;
        }
        final linePrefixes = (idxLinePrefixes >= 0 && row.length > idxLinePrefixes)
            ? row
                .sublist(idxLinePrefixes)
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList()
            : <String>[];
        routes.add(
          gtfs.Route(
            routeId: row[idxRouteId].trim(),
            agencyId: row[idxAgencyId].trim(),
            shortName: row[idxShortName].trim(),
            longName: row[idxLongName].trim(),
            type: row[idxType].trim(),
            color:
                idxColor >= 0 && idxColor < row.length ? _cleanHex(row[idxColor]) : null,
            textColor: idxTextColor >= 0 && idxTextColor < row.length
                ? _cleanHex(row[idxTextColor])
                : null,
            linePrefixes: linePrefixes,
          ),
        );
      }
      return routes;
    } catch (_) {
      return [];
    }
  }

  static Future<List<gtfs.Stop>> loadStops(
    String assetPath, {
    Map<String, String>? thaiNames,
  }) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return [];
      final header = parseCsvLine(lines.first).map((s) => s.trim()).toList();
      int idxStopId = header.indexOf('stop_id');
      if (idxStopId < 0) idxStopId = 0;
      int idxName = header.indexOf('stop_name');
      if (idxName < 0) idxName = 1;
      final idxThai = header.indexOf('stop_name_th');
      int idxLat = header.indexOf('stop_lat');
      if (idxLat < 0) idxLat = 2;
      int idxLon = header.indexOf('stop_lon');
      if (idxLon < 0) idxLon = 3;
      final idxCode = header.indexOf('stop_code');
      final idxDesc = header.indexOf('stop_desc');
      final idxZone = header.indexOf('zone_id');
      final stops = <gtfs.Stop>[];
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = parseCsvLine(line);
        if (row.length <= idxStopId || row.length <= idxName) continue;
        if (row.length <= idxLat || row.length <= idxLon) continue;
        final stopId = row[idxStopId].trim();
        if (stopId.isEmpty) continue;
        final name = row[idxName].trim();
        final lat = double.tryParse(row[idxLat].trim());
        final lon = double.tryParse(row[idxLon].trim());
        if (lat == null || lon == null) continue;
        final thaiFromFile = idxThai >= 0 && row.length > idxThai
            ? row[idxThai].trim()
            : '';
        final override = thaiNames?[stopId]?.trim();
        final thai = (override != null && override.isNotEmpty)
            ? override
            : (thaiFromFile.isNotEmpty ? thaiFromFile : null);
        stops.add(
          gtfs.Stop(
            stopId: stopId,
            name: name,
            thaiName: thai,
            lat: lat,
            lon: lon,
            code: (idxCode >= 0 && row.length > idxCode)
                ? row[idxCode].trim()
                : null,
            desc: (idxDesc >= 0 && row.length > idxDesc)
                ? row[idxDesc].trim()
                : null,
            zoneId: (idxZone >= 0 && row.length > idxZone)
                ? row[idxZone].trim()
                : null,
          ),
        );
      }
      return stops;
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, String>> loadFareTypeMap(String assetPath) async {
    final result = <String, String>{};
    try {
      final content = await rootBundle.loadString(assetPath);
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return result;
      final header = parseCsvLine(lines.first).map((s) => s.toLowerCase()).toList();
      int idxFareId = header.indexOf('fareid');
      if (idxFareId < 0) idxFareId = 0;
      int idxStatus = header.indexOf('agencystatus');
      if (idxStatus < 0) idxStatus = header.indexOf('agsscystatus');
      if (idxStatus < 0) idxStatus = 1;
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = parseCsvLine(line);
        if (row.length <= idxFareId) continue;
        final id = row[idxFareId].trim();
        final status = row.length > idxStatus ? row[idxStatus].trim().toLowerCase() : '';
        if (id.isNotEmpty && (status == 'm' || status == 's')) {
          result[id] = status;
        }
      }
    } catch (_) {}
    return result;
  }

  static Future<Map<String, int>> loadFareDataMap(String assetPath) async {
    final result = <String, int>{};
    try {
      final content = await rootBundle.loadString(assetPath);
      final lines = const LineSplitter().convert(content);
      if (lines.length <= 1) return result;
      final header = parseCsvLine(lines.first).map((s) => s.toLowerCase()).toList();
      int idxId = header.indexOf('faredataid');
      if (idxId < 0) idxId = header.indexOf('fareid');
      if (idxId < 0) idxId = 0;
      int idxPrice = header.indexOf('price');
      if (idxPrice < 0) idxPrice = 1;
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final row = parseCsvLine(line);
        if (row.length <= idxId) continue;
        final id = row[idxId].trim();
        final price = row.length > idxPrice ? int.tryParse(row[idxPrice].trim()) ?? 0 : 0;
        if (id.isNotEmpty) {
          result[id] = price;
        }
      }
    } catch (_) {}
    return result;
  }

  static String? _cleanHex(String? hex) {
    if (hex == null) return null;
    final value = hex.trim().replaceAll('\r', '').replaceAll('#', '');
    if (value.isEmpty) return null;
    return value.toUpperCase();
  }
}
