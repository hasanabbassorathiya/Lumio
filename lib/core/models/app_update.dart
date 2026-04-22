import 'dart:io';
import 'package:flutter/services.dart';
import '../platform/platform_detector.dart';
import '../services/service_locator.dart';

class AppUpdate {
  final String version;
  final int build;
  final String releaseNotes;
  final String downloadUrl;
  final Map<String, dynamic> assets;
  final DateTime releaseDate;
  final String minVersion;

  AppUpdate({
    required this.version,
    required this.build,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.assets,
    required this.releaseDate,
    this.minVersion = '1.0.0',
  });

  // Cache CPU architecture
  static String? _cachedCpuAbi;
  static const _platformChannel = MethodChannel('com.flutteriptv/platform');

  /// Parse from GitHub Pages version.json
  static Future<AppUpdate> fromVersionJsonAsync(Map<String, dynamic> json) async {
    final assets = json['assets'] as Map<String, dynamic>? ?? {};
    final changelog = json['changelog'] as Map<String, dynamic>? ?? {};
    
    // Select changelog based on current language, default to English
    final locale = Platform.localeName.startsWith('en') ? 'en' : 'en';
    final releaseNotes = changelog[locale] ?? changelog['en'] ?? changelog['zh'] ?? '';
    
    // Select download URL based on platform and architecture
    final downloadUrl = await _getDownloadUrl(assets);

    return AppUpdate(
      version: json['version'] ?? '0.0.0',
      build: json['build'] ?? 0,
      releaseNotes: releaseNotes,
      downloadUrl: downloadUrl,
      assets: assets,
      releaseDate: DateTime.tryParse(json['releaseDate'] ?? '') ?? DateTime.now(),
      minVersion: json['minVersion'] ?? '1.0.0',
    );
  }

  /// Parse from GitHub Pages version.json (Synchronous version, uses cached architecture)
  factory AppUpdate.fromVersionJson(Map<String, dynamic> json) {
    final assets = json['assets'] as Map<String, dynamic>? ?? {};
    final changelog = json['changelog'] as Map<String, dynamic>? ?? {};
    
    // Select changelog based on current language, default to English
    final locale = Platform.localeName.startsWith('en') ? 'en' : 'en';
    final releaseNotes = changelog[locale] ?? changelog['en'] ?? changelog['zh'] ?? '';
    
    // Select download URL based on platform and architecture（同步版本）
    final downloadUrl = _getDownloadUrlSync(assets);

    return AppUpdate(
      version: json['version'] ?? '0.0.0',
      build: json['build'] ?? 0,
      releaseNotes: releaseNotes,
      downloadUrl: downloadUrl,
      assets: assets,
      releaseDate: DateTime.tryParse(json['releaseDate'] ?? '') ?? DateTime.now(),
      minVersion: json['minVersion'] ?? '1.0.0',
    );
  }

  /// Get Android CPU architecture (asynchronous)
  static Future<String> _getAndroidArch() async {
    if (_cachedCpuAbi != null) return _cachedCpuAbi!;
    
    try {
      final abi = await _platformChannel.invokeMethod<String>('getCpuAbi');
      _cachedCpuAbi = abi ?? 'armeabi-v7a';
      ServiceLocator.log.d('UPDATE: Obtained CPU architecture: $_cachedCpuAbi');
    } catch (e) {
      ServiceLocator.log.d('UPDATE: Failed to get CPU architecture: $e, using default');
      _cachedCpuAbi = 'armeabi-v7a';
    }
    return _cachedCpuAbi!;
  }

  /// Get download URL based on platform and architecture (asynchronous)
  static Future<String> _getDownloadUrl(Map<String, dynamic> assets) async {
    if (Platform.isWindows) {
      return assets['windows'] ?? '';
    }
    
    if (Platform.isAndroid) {
      final arch = await _getAndroidArch();
      ServiceLocator.log.d('UPDATE: Android architecture: $arch, isTV: ${PlatformDetector.isTV}');
      
      // Select corresponding package based on whether it is a TV
      final androidAssets = PlatformDetector.isTV 
          ? assets['android_tv'] as Map<String, dynamic>?
          : assets['android_mobile'] as Map<String, dynamic>?;
      
      if (androidAssets != null) {
        // Prefer package for corresponding architecture, otherwise use universal
        return androidAssets[arch] ?? androidAssets['universal'] ?? '';
      }
      
      // Compatible with old formats
      return assets['android'] ?? '';
    }
    
    return '';
  }

  /// Get download URL based on platform and architecture (synchronous, using cache)
  static String _getDownloadUrlSync(Map<String, dynamic> assets) {
    if (Platform.isWindows) {
      return assets['windows'] ?? '';
    }
    
    if (Platform.isAndroid) {
      // Use cached architecture, default to armeabi-v7a if none (safer default)
      final arch = _cachedCpuAbi ?? 'armeabi-v7a';
      ServiceLocator.log.d('UPDATE: Android architecture (sync): $arch, isTV: ${PlatformDetector.isTV}');
      
      // Select corresponding package based on whether it is a TV
      final androidAssets = PlatformDetector.isTV 
          ? assets['android_tv'] as Map<String, dynamic>?
          : assets['android_mobile'] as Map<String, dynamic>?;
      
      if (androidAssets != null) {
        // Prefer package for corresponding architecture, otherwise use universal
        return androidAssets[arch] ?? androidAssets['universal'] ?? '';
      }
      
      // Compatible with old formats
      return assets['android'] ?? '';
    }
    
    return '';
  }

  /// Preload CPU architecture (called on app startup)
  static Future<void> preloadCpuArch() async {
    if (Platform.isAndroid) {
      await _getAndroidArch();
    }
  }

  /// Parse from GitHub API (keep compatibility)
  factory AppUpdate.fromJson(Map<String, dynamic> json) {
    // Extract version number from tagName, remove 'v' prefix
    String version = json['tag_name'] ?? '0.0.0';
    if (version.startsWith('v')) {
      version = version.substring(1);
    }

    // Get release notes
    String releaseNotes = json['body'] ?? '';

    // Get release date
    DateTime releaseDate = DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now();

    // Get download URL
    String downloadUrl = '';
    
    if (json['assets'] != null && json['assets'] is List) {
      for (final asset in json['assets']) {
        final name = asset['name']?.toString().toLowerCase() ?? '';
        final url = asset['browser_download_url'] ?? '';
        
        if (Platform.isAndroid && name.endsWith('.apk')) {
          // Prefer package for corresponding architecture
          if (PlatformDetector.isTV && name.contains('tv')) {
            if (name.contains('arm64')) {
              downloadUrl = url;
              break;
            } else if (downloadUrl.isEmpty) {
              downloadUrl = url;
            }
          } else if (!PlatformDetector.isTV && name.contains('mobile')) {
            if (name.contains('arm64')) {
              downloadUrl = url;
              break;
            } else if (downloadUrl.isEmpty) {
              downloadUrl = url;
            }
          }
        } else if (Platform.isWindows && (name.endsWith('.exe') || name.endsWith('.zip'))) {
          downloadUrl = url;
        }
      }
      
      // If no match, use the first APK/EXE
      if (downloadUrl.isEmpty && json['assets'].isNotEmpty) {
        for (final asset in json['assets']) {
          final name = asset['name']?.toString().toLowerCase() ?? '';
          final url = asset['browser_download_url'] ?? '';
          if ((Platform.isAndroid && name.endsWith('.apk')) ||
              (Platform.isWindows && (name.endsWith('.exe') || name.endsWith('.zip')))) {
            downloadUrl = url;
            break;
          }
        }
      }
    }

    return AppUpdate(
      version: version,
      build: 0,
      releaseNotes: releaseNotes,
      downloadUrl: downloadUrl,
      assets: {},
      releaseDate: releaseDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'build': build,
      'releaseNotes': releaseNotes,
      'downloadUrl': downloadUrl,
      'assets': assets,
      'releaseDate': releaseDate.toIso8601String(),
      'minVersion': minVersion,
    };
  }

  @override
  String toString() {
    return 'AppUpdate(version: $version, build: $build, downloadUrl: $downloadUrl, releaseDate: $releaseDate)';
  }
}
