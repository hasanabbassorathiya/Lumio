import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/channel.dart';
import '../services/service_locator.dart';

/// Parser for TXT playlist files (genre format)
/// Format:
/// Category,#genre#
/// Channel Name,URL
/// Channel Name,URL
class TXTParser {
  /// Parse TXT content from a URL
  static Future<List<Channel>> parseFromUrl(String url, int playlistId) async {
    try {
      ServiceLocator.log.d('DEBUG: Starting to fetch TXT playlist content from URL: $url');

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

      ServiceLocator.log.d('DEBUG: Successfully fetched TXT playlist content, status code: ${response.statusCode}');
      ServiceLocator.log
          .d('DEBUG: Content size: ${response.data.toString().length}  characters');

      // Use compute to parse in a separate isolate to avoid blocking the main thread
      final channels = await compute(
          _parseInIsolate, _ParseParams(response.data.toString(), playlistId));
      ServiceLocator.log.d('DEBUG: TXT URL parsing completed, parsed  ${channels.length}  channels');

      return channels;
    } catch (e) {
      ServiceLocator.log.d('DEBUG: Error fetching TXT playlist from URL: $e');

      final errorStr = e.toString().toLowerCase();

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

  /// Parse TXT content from a local file
  static Future<List<Channel>> parseFromFile(
      String filePath, int playlistId) async {
    try {
      ServiceLocator.log.d('DEBUG: Starting to read TXT playlist from local file: $filePath');
      final file = File(filePath);

      if (!await file.exists()) {
        ServiceLocator.log.d('DEBUG: File does not exist: $filePath');
        throw Exception('File does not exist: $filePath');
      }

      final content = await file.readAsString();
      ServiceLocator.log.d('DEBUG: Successfully read local TXT file, content size: ${content.length} characters');

      // Use compute to parse in a separate isolate to avoid blocking the main thread
      final channels =
          await compute(_parseInIsolate, _ParseParams(content, playlistId));
      ServiceLocator.log.d('DEBUG: Local TXT file parsing completed, parsed ${channels.length} channels');

      return channels;
    } catch (e) {
      ServiceLocator.log.d('DEBUG: Error reading local TXT playlist file: $e');
      throw Exception('Error reading playlist file: $e');
    }
  }

  /// Parse TXT content string
  /// Format: Category,#genre#
  ///         Channel Name,URL
  /// Merges channels with same name into single channel with multiple sources
  static List<Channel> parse(String content, int playlistId) {
    // Note: this method may run in isolate, cannot use ServiceLocator.log
    // ServiceLocator.log.d('DEBUG: Starting parse of TXT content, playlist ID: $playlistId');

    final List<Channel> rawChannels = [];
    final lines = LineSplitter.split(content).toList();

    // ServiceLocator.log.d('DEBUG: Total TXT lines: ${lines.length}');

    if (lines.isEmpty) {
      // ServiceLocator.log.d('DEBUG: TXT content is empty, returning empty channel list');
      return rawChannels;
    }

    String currentGroup = 'Uncategorized';
    int validChannelCount = 0;
    int invalidLineCount = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) continue;

      // Check if this is a category line (ends with ,#genre#)
      if (line.endsWith(',#genre#')) {
        currentGroup = line.substring(0, line.length - 8).trim();
        if (currentGroup.isEmpty) {
          currentGroup = 'Uncategorized';
        }
        // ServiceLocator.log.d('DEBUG: Found category: $currentGroup');
        continue;
      }

      // Parse channel line: Channel Name,URL
      final parts = line.split(',');
      if (parts.length >= 2) {
        final name = parts[0].trim();
        final url =
            parts.sublist(1).join(',').trim(); // Handle URLs with commas

        if (name.isNotEmpty && _isValidUrl(url)) {
          final channel = Channel(
            playlistId: playlistId,
            name: name,
            url: url,
            groupName: currentGroup,
          );

          rawChannels.add(channel);
          validChannelCount++;
        } else {
          invalidLineCount++;
          // if (name.isEmpty) {
          //   ServiceLocator.log.d('DEBUG: Line ${i + 1} channel name is empty: $line');
          // } else {
          //   ServiceLocator.log.d('DEBUG: Line ${i + 1} URL is invalid: $url');
          // }
        }
      } else {
        invalidLineCount++;
        // ServiceLocator.log.d('DEBUG: Line ${i + 1} format is incorrect: $line');
      }
    }

    // ServiceLocator.log.d('DEBUG: TXT original parse completed - valid channels: $validChannelCount, invalid lines: $invalidLineCount');

    // Merge channels with same name into single channel with multiple sources
    final List<Channel> mergedChannels = _mergeChannelSources(rawChannels);

    // ServiceLocator.log.d('DEBUG: TXT merged channel count: ${mergedChannels.length} (original: ${rawChannels.length})');

    return mergedChannels;
  }

  /// Merge channels with same name into single channel with multiple sources
  /// Preserves the order of first occurrence, but prefers non-special groups
  static List<Channel> _mergeChannelSources(List<Channel> channels) {
    final Map<String, Channel> mergedMap = {};
    final List<String> orderKeys = []; // Preserve order

    // Special groups that should not be the primary group
    final specialGroups = {'🕘️Update Time', 'Update Time', 'update', 'info'};

    for (final channel in channels) {
      // Use channel name as merge key (TXT format doesn't have epgId)
      final mergeKey = channel.name;

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

      return isValid;
    } catch (e) {
      return false;
    }
  }

  /// Generate TXT content from a list of channels
  static String generate(List<Channel> channels) {
    final buffer = StringBuffer();

    // Group channels by category
    final Map<String, List<Channel>> groupedChannels = {};
    for (final channel in channels) {
      final group = channel.groupName ?? 'Uncategorized';
      groupedChannels.putIfAbsent(group, () => []).add(channel);
    }

    // Write each group
    for (final entry in groupedChannels.entries) {
      buffer.writeln('${entry.key},#genre#');
      for (final channel in entry.value) {
        buffer.writeln('${channel.name},${channel.url}');
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

/// Parsing function executed in Isolate (must be top-level or static)
List<Channel> _parseInIsolate(_ParseParams params) {
  return TXTParser.parse(params.content, params.playlistId);
}
