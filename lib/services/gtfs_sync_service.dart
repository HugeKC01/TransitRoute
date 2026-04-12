import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive_io.dart';

class GtfsSyncService {
  static const _versionKey = 'gtfs_local_version';
  static const _gtfsJsonFilename = 'gtfs_version.json';
  static const _gtfsZipFilename = 'gtfs_data_latest.zip';
  static const _gtfsLocalDir = 'gtfs_data';

  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isInit = false;
  late final String _localGtfsPath;

  /// Call this when the app starts
  Future<void> initAndSync() async {
    final docDir = await getApplicationDocumentsDirectory();
    _localGtfsPath = '${docDir.path}/$_gtfsLocalDir';
    _isInit = true;

    try {
      await _checkForUpdates();
    } catch (e) {
      debugPrint('Failed to sync GTFS data: $e');
    }
  }

  Future<void> _checkForUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final localVersion = prefs.getInt(_versionKey) ?? 0;

    debugPrint('Current local GTFS version: $localVersion');

    // Fetch latest version from Firebase Storage
    final versionRef = _storage.ref().child(_gtfsJsonFilename);
    final versionData = await versionRef.getData();

    if (versionData == null) {
      debugPrint('No GTFS version data found in Firebase.');
      return;
    }

    final jsonStr = utf8.decode(versionData);
    final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
    final remoteVersion = jsonMap['version'] as int? ?? 0;

    debugPrint('Latest remote GTFS version: $remoteVersion');

    if (remoteVersion > localVersion) {
      debugPrint('New GTFS version detected. Downloading...');
      await _downloadAndExtractGtfs();
      await prefs.setInt(_versionKey, remoteVersion);
      debugPrint('Successfully updated GTFS data to version $remoteVersion');
    } else {
      debugPrint('GTFS data is up to date.');
    }
  }

  /// Get the current local GTFS version number
  Future<int> getLocalVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_versionKey) ?? 0;
  }

  /// Manually trigger an update check and return a status message
  Future<String> manualUpdateCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getInt(_versionKey) ?? 0;

      final versionRef = _storage.ref().child(_gtfsJsonFilename);
      final versionData = await versionRef.getData();

      if (versionData == null) {
        return 'No remote version found.';
      }

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
    final zipRef = _storage.ref().child(_gtfsZipFilename);

    // Create temporary download path
    final tempDir = await getTemporaryDirectory();
    final tempZipFile = File('${tempDir.path}/$_gtfsZipFilename');

    // Download the file
    await zipRef.writeToFile(tempZipFile);

    // Create or clear the local target directory
    final targetDir = Directory(_localGtfsPath);
    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }
    await targetDir.create(recursive: true);

    // Extract the zip to the documents directory using memory efficient extract
    await extractFileToDisk(tempZipFile.path, targetDir.path);

    // Clean up
    await tempZipFile.delete();
  }

  /// Helper to get file content (checks downloaded files first, falls back to assets)
  Future<String> getGtfsFile(String filename) async {
    // Strip asset folder prefix if passed in accidentally
    if (filename.startsWith('assets/gtfs_data/')) {
      filename = filename.replaceFirst('assets/gtfs_data/', '');
    }

    if (!_isInit) {
      final docDir = await getApplicationDocumentsDirectory();
      _localGtfsPath = '${docDir.path}/$_gtfsLocalDir';
    }

    final localFile = File('$_localGtfsPath/$filename');
    if (await localFile.exists()) {
      // Use locally downloaded file
      return await localFile.readAsString();
    } else {
      // Fallback to bundled asset
      return await rootBundle.loadString('assets/gtfs_data/$filename');
    }
  }
}

// Global instance for convenience
final gtfsSyncService = GtfsSyncService();
