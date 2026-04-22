import '../database/database_helper.dart';
import 'service_locator.dart';

/// Service for managing channel logos
class ChannelLogoService {
  final DatabaseHelper _db;
  static const String _tableName = 'channel_logos';
  
  // Cache for logo mappings
  final Map<String, String> _logoCache = {};
  bool _isInitialized = false;

  ChannelLogoService(this._db);

  /// Initialize the service and load cache
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      ServiceLocator.log.d('ChannelLogoService: Starting initialization');
      await _loadCacheFromDatabase();
      _isInitialized = true;
      ServiceLocator.log.d('ChannelLogoService: Initialization completed, cached ${_logoCache.length} records');
    } catch (e) {
      ServiceLocator.log.e('ChannelLogoService: Initialization failed: $e');
    }
  }

  /// Load cache from database
  Future<void> _loadCacheFromDatabase() async {
    try {
      final logos = await _db.query(_tableName);
      _logoCache.clear();
      for (final logo in logos) {
        final channelName = logo['channel_name'] as String;
        final logoUrl = logo['logo_url'] as String;
        _logoCache[_normalizeChannelName(channelName)] = logoUrl;
      }
      ServiceLocator.log.d('ChannelLogoService: Cache loading completed, total ${_logoCache.length} records');
    } catch (e) {
      ServiceLocator.log.e('ChannelLogoService: Cache loading failed: $e');
    }
  }

  /// Normalize channel name for matching
  String _normalizeChannelName(String name) {
    String normalized = name.toUpperCase();
    
    // 1. Special handling: CCTV-01 -> CCTV1, CCTV-1 -> CCTV1
    normalized = normalized.replaceAllMapped(
      RegExp(r'CCTV[-\s]*0*(\d+)'),
      (match) => 'CCTV${match.group(1)}',
    );

    // 2. For pure English+number channels (e.g. CCTV1, CCTV5+), extract core part and remove extra suffixes
    // Match pattern: letter+number+optional symbol (e.g. +), followed by other suffix
    final coreMatch = RegExp(r'^([A-Z0-9+]+)').firstMatch(normalized);
    if (coreMatch != null) {
      final core = coreMatch.group(1)!;
      // If core part contains letters and numbers, it is an English channel, keep core only
      if (RegExp(r'[A-Z]').hasMatch(core) && RegExp(r'[0-9]').hasMatch(core)) {
        normalized = core;
        return normalized;
      }
    }
    
    // 3. For international channels, remove common suffixes
    // Remove English suffix
    normalized = normalized.replaceAll(RegExp(r'(HD|4K|8K|FHD|UHD|SD)'), '');

    // Remove status suffixes (match end modifiers)
    normalized = normalized.replaceAll(
      RegExp(r'(HD|UHD|FHD|SD|BLUE-RAY|HIGH-BITRATE|LOW-BITRATE|CHANNEL|TV-HD|TV-UHD)$'),
      '',
    );

    // Special handling: preserve "TV"
    if (!normalized.endsWith('TV') && name.toUpperCase().contains('TV')) {
      // If original name contained "TV" but was removed, add it back
      final wsMatch = RegExp(r'(.+?)TV').firstMatch(name.toUpperCase());
      if (wsMatch != null) {
        normalized = '${wsMatch.group(1)!}TV';
      }
    }
    
    // 4. Remove spaces, hyphens, underscores (keep + sign)
    normalized = normalized.replaceAll(RegExp(r'[-\s_]+'), '');
    
    return normalized;
  }

  /// Find logo URL for a channel name with fuzzy matching
  Future<String?> findLogoUrl(String channelName) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Try exact match from cache first
    final normalized = _normalizeChannelName(channelName);
    // Lower log level to avoid excessive output
    // ServiceLocator.log.d('ChannelLogoService: Query logo "$channelName" → normalized to "$normalized"');
    
    if (_logoCache.containsKey(normalized)) {
      // ServiceLocator.log.d('ChannelLogoService: Cache hit "$normalized"');
      return _logoCache[normalized];
    }

    // Try fuzzy match from database
    try {
      final cleanName = _normalizeChannelName(channelName);
      
      // Try exact match first (after normalization)
      var results = await _db.rawQuery('''
        SELECT logo_url FROM $_tableName 
        WHERE UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
          REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            channel_name, 
            'High Bitrate', ''), 'Low Bitrate', ''), 'UltraHD', ''), 'Blu-ray', ''), 
            'HD', ''), 'SD', ''), 'HD', ''), '4K', ''), '8K', ''), 
            'FHD', ''), 'UHD', ''), '-', ''), ' ', ''), '_', '')) = ?
        LIMIT 1
      ''', [cleanName]);
      
      // If exact match fails, try fuzzy match
      if (results.isEmpty) {
        results = await _db.rawQuery('''
          SELECT logo_url FROM $_tableName 
          WHERE UPPER(REPLACE(REPLACE(REPLACE(channel_name, '-', ''), ' ', ''), '_', '')) LIKE ?
             OR UPPER(REPLACE(REPLACE(REPLACE(search_keys, '-', ''), ' ', ''), '_', '')) LIKE ?
          LIMIT 1
        ''', ['%$cleanName%', '%$cleanName%']);
      }
      
      if (results.isNotEmpty) {
        final logoUrl = results.first['logo_url'] as String;
        // ServiceLocator.log.d('ChannelLogoService: Database match success "$channelName" → "$logoUrl"');
        // Cache the result
        _logoCache[normalized] = logoUrl;
        return logoUrl;
      }
    } catch (e) {
      ServiceLocator.log.w('ChannelLogoService: Query failed: $e');
    }

    return null;
  }

  /// Get logo count from database
  Future<int> getLogoCount() async {
    try {
      final result = await _db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
      return result.first['count'] as int;
    } catch (e) {
      return 0;
    }
  }
}
