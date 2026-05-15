import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:route/services/gtfs_sync_service.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  Database? _db;
  bool get isReady => _db != null;
  Database get db => _db!;

  final ValueNotifier<double> importProgress = ValueNotifier(0.0);
  final ValueNotifier<String> importStatus = ValueNotifier('');

  Future<void> init() async {
    if (kIsWeb) {
      debugPrint('LocalDB not supported on Web. Falling back to memory parsing.');
      return;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gtfs_local.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // Trips
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trips (
        trip_id TEXT PRIMARY KEY,
        route_id TEXT,
        service_id TEXT,
        trip_headsign TEXT,
        direction_id TEXT,
        shape_id TEXT,
        shape_color TEXT
      )
    ''');

    // Shapes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shapes (
        shape_id TEXT,
        shape_pt_lat REAL,
        shape_pt_lon REAL,
        shape_pt_sequence INTEGER,
        shape_pt_name TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_shape_id ON shapes (shape_id)');

    // Shapes Source
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shapes_source (
        shape_id TEXT,
        shape_pt_lat REAL,
        shape_pt_lon REAL,
        shape_pt_sequence INTEGER,
        shape_pt_name TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_shapes_source_id ON shapes_source (shape_id)');

    // Stops
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stops (
        stop_id TEXT PRIMARY KEY,
        stop_name TEXT,
        stop_lat REAL,
        stop_lon REAL,
        location_type INTEGER
      )
    ''');

    // Stop Times
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stop_times (
        trip_id TEXT,
        arrival_time TEXT,
        departure_time TEXT,
        stop_id TEXT,
        stop_sequence INTEGER
      )
    ''');
    await db.execute('CREATE INDEX idx_stop_times_trip ON stop_times (trip_id)');
    await db.execute('CREATE INDEX idx_stop_times_stop ON stop_times (stop_id)');

    // Frequencies
    await db.execute('''
      CREATE TABLE IF NOT EXISTS frequencies (
        trip_id TEXT,
        start_time TEXT,
        end_time TEXT,
        headway_secs INTEGER
      )
    ''');
    await db.execute('CREATE INDEX idx_frequencies_trip ON frequencies (trip_id)');

    // Fixed Timetables
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fixed_timetables (
        trip_id TEXT,
        stop_id TEXT,
        departure_times TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_fixed_timetables_stop ON fixed_timetables (stop_id)');
  }

  /// Called after a new zip is extracted, or when the db is empty.
  Future<void> importDataIfRequired(int currentVersion) async {
    if (kIsWeb || _db == null) return;
    
    // Check if we already have data
    final tripsCount = Sqflite.firstIntValue(await _db!.rawQuery('SELECT COUNT(*) FROM trips')) ?? 0;
    if (tripsCount > 0) {
      debugPrint('GTFS DB already populated.');
      return; // Add version check logic later
    }

    importStatus.value = 'Importing GTFS to Local DB...';
    debugPrint(importStatus.value);

    // Import Trips
    Map<String, dynamic> tripMapper(List<String> row, List<String> header) {
      if (header.isEmpty && row.isNotEmpty && row[0].contains('BRT')) {
        return {
          'trip_id': row[0].trim(),
          'route_id': 'BRT',
          'service_id': '',
          'trip_headsign': '',
          'direction_id': '',
          'shape_id': '',
          'shape_color': '',
        };
      }
      return {
        'trip_id': _getVal(row, header, 'trip_id'),
        'route_id': _getVal(row, header, 'route_id'),
        'service_id': _getVal(row, header, 'service_id'),
        'trip_headsign': _getVal(row, header, 'trip_headsign'),
        'direction_id': _getVal(row, header, 'direction_id'),
        'shape_id': _getVal(row, header, 'shape_id'),
        'shape_color': _getVal(row, header, 'shape_color') ?? _getVal(row, header, 'shape-color'),
      };
    }
    await _importFile('trips.txt', 'trips', tripMapper);
    await _importFile('ferry_trips.txt', 'trips', tripMapper);
    await _importFile('brt_trips.txt', 'trips', tripMapper);

    // Import Shapes
    await _importFile('shapes.txt', 'shapes', (row, header) {
      return {
        'shape_id': _getVal(row, header, 'shape_id'),
        'shape_pt_lat': double.tryParse(_getVal(row, header, 'shape_pt_lat') ?? ''),
        'shape_pt_lon': double.tryParse(_getVal(row, header, 'shape_pt_lon') ?? ''),
        'shape_pt_sequence': int.tryParse(_getVal(row, header, 'shape_pt_sequence') ?? '0'),
        'shape_pt_name': _getVal(row, header, 'shape_pt_name') ?? _getVal(row, header, 'shape_name'),
      };
    });

    // Import Shapes Source (huge, may take a while)
    await _importFile('shapes_source.txt', 'shapes_source', (row, header) {
      return {
        'shape_id': _getVal(row, header, 'shape_id'),
        'shape_pt_lat': double.tryParse(_getVal(row, header, 'shape_pt_lat') ?? ''),
        'shape_pt_lon': double.tryParse(_getVal(row, header, 'shape_pt_lon') ?? ''),
        'shape_pt_sequence': int.tryParse(_getVal(row, header, 'shape_pt_sequence') ?? '0'),
        'shape_pt_name': _getVal(row, header, 'shape_pt_name') ?? _getVal(row, header, 'shape_name'),
      };
    });

    // Import Frequencies
    await _importFile('frequencies.txt', 'frequencies', (row, header) {
      return {
        'trip_id': _getVal(row, header, 'trip_id'),
        'start_time': _getVal(row, header, 'start_time'),
        'end_time': _getVal(row, header, 'end_time'),
        'headway_secs': int.tryParse(_getVal(row, header, 'headway_secs') ?? '0'),
      };
    });

    // Import Fixed Timetables
    await _importFile('fixed_timetables.txt', 'fixed_timetables', (row, header) {
      return {
        'trip_id': _getVal(row, header, 'trip_id'),
        'stop_id': _getVal(row, header, 'stop_id'),
        'departure_times': _getVal(row, header, 'departure_times'),
      };
    });

    // Import Stop Times
    Map<String, dynamic> stopTimesMapper(List<String> row, List<String> header) {
      return {
        'trip_id': _getVal(row, header, 'trip_id'),
        'arrival_time': _getVal(row, header, 'arrival_time'),
        'departure_time': _getVal(row, header, 'departure_time'),
        'stop_id': _getVal(row, header, 'stop_id'),
        'stop_sequence': int.tryParse(_getVal(row, header, 'stop_sequence') ?? '0'),
      };
    }
    await _importFile('stop_times.txt', 'stop_times', stopTimesMapper);
    await _importFile('bus_stop_times.txt', 'stop_times', stopTimesMapper);
    await _importFile('ferry_stop_times.txt', 'stop_times', stopTimesMapper);

    // Import Stops
    Map<String, dynamic> stopMapper(List<String> row, List<String> header) {
      final nameTh = _getVal(row, header, 'stop_name_th');
      final nameEn = _getVal(row, header, 'stop_name');
      return {
        'stop_id': _getVal(row, header, 'stop_id'),
        'stop_name': (nameTh != null && nameTh.isNotEmpty) ? nameTh : nameEn,
        'stop_lat': double.tryParse(_getVal(row, header, 'stop_lat') ?? ''),
        'stop_lon': double.tryParse(_getVal(row, header, 'stop_lon') ?? ''),
        'location_type': int.tryParse(_getVal(row, header, 'location_type') ?? '0'),
      };
    }
    await _importFile('stops.txt', 'stops', stopMapper);
    await _importFile('bus_stop.txt', 'stops', stopMapper);
    await _importFile('ferry_stop.txt', 'stops', stopMapper);
    
    importStatus.value = 'Import Complete!';
    importProgress.value = 1.0;
  }

  String? _getVal(List<String> row, List<String> header, String colName) {
    final idx = header.indexOf(colName);
    if (idx >= 0 && idx < row.length) {
      final v = row[idx].trim();
      return v.isEmpty ? null : v;
    }
    return null;
  }

  Future<void> _importFile(String filename, String tableName, Map<String, dynamic> Function(List<String>, List<String>) mapper) async {
    try {
      final rawPath = filename.replaceFirst('assets/gtfs_data/', '');
      final localPath = gtfsSyncService.localGtfsPath;
      final localFile = localPath != null ? io.File('$localPath/$rawPath') : null;

      Stream<String> lineStream;
      if (localFile != null && await localFile.exists()) {
        lineStream = localFile.openRead().transform(utf8.decoder).transform(const LineSplitter());
      } else {
        final byteData = await rootBundle.load('assets/gtfs_data/$rawPath');
        final bytes = byteData.buffer.asUint8List();
        
        Stream<List<int>> chunkedStream(Uint8List data, int chunkSize) async* {
          for (int i = 0; i < data.length; i += chunkSize) {
            int end = i + chunkSize;
            if (end > data.length) end = data.length;
            yield data.sublist(i, end);
          }
        }
        
        lineStream = chunkedStream(bytes, 64 * 1024)
            .transform(utf8.decoder)
            .transform(const LineSplitter());
      }

      var batch = _db!.batch();
      int i = 0;
      List<String>? header;

      await for (final line in lineStream) {
        final trimmed = line.trimRight();
        if (trimmed.isEmpty) continue;

        if (header == null) {
          header = _splitCsvLine(trimmed).map((s) => s.trim().toLowerCase()).toList();
          continue;
        }

        final row = _splitCsvLine(trimmed);
        final data = mapper(row, header);
        batch.insert(tableName, data, conflictAlgorithm: ConflictAlgorithm.replace);
        
        i++;
        if (i % 2000 == 0) {
          await batch.commit(noResult: true);
          batch = _db!.batch(); // Reset batch to prevent OOM
          importProgress.value = (i / 100000); // Approximate progress indicator
          // Yield to the Flutter UI event loop to prevent skipped frames
          await Future.delayed(const Duration(milliseconds: 5));
        }
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('Failed to import $filename: $e');
    }
  }

  List<String> _splitCsvLine(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    out.add(buf.toString());
    return out;
  }
}

final localDbService = LocalDbService();
