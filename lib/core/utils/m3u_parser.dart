import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/channel.dart';
import '../services/service_locator.dart';

/// Result of M3U parsing containing channels and metadata
class M3UParseResult {
  final List<Channel> channels;
  final String? epgUrl;

  M3UParseResult({required this.channels, this.epgUrl});
}

/// Parser for M3U/M3U8 playlist files
class M3UParser {
  static const String _extM3U = '#EXTM3U';
  static const String _extInf = '#EXTINF:';
  static const String _extGrp = '#EXTGRP:';

  /// Parse result containing channels and metadata
  static M3UParseResult? _lastParseResult;

  /// Get the last parse result (for accessing EPG URL)
  static M3UParseResult? get lastParseResult => _lastParseResult;

  /// Parse M3U content from a URL
  static Future<List<Channel>> parseFromUrl(String url, int playlistId) async {
    try {
      ServiceLocator.log.d('DEBUG: Starting to fetch playlist content from URL: $url');

      // Use Dio for better handling of large files and redirects
      final dio = Dio();
      // Reduce timeout to 10 seconds as requested
      dio.options.connectTimeout = const Duration(seconds: 3);
      dio.options.receiveTimeout = const Duration(seconds: 3);

      final response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      ServiceLocator.log.d('DEBUG: Successfully fetched playlist content, status code: ${response.statusCode}');
      ServiceLocator.log
          .d('DEBUG: Content size: ${response.data.toString().length}  characters');

      // Use compute to parse in a separate isolate to avoid blocking the main thread
      final result = await compute(
          _parseInIsolate, _ParseParams(response.data.toString(), playlistId));

      // Save parse results (including EPG URL) to main thread static variable
      _lastParseResult = result;

      ServiceLocator.log.d(
          'DEBUG: URL parsing completed, parsed  ${result.channels.length}  channels, EPG URL: ${result.epgUrl ?? "(not configured)"}');

      return result.channels;
    } catch (e) {
      ServiceLocator.log.d('DEBUG: Error fetching playlist from URL: $e');

      final errorStr = e.toString().toLowerCase();
      // Use localization keys for common errors
      if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
        throw Exception('errorTimeout');
      } else if (errorStr.contains('socket') ||
          errorStr.contains('connection') ||
          errorStr.contains('handshake') ||
          errorStr.contains('lookup')) {
        throw Exception('errorNetwork');
      } else if (errorStr.contains('404')) {
        throw Exception('Playlist not found (404)');
      } else if (errorStr.contains('403')) {
        throw Exception('Access denied (403)');
      }

      throw e;
    }
  }

  /// Parse M3U content from a local file
  static Future<List<Channel>> parseFromFile(
      String filePath, int playlistId) async {
    try {
      ServiceLocator.log.d('DEBUG: Starting to read playlist from local file: $filePath');
      final file = File(filePath);

      if (!await file.exists()) {
        ServiceLocator.log.d('DEBUG: File does not exist: $filePath');
        throw Exception('File does not exist: $filePath');
      }

      final content = await file.readAsString();
      ServiceLocator.log.d('DEBUG: Successfully read local file，Content size: ${content.length}  characters');

      // Use compute to parse in a separate isolate to avoid blocking the main thread
      final result =
          await compute(_parseInIsolate, _ParseParams(content, playlistId));

      // Save parse results (including EPG URL) to main thread static variable
      _lastParseResult = result;

      ServiceLocator.log.d(
          'DEBUG: Local file parsing completed, parsed  ${result.channels.length}  channels, EPG URL: ${result.epgUrl ?? "(not configured)"}');

      return result.channels;
    } catch (e) {
      ServiceLocator.log.d('DEBUG: Error reading local playlist file: $e');
      throw Exception('Error reading playlist file: $e');
    }
  }

  /// Parsing function executed in Isolate (must be top-level or static)
  /// Returns full parse result, including channel list and EPG URL
  static M3UParseResult _parseInIsolate(_ParseParams params) {
    final channels = parse(params.content, params.playlistId);
    // parse method sets _lastParseResult, but in isolate
    // We need to return results to main thread
    // Note: _lastParseResult set in isolate, but we need to return it
    return _lastParseResult ?? M3UParseResult(channels: channels, epgUrl: null);
  }

  /// Parse M3U content string
  /// Merges channels with same tvg-name/epgId into single channel with multiple sources
  static List<Channel> parse(String content, int playlistId) {
    // Note: this method may run in isolate, cannot use ServiceLocator.log
    // But we can use print for debugging (outputs to console)
    print('M3U Parser: Starting parse, playlist ID: $playlistId');

    final List<Channel> rawChannels = [];
    final lines = LineSplitter.split(content).toList();
    String? epgUrl;

    print('M3U Parser: Total lines: ${lines.length}');

    if (lines.isEmpty) {
      print('M3U Parser: Content is empty, returning empty channel list');
      return rawChannels;
    }

    // Check for valid M3U header and extract EPG URL from first few lines
    bool foundHeader = false;
    for (int i = 0; i < lines.length && i < 10; i++) {
      final line = lines[i].trim();
      print(
          'M3U Parser: Checking line ${i + 1} line: ${line.length > 100 ? line.substring(0, 100) + "..." : line}');

      if (line.startsWith(_extM3U)) {
        foundHeader = true;
        print('M3U Parser: Found M3U header tag');

        // Extract x-tvg-url from this line
        final extractedUrl = _extractEpgUrl(line);
        print('M3U Parser: EPG URL extraction result: ${extractedUrl ?? "(not found)"}');

        if (extractedUrl != null) {
          epgUrl = extractedUrl;
          print('M3U Parser: Successfully extracted EPG URL: $epgUrl');
          break;
        }
      }
    }

    if (!foundHeader) {
      print('M3U Parser: Warning - missing M3U header tag, attempting to continue');
    } else {
      print('M3U Parser: M3U header verification completed, EPG URL: ${epgUrl ?? "(not configured)"}');
    }

    String? currentName;
    String? currentLogo;
    String? currentGroup;
    String? currentEpgId;
    int invalidUrlCount = 0;
    int validChannelCount = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) continue;

      if (line.startsWith(_extInf)) {
        // Parse EXTINF line
        final parsed = _parseExtInf(line);
        currentName = parsed['name'];
        currentLogo = parsed['logo'];
        currentGroup = parsed['group'];
        currentEpgId = parsed['epgId'];
      } else if (line.startsWith(_extGrp)) {
        // Parse EXTGRP line (alternative group format)
        currentGroup = line.substring(_extGrp.length).trim();
      } else if (line.startsWith('#')) {
        // Skip other directives
        continue;
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        // This is a URL line
        if (currentName != null) {
          final url = line.split('\n').first.trim();
          if (_isValidUrl(url)) {
            final channel = Channel(
              playlistId: playlistId,
              name: currentName,
              url: url,
              logoUrl: currentLogo,
              groupName: currentGroup ?? 'Uncategorized',
              epgId: currentEpgId,
            );

            rawChannels.add(channel);
            validChannelCount++;
          } else {
            invalidUrlCount++;
            // ServiceLocator.log.d('DEBUG: Invalid URL at line ${i + 1} line: $line');
          }
        } else {
          // ServiceLocator.log.d('DEBUG: Found URL without corresponding channel name at line ${i + 1} line: $line');
        }

        // Reset for next entry
        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentEpgId = null;
      }
    }

    // ServiceLocator.log.d('DEBUG: Original parse completed - valid channels: $validChannelCount, invalid URLs: $invalidUrlCount');
    print(
        'M3U Parser: Original parse completed - valid channels: $validChannelCount, invalid URLs: $invalidUrlCount');

    // Merge channels with same epgId (tvg-name) into single channel with multiple sources
    final List<Channel> mergedChannels = _mergeChannelSources(rawChannels);

    // ServiceLocator.log.d('DEBUG: Merged channel count: ${mergedChannels.length} (original: ${rawChannels.length})');
    print(
        'M3U Parser: Merged channel count: ${mergedChannels.length} (original: ${rawChannels.length})');

    // Save parse result with EPG URL
    _lastParseResult = M3UParseResult(channels: mergedChannels, epgUrl: epgUrl);
    print('M3U Parser: Saving parse result - EPG URL: ${epgUrl ?? "(not configured)"}');

    return mergedChannels;
  }

  /// Merge channels with same epgId into single channel with multiple sources
  /// Preserves the order of first occurrence, but prefers non-special groups
  static List<Channel> _mergeChannelSources(List<Channel> channels) {
    final Map<String, Channel> mergedMap = {};
    final List<String> orderKeys = []; // Preserve order

    // Special groups that should not be the primary group
    final specialGroups = {'🕘️Update Time', 'Update Time', 'update', 'info'};

    for (final channel in channels) {
      // Use epgId as merge key
      final mergeKey = channel.epgId ?? channel.name;

      if (mergedMap.containsKey(mergeKey)) {
        // Add source to existing channel
        final existing = mergedMap[mergeKey]!;
        final newSources = [...existing.sources];

        // Add URL if not duplicate
        if (!newSources.contains(channel.url)) {
          newSources.add(channel.url);
        }

        // Check if we should replace the primary channel info
        // (prefer non-special group over special group)
        final existingIsSpecial = specialGroups.any((g) =>
            existing.groupName?.toLowerCase().contains(g.toLowerCase()) ??
            false);
        final newIsSpecial = specialGroups.any((g) =>
            channel.groupName?.toLowerCase().contains(g.toLowerCase()) ??
            false);

        if (existingIsSpecial && !newIsSpecial) {
          // Replace with the new channel's info but keep all sources
          mergedMap[mergeKey] = channel.copyWith(
            sources: newSources,
            // Keep the first URL as primary
            url: newSources.first,
          );
        } else {
          // Just add the new source
          mergedMap[mergeKey] = existing.copyWith(sources: newSources);
        }
      } else {
        // New channel
        mergedMap[mergeKey] = channel.copyWith(sources: [channel.url]);
        orderKeys.add(mergeKey);
      }
    }

    // Return in original order
    return orderKeys.map((key) => mergedMap[key]!).toList();
  }

  /// Extract EPG URL from M3U header line
  /// Supports: x-tvg-url="url" or url-tvg="url"
  static String? _extractEpgUrl(String headerLine) {
    print(
        'M3U Parser: _extractEpgUrl Input: ${headerLine.length > 200 ? headerLine.substring(0, 200) + "..." : headerLine}');

    // Match x-tvg-url="..." or url-tvg="..."
    final patterns = [
      RegExp(r'x-tvg-url="([^"]+)"', caseSensitive: false),
      RegExp(r'url-tvg="([^"]+)"', caseSensitive: false),
      RegExp(r"x-tvg-url='([^']+)'", caseSensitive: false),
      RegExp(r"url-tvg='([^']+)'", caseSensitive: false),
    ];

    for (int i = 0; i < patterns.length; i++) {
      final pattern = patterns[i];
      final match = pattern.firstMatch(headerLine);
      print('M3U Parser: Attempting pattern $i: ${pattern.pattern} - match result: ${match != null}');

      if (match != null && match.groupCount >= 1) {
        final urls = match.group(1);
        print('M3U Parser: Extracted URL string: $urls');

        if (urls != null && urls.isNotEmpty) {
          // If multiple URLs separated by comma, return the first one
          final firstUrl = urls.split(',').first.trim();
          print('M3U Parser: Returning first URL: $firstUrl');
          return firstUrl;
        }
      }
    }

    print('M3U Parser: No patterns matched EPG URL');
    return null;
  }

  /// Parse EXTINF line and extract metadata
  static Map<String, String?> _parseExtInf(String line) {
    String? name;
    String? logo;
    String? group;
    String? epgId;

    // Remove #EXTINF: prefix
    String content = line.substring(_extInf.length);

    // Find the channel name (after the last comma)
    final lastCommaIndex = content.lastIndexOf(',');
    if (lastCommaIndex != -1) {
      name = content.substring(lastCommaIndex + 1).trim();
      content = content.substring(0, lastCommaIndex);
    }

    // Parse attributes
    final attributes = _parseAttributes(content);

    logo = attributes['tvg-logo'] ?? attributes['logo'];
    group = attributes['group-title'] ?? attributes['tvg-group'];
    epgId = attributes['tvg-id'] ?? attributes['tvg-name'];

    // Debug logging for logo parsing
    if (logo != null && logo.isNotEmpty) {
      // ServiceLocator.log.d('DEBUG: Parsed logo URL: $logo, channel: $name');
    }

    return {
      'name': name,
      'logo': logo,
      'group': group,
      'epgId': epgId,
    };
  }

  /// Parse key="value" attributes from a string
  static Map<String, String> _parseAttributes(String content) {
    final Map<String, String> attributes = {};

    // Regular expression to match key="value" or key=value patterns
    final RegExp attrRegex =
        RegExp(r'(\S+?)=["\u0027]?([^"\u0027]+)["\u0027]?(?:\s|$)');

    for (final match in attrRegex.allMatches(content)) {
      if (match.groupCount >= 2) {
        final key = match.group(1)?.toLowerCase();
        final value = match.group(2);
        if (key != null && value != null) {
          attributes[key] = value.trim();
        }
      }
    }

    return attributes;
  }

  /// Check if a string is a valid URL
  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final isValid = uri.hasScheme &&
          (uri.scheme == 'http' ||
              uri.scheme == 'https' ||
              uri.scheme == 'rtmp' ||
              uri.scheme == 'rtsp' ||
              uri.scheme == 'mms' ||
              uri.scheme == 'mmsh' ||
              uri.scheme == 'mmst');

      // if (!isValid) {
      //   ServiceLocator.log.d('DEBUG: URL verification failed - Scheme: ${uri.scheme}, Host: ${uri.host}');
      // }

      return isValid;
    } catch (e) {
      // ServiceLocator.log.d('DEBUG: URL parsing error: $url, error: $e');
      return false;
    }
  }

  /// Extract unique groups from a list of channels
  static List<String> extractGroups(List<Channel> channels) {
    final Set<String> groups = {};
    for (final channel in channels) {
      if (channel.groupName != null && channel.groupName!.isNotEmpty) {
        groups.add(channel.groupName!);
      }
    }
    return groups.toList()..sort();
  }

  /// Generate M3U content from a list of channels
  static String generate(List<Channel> channels, {String? playlistName}) {
    final buffer = StringBuffer();

    buffer.writeln('#EXTM3U');
    if (playlistName != null) {
      buffer.writeln('#PLAYLIST:$playlistName');
    }
    buffer.writeln();

    for (final channel in channels) {
      // Generate entry for each source
      for (final sourceUrl in channel.sources) {
        buffer.write('#EXTINF:-1');

        if (channel.epgId != null) {
          buffer.write(' tvg-id="${channel.epgId}"');
        }
        if (channel.logoUrl != null) {
          buffer.write(' tvg-logo="${channel.logoUrl}"');
        }
        if (channel.groupName != null) {
          buffer.write(' group-title="${channel.groupName}"');
        }

        buffer.writeln(',${channel.name}');
        buffer.writeln(sourceUrl);
        buffer.writeln();
      }
    }

    return buffer.toString();
  }
}

/// Class for passing parameters to isolate
class _ParseParams {
  final String content;
  final int playlistId;

  _ParseParams(this.content, this.playlistId);
}
