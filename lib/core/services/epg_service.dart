import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:flutter/foundation.dart';
import './service_locator.dart';

/// EPG program information
class EpgProgram {
  final String channelId;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;
  final String? category;

  EpgProgram({
    required this.channelId,
    required this.title,
    this.description,
    required this.start,
    required this.end,
    this.category,
  });

  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  bool get isNext {
    final now = DateTime.now();
    return start.isAfter(now);
  }

  /// Program progress (0.0 - 1.0)
  double get progress {
    final now = DateTime.now();
    if (now.isBefore(start)) return 0.0;
    if (now.isAfter(end)) return 1.0;
    final total = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    return elapsed / total;
  }

  /// Remaining time (minutes)
  int get remainingMinutes {
    final now = DateTime.now();
    if (now.isAfter(end)) return 0;
    return end.difference(now).inMinutes;
  }
}

/// EPG service - parsing and managing EPG data
class EpgService {
  static final EpgService _instance = EpgService._internal();
  factory EpgService() => _instance;
  EpgService._internal();

  // channelId -> List<EpgProgram>
  final Map<String, List<EpgProgram>> _programs = {};

  // Channel name mapping (for matching)
  final Map<String, String> _channelNames = {};

  // Channel name index (normalizedName -> channelId) for fast lookup
  final Map<String, String> _nameIndex = {};

  // EPG query cache (channelKey -> channelId)
  final Map<String, String?> _lookupCache = {};

  DateTime? _lastUpdate;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  DateTime? get lastUpdate => _lastUpdate;

  /// Get current program for channel
  EpgProgram? getCurrentProgram(String? channelId, String? channelName) {
    final programs = _findPrograms(channelId, channelName);
    if (programs == null) return null;

    final now = DateTime.now();
    for (final program in programs) {
      if (now.isAfter(program.start) && now.isBefore(program.end)) {
        return program;
      }
    }
    return null;
  }

  /// Get next program for channel
  EpgProgram? getNextProgram(String? channelId, String? channelName) {
    final programs = _findPrograms(channelId, channelName);
    if (programs == null) return null;

    final now = DateTime.now();
    for (final program in programs) {
      if (program.start.isAfter(now)) {
        return program;
      }
    }
    return null;
  }

  /// Get todays program list for channel
  List<EpgProgram> getTodayPrograms(String? channelId, String? channelName) {
    final programs = _findPrograms(channelId, channelName);
    if (programs == null) return [];

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return programs.where((p) => p.start.isAfter(startOfDay) && p.start.isBefore(endOfDay)).toList();
  }

  List<EpgProgram>? _findPrograms(String? channelId, String? channelName) {
    // Generate cache key
    final cacheKey = '${channelId ?? ''}_${channelName ?? ''}';

    // Check cache
    if (_lookupCache.containsKey(cacheKey)) {
      final cachedId = _lookupCache[cacheKey];
      if (cachedId != null && _programs.containsKey(cachedId)) {
        return _programs[cachedId];
      }
      return null;
    }

    // Search using channelId first
    if (channelId != null && channelId.isNotEmpty && _programs.containsKey(channelId)) {
      _lookupCache[cacheKey] = channelId;
      return _programs[channelId];
    }

    // Fast lookup using channel name index
    if (channelName != null && channelName.isNotEmpty) {
      final normalizedName = _normalizeName(channelName);
      ServiceLocator.log.d('EPG: Looking up channel "$channelName" → normalized to "$normalizedName"');
      
      if (_nameIndex.containsKey(normalizedName)) {
        final foundId = _nameIndex[normalizedName]!;
        ServiceLocator.log.d('EPG: Match successful "$normalizedName" → ID: $foundId');
        _lookupCache[cacheKey] = foundId;
        return _programs[foundId];
      } else {
        ServiceLocator.log.d('EPG: No match found "$normalizedName", available channels: ${_nameIndex.keys.take(10).join(", ")}...');
      }
      
      // Try using channelId as a name for lookup
      if (channelId != null && channelId.isNotEmpty) {
        final normalizedId = _normalizeName(channelId);
        if (_nameIndex.containsKey(normalizedId)) {
          final foundId = _nameIndex[normalizedId]!;
          _lookupCache[cacheKey] = foundId;
          return _programs[foundId];
        }
      }
    }

    // Cache not found result
    _lookupCache[cacheKey] = null;
    return null;
  }

  /// Normalize channel name for smart matching
  /// Refer to logo service matching logic
  String _normalizeName(String name) {
    String normalized = name.toUpperCase();
    
    // 1. Remove spaces, hyphens, underscores (keep +), unify format
    normalized = normalized.replaceAll(RegExp(r'[-\s_]+'), '');
    
    // 2. Special handling: CCTV01 -> CCTV1
    normalized = normalized.replaceAllMapped(
      RegExp(r'CCTV0*(\d+)'),
      (match) => 'CCTV${match.group(1)}',
    );
    
    // 3. Remove English suffix
    normalized = normalized.replaceAll(RegExp(r'(HD|4K|8K|FHD|UHD|SD)'), '');
    
    // 4. Remove international suffixes (match end modifiers)
    normalized = normalized.replaceAll(
      RegExp(r'(HD|4K|8K|FHD|UHD|SD|BLUE-RAY|HIGH-BITRATE|LOW-BITRATE|CHANNEL)$'),
      '',
    );

    // 5. Special handling for CCTV channels: remove descriptive text (e.g. CCTV1-General -> CCTV1)
    normalized = normalized.replaceAllMapped(
      RegExp(r'(CCTV\d+\+?)[A-Z0-9]+'),
      (match) => match.group(1)!,
    );
    
    // 6. Special handling: keep "TV"
    if (!normalized.endsWith('TV') && name.toUpperCase().contains('TV')) {
      // If original name had "TV" but was removed, add it back
      final wsMatch = RegExp(r'(.+?)TV').firstMatch(name.toUpperCase().replaceAll(RegExp(r'[-\s_]+'), ''));
      if (wsMatch != null) {
        normalized = '${wsMatch.group(1)!}TV';
      }
    }

    // 7. Remove modifiers after "TV" suffix
    normalized = normalized.replaceAll(
      RegExp(r'(TV)(HD|4K|8K|FHD|UHD|SD)$'),
      r'$1',
    );
    
    return normalized;
  }

  /// Load EPG data from URL
  Future<bool> loadFromUrl(String url) async {
    if (_isLoading) return false;
    _isLoading = true;

    try {
      ServiceLocator.log.d('EPG: Loading from $url');

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode != 200) {
        ServiceLocator.log.d('EPG: HTTP error ${response.statusCode}');
        return false;
      }

      String content;

      // Check if gzip compressed
      if (url.endsWith('.gz')) {
        final decompressed = GZipCodec().decode(response.bodyBytes);
        content = _decodeContent(decompressed);
      } else {
        content = _decodeContent(response.bodyBytes);
      }

      // Parse XML in background isolate to avoid blocking UI
      final result = await compute(_parseXmlTvInBackground, content);
      if (result != null) {
        _programs.clear();
        _channelNames.clear();
        _nameIndex.clear();
        _lookupCache.clear();

        _programs.addAll(result['programs'] as Map<String, List<EpgProgram>>);
        _channelNames.addAll(result['channelNames'] as Map<String, String>);
        _nameIndex.addAll(result['nameIndex'] as Map<String, String>);

        _lastUpdate = DateTime.now();
        ServiceLocator.log.d('EPG: Loaded ${_programs.length} channels, ${_programs.values.fold(0, (sum, list) => sum + list.length)} programs');
        return true;
      }
      return false;
    } catch (e) {
      ServiceLocator.log.d('EPG: Error loading: $e');
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// Parse XML in background isolate
  static Map<String, dynamic>? _parseXmlTvInBackground(String content) {
    try {
      final document = XmlDocument.parse(content);
      final tv = document.findElements('tv').firstOrNull;
      if (tv == null) return null;

      final programs = <String, List<EpgProgram>>{};
      final channelNames = <String, String>{};
      final nameIndex = <String, String>{};

      // Parse channels
      for (final channel in tv.findElements('channel')) {
        final id = channel.getAttribute('id');
        if (id == null) continue;

        // Supports two formats:
        // 1. <channel id="11"><display-name>CCTV1</display-name></channel>
        // 2. <channel id="11" display-name="CCTV1"></channel>
        var displayName = channel.findElements('display-name').firstOrNull?.innerText;
        displayName ??= channel.getAttribute('display-name');
        
        if (displayName != null) {
          channelNames[id] = displayName;
          nameIndex[_normalizeNameStatic(displayName)] = id;
          nameIndex[_normalizeNameStatic(id)] = id;
        }
      }

      // Parse programs (supports both "programme" and "program" tags)
      final programmes = tv.findElements('programme').toList();
      programmes.addAll(tv.findElements('program'));
      
      for (final programme in programmes) {
        final channelId = programme.getAttribute('channel');
        final startStr = programme.getAttribute('start');
        final stopStr = programme.getAttribute('stop');

        if (channelId == null || startStr == null || stopStr == null) continue;

        final start = _parseDateTimeStatic(startStr);
        final end = _parseDateTimeStatic(stopStr);
        if (start == null || end == null) continue;

        final title = programme.findElements('title').firstOrNull?.innerText ?? '';
        final desc = programme.findElements('desc').firstOrNull?.innerText;
        final category = programme.findElements('category').firstOrNull?.innerText;

        final program = EpgProgram(
          channelId: channelId,
          title: title,
          description: desc,
          start: start,
          end: end,
          category: category,
        );

        programs.putIfAbsent(channelId, () => []).add(program);
      }

      // Sort by start time
      for (final programList in programs.values) {
        programList.sort((a, b) => a.start.compareTo(b.start));
      }

      return {
        'programs': programs,
        'channelNames': channelNames,
        'nameIndex': nameIndex,
      };
    } catch (e) {
      return null;
    }
  }

  /// Normalize channel name (static version for isolate)
  /// Refer to logo service matching logic
  static String _normalizeNameStatic(String name) {
    String normalized = name.toUpperCase();
    
    // 1. Remove spaces, hyphens, underscores (keep +), unify format
    normalized = normalized.replaceAll(RegExp(r'[-\s_]+'), '');
    
    // 2. Special handling: CCTV01 -> CCTV1
    normalized = normalized.replaceAllMapped(
      RegExp(r'CCTV0*(\d+)'),
      (match) => 'CCTV${match.group(1)}',
    );
    
    // 3. Remove English suffix
    normalized = normalized.replaceAll(RegExp(r'(HD|4K|8K|FHD|UHD|SD)'), '');
    
    // 4. Remove international suffixes (match end modifiers)
    normalized = normalized.replaceAll(
      RegExp(r'(HD|4K|8K|FHD|UHD|SD|BLUE-RAY|HIGH-BITRATE|LOW-BITRATE|CHANNEL)$'),
      '',
    );

    // 5. Special handling for CCTV channels: remove descriptive text (e.g. CCTV1-General -> CCTV1)
    normalized = normalized.replaceAllMapped(
      RegExp(r'(CCTV\d+\+?)[A-Z0-9]+'),
      (match) => match.group(1)!,
    );
    
    // 6. Special handling: keep "TV"
    if (!normalized.endsWith('TV') && name.toUpperCase().contains('TV')) {
      // If original name had "TV" but was removed, add it back
      final wsMatch = RegExp(r'(.+?)TV').firstMatch(name.toUpperCase().replaceAll(RegExp(r'[-\s_]+'), ''));
      if (wsMatch != null) {
        normalized = '${wsMatch.group(1)!}TV';
      }
    }

    // 7. Remove modifiers after "TV" suffix
    normalized = normalized.replaceAll(
      RegExp(r'(TV)(HD|4K|8K|FHD|UHD|SD)$'),
      r'$1',
    );
    
    return normalized;
  }

  static DateTime? _parseDateTimeStatic(String str) {
    try {
      final match = RegExp(r'(\d{14})').firstMatch(str);
      if (match == null) return null;

      final dateStr = match.group(1)!;
      return DateTime(
        int.parse(dateStr.substring(0, 4)),
        int.parse(dateStr.substring(4, 6)),
        int.parse(dateStr.substring(6, 8)),
        int.parse(dateStr.substring(8, 10)),
        int.parse(dateStr.substring(10, 12)),
        int.parse(dateStr.substring(12, 14)),
      );
    } catch (e) {
      return null;
    }
  }

  /// Smart decode content, supports UTF-8 and GBK
  String _decodeContent(List<int> bytes) {
    // Try UTF-8 first
    try {
      final content = utf8.decode(bytes);
      // Check for garbled text (common UTF-8 decoding GBK signatures)
      if (!content.contains('�') && !_hasGarbledChinese(content)) {
        return content;
      }
    } catch (_) {}

    // Try Latin1 (ISO-8859-1) as a GBK alternative
    // Since Dart lacks built-in GBK support, use Latin1 to read raw bytes
    try {
      final latin1Content = latin1.decode(bytes);
      // Check encoding in XML declaration
      if (latin1Content.contains('encoding="gb2312"') || latin1Content.contains('encoding="gbk"') || latin1Content.contains('encoding="GB2312"') || latin1Content.contains('encoding="GBK"')) {
        // GBK decoding needed but unsupported, try UTF-8 with allowMalformed
        return utf8.decode(bytes, allowMalformed: true);
      }
    } catch (_) {}

    // Finally use UTF-8 with allowMalformed
    return utf8.decode(bytes, allowMalformed: true);
  }

  bool _hasGarbledChinese(String content) {
    // Check for common garbled patterns
    final garbledPatterns = ['å', 'ä', 'ã', 'æ', 'ç', 'è', 'é', 'ê', 'ë', 'ì', 'í', 'î', 'ï'];
    int count = 0;
    for (final pattern in garbledPatterns) {
      if (content.contains(pattern)) count++;
    }
    // If there are multiple such characters, it might be garbled
    return count > 3;
  }

  void clear() {
    _programs.clear();
    _channelNames.clear();
    _nameIndex.clear();
    _lookupCache.clear();
    _lastUpdate = null;
  }
}
