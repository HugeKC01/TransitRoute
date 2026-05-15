import 'dart:io' as io; // Prefixing to avoid web conflicts
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Gives us kIsWeb
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive_io.dart';
import 'package:route/services/local_db_service.dart';


void _extractArchiveIsolate(Map<String, String> args) {
  extractFileToDisk(args['zipPath']!, args['targetPath']!);
}

class GtfsSyncService {
  static const _versionKey = 'gtfs_local_version';
  static const _gtfsJsonFilename = 'gtfs_version.json';
  static const _gtfsZipFilename = 'gtfs_data_latest.zip';
  static const _gtfsLocalDir = 'gtfs_data';

  bool _isInit = false;
  String? _localGtfsPath;
  String? get localGtfsPath => _localGtfsPath;

  final ValueNotifier<List<String>> consoleLogs = ValueNotifier([]);

  void _log(String message) {
    debugPrint(message);
    consoleLogs.value = List.from(consoleLogs.value)..add(message);
  }

  /// Call this when the app starts
  Future<void> initAndSync() async {
    _log('Initializing GTFS sync service...');
    
    // CRITICAL FIX: Bypass all local file system logic if running on the web
    if (kIsWeb) {
      _log('Running on Web. Local caching disabled. Using bundled assets.');
      _isInit = true;
      return; 
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      _localGtfsPath = '${docDir.path}/$_gtfsLocalDir';
      _isInit = true;
      
      await _checkForUpdates();
      
      // Initialize local DB and import data if we are not on web
      if (!kIsWeb) {
        await localDbService.init();
        final currentVersion = await getLocalVersion();
        await localDbService.importDataIfRequired(currentVersion);
      }
    } catch (e) {
      _log('Failed to sync GTFS data: $e');
    }
  }

  Future<void> _checkForUpdates() async {
    if (kIsWeb) return; // Safety check

    final prefs = await SharedPreferences.getInstance();
    final localVersion = prefs.getInt(_versionKey) ?? 0;

    _log('Current local GTFS version: $localVersion');

    _log('Fetching remote GTFS version...');
    final versionRef = FirebaseStorage.instance.ref().child(_gtfsJsonFilename);
    final versionData = await versionRef.getData();

    if (versionData == null) {
      _log('No GTFS version data found in Firebase.');
      return;
    }

    final jsonStr = utf8.decode(versionData);
    final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
    final remoteVersion = jsonMap['version'] as int? ?? 0;

    _log('Latest remote GTFS version: $remoteVersion');

    if (remoteVersion > localVersion) {
      _log('New GTFS version detected. Downloading...');
      await _downloadAndExtractGtfs();
      await prefs.setInt(_versionKey, remoteVersion);
      _log('Successfully updated GTFS data to version $remoteVersion');
      
      // Re-import the newly downloaded data
      if (!kIsWeb) {
        await localDbService.init();
        await localDbService.importDataIfRequired(remoteVersion);
      }
    } else {
      _log('GTFS data is up to date.');
    }
  }

  Future<int> getLocalVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_versionKey) ?? 0;
  }

  Future<String> manualUpdateCheck() async {
    if (kIsWeb) return 'Web version automatically uses the latest deployed data.';

    try {
      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getInt(_versionKey) ?? 0;

      final versionRef = FirebaseStorage.instance.ref().child(_gtfsJsonFilename);
      final versionData = await versionRef.getData();

      if (versionData == null) return 'No remote version found.';

      final jsonStr = utf8.decode(versionData);
      final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
      final remoteVersion = jsonMap['version'] as int? ?? 0;

      if (remoteVersion > localVersion) {
        await _downloadAndExtractGtfs();
        await prefs.setInt(_versionKey, remoteVersion);
        return 'Successfully updated to version $remoteVersion!';
      } else {
        return 'Data is already up to date (Version $localVersion).';
      }
    } catch (e) {
      return 'Failed to check for updates.';
    }
  }

  Future<void> _downloadAndExtractGtfs() async {
    final zipRef = FirebaseStorage.instance.ref().child(_gtfsZipFilename);

    final tempDir = await getTemporaryDirectory();
    final tempZipFile = io.File('${tempDir.path}/$_gtfsZipFilename');

    await zipRef.writeToFile(tempZipFile);

    final targetDir = io.Directory(_localGtfsPath!);
    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }
    await targetDir.create(recursive: true);

    await compute(_extractArchiveIsolate, {
      'zipPath': tempZipFile.path,
      'targetPath': targetDir.path,
    });
    
    await tempZipFile.delete();
  }

  /// Helper to get file content (checks downloaded files first, falls back to assets)
  Future<String> getGtfsFile(String filename) async {
    if (filename.startsWith('assets/gtfs_data/')) {
      filename = filename.replaceFirst('assets/gtfs_data/', '');
    }

    // Always use rootBundle for web
    if (kIsWeb) {
      return await rootBundle.loadString('assets/gtfs_data/$filename');
    }

    if (!_isInit) {
      final docDir = await getApplicationDocumentsDirectory();
      _localGtfsPath = '${docDir.path}/$_gtfsLocalDir';
    }

    final localFile = io.File('$_localGtfsPath/$filename');
    if (await localFile.exists()) {
      return await localFile.readAsString();
    } else {
      return await rootBundle.loadString('assets/gtfs_data/$filename');
    }
  }
}

final gtfsSyncService = GtfsSyncService();