import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_update.dart';
import 'service_locator.dart';

class UpdateService {
  // Using GitHub Pages static files, no request limit
  // static const String _versionJsonUrl = 'https://shnulaa.github.io/FlutterIPTV/version.json';
  // static const String _githubReleasesUrl = 'https://github.com/shnulaa/FlutterIPTV/releases';

  static const String _versionJsonUrl = 'https://hk.gh-proxy.org/https://raw.githubusercontent.com/shnulaa/FlutterIPTV/main/docs/version.json';
  static const String _githubReleasesUrl = 'https://github.com/shnulaa/FlutterIPTV/releases';

  // Interval for checking updates (hours)
  static const int _checkUpdateInterval = 24;
  static const String _lastUpdateCheckKey = 'last_update_check';

  /// Check if update is available
  Future<AppUpdate?> checkForUpdates({bool forceCheck = false}) async {
    try {
      ServiceLocator.log.d('UPDATE: Starting update check...');

      // Check if update check is needed (unless forced)
      if (!forceCheck) {
        final lastCheck = await _getLastUpdateCheckTime();
        final now = DateTime.now();
        if (lastCheck != null && now.difference(lastCheck).inHours < _checkUpdateInterval) {
          ServiceLocator.log.d('UPDATE: Less than 24 hours since last check, skipping');
          return null;
        }
      }

      // Get current app version
      final currentVersion = await getCurrentVersion();
      ServiceLocator.log.d('UPDATE: Current version: $currentVersion');

      // Get latest release info
      final latestRelease = await _fetchLatestRelease();
      if (latestRelease == null) {
        ServiceLocator.log.d('UPDATE: Unable to fetch latest release info');
        return null;
      }

      ServiceLocator.log.d('UPDATE: Latest release version: ${latestRelease.version}');

      // Compare version numbers
      if (_isNewerVersion(latestRelease.version, currentVersion)) {
        ServiceLocator.log.d('UPDATE: New version available!');
        await _saveLastUpdateCheckTime();
        return latestRelease;
      } else {
        ServiceLocator.log.d('UPDATE: Already latest version');
        await _saveLastUpdateCheckTime();
        return null;
      }
    } catch (e) {
      ServiceLocator.log.d('UPDATE: Error checking for updates: $e');
      return null;
    }
  }

  /// Get current app version
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      ServiceLocator.log.d('UPDATE: Failed to get current version: $e');
      return '0.0.0';
    }
  }

  /// Fetch latest release info from GitHub Pages
  Future<AppUpdate?> _fetchLatestRelease() async {
    try {
      final response = await http.get(
        Uri.parse(_versionJsonUrl),
        headers: {
          'User-Agent': 'FlutterIPTV-App',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        // Use asynchronous method to get correct download URL
        return await AppUpdate.fromVersionJsonAsync(data);
      } else {
        ServiceLocator.log.d('UPDATE: Failed to fetch version info, status code: ${response.statusCode}');
      }
    } catch (e) {
      ServiceLocator.log.d('UPDATE: Error fetching release info: $e');
    }
    return null;
  }

  /// Compare version numbers, determine if it is a new version
  bool _isNewerVersion(String newVersion, String currentVersion) {
    try {
      final newVer = Version.parse(newVersion);
      final currentVer = Version.parse(currentVersion);
      return newVer > currentVer;
    } catch (e) {
      ServiceLocator.log.d('UPDATE: Version comparison failed: $e');
      return false;
    }
  }

  /// Open download page
  Future<bool> openDownloadPage() async {
    try {
      final uri = Uri.parse(_githubReleasesUrl);
      ServiceLocator.log.d('UPDATE: Opening download page: $_githubReleasesUrl');
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ServiceLocator.log.d('UPDATE: Failed to open download page: $e');
      return false;
    }
  }

  /// Download update file
  Future<File?> downloadUpdate(AppUpdate update, {Function(double)? onProgress}) async {
    try {
      final downloadUrl = update.downloadUrl;
      if (downloadUrl.isEmpty) {
        ServiceLocator.log.d('UPDATE: Download URL is empty');
        return null;
      }

      ServiceLocator.log.d('UPDATE: Starting download: $downloadUrl');

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      
      // Extract filename from URL
      String fileName;
      final uri = Uri.parse(downloadUrl);
      final urlFileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (urlFileName.isNotEmpty) {
        fileName = urlFileName;
      } else if (Platform.isWindows) {
        fileName = 'flutter_iptv_update.exe';
      } else {
        fileName = 'flutter_iptv_update.apk';
      }
      
      final file = File('${tempDir.path}/$fileName');
      ServiceLocator.log.d('UPDATE: Saving to: ${file.path}');

      // Downloading file
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'FlutterIPTV-App';
      
      final response = await http.Client().send(request);
      
      if (response.statusCode != 200) {
        ServiceLocator.log.d('UPDATE: Download failed, status code: ${response.statusCode}');
        return null;
      }

      final contentLength = response.contentLength ?? 0;
      ServiceLocator.log.d('UPDATE: File size: $contentLength bytes');
      int receivedBytes = 0;
      
      final sink = file.openWrite();
      
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          onProgress(receivedBytes / contentLength);
        }
      }
      
      await sink.close();
      
      ServiceLocator.log.d('UPDATE: Download complete: ${file.path}, size: $receivedBytes bytes');
      return file;
    } catch (e, stack) {
      ServiceLocator.log.d('UPDATE: Error downloading update: $e');
      ServiceLocator.log.d('UPDATE: Stack: $stack');
      return null;
    }
  }

  /// Get last update check time
  Future<DateTime?> _getLastUpdateCheckTime() async {
    try {
      final prefs = ServiceLocator.prefs;
      final timestamp = prefs.getInt(_lastUpdateCheckKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      ServiceLocator.log.d('UPDATE: Failed to get last check time: $e');
      return null;
    }
  }

  /// Save last update check time
  Future<void> _saveLastUpdateCheckTime() async {
    try {
      final prefs = ServiceLocator.prefs;
      await prefs.setInt(_lastUpdateCheckKey, DateTime.now().millisecondsSinceEpoch);
      ServiceLocator.log.d('UPDATE: Saved check time: ${DateTime.now()}');
    } catch (e) {
      ServiceLocator.log.d('UPDATE: Failed to save check time: $e');
    }
  }
}
