import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import '../../../core/models/playlist.dart';
import '../../../core/models/channel.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/m3u_parser.dart';
import '../../../core/utils/txt_parser.dart';
import '../../favorites/providers/favorites_provider.dart';

class PlaylistProvider extends ChangeNotifier {
  List<Playlist> _playlists = [];
  Playlist? _activePlaylist;
  bool _isLoading = false;
  String? _error;
  double _importProgress = 0.0;

  /// Last extracted EPG URL from M3U file (for UI display only)
  String? _lastExtractedEpgUrl;
  String? get lastExtractedEpgUrl => _lastExtractedEpgUrl;

  // Getters
  List<Playlist> get playlists => _playlists;
  Playlist? get activePlaylist => _activePlaylist;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get importProgress => _importProgress;

  bool get hasPlaylists => _playlists.isNotEmpty;

  String _sortBy = 'name ASC';
  String get sortBy => _sortBy;

  void toggleSortOrder() {
    if (_sortBy == 'name ASC') {
      _sortBy = 'created_at DESC';
    } else {
      _sortBy = 'name ASC';
    }
    loadPlaylists();
  }

  // Load all playlists from database
  Future<void> loadPlaylists() async {
    ServiceLocator.log.i('Start loading playlists', tag: 'PlaylistProvider');
    final startTime = DateTime.now();
    
    _isLoading = true;
    _error = null;
    Future.microtask(() => notifyListeners());

    try {
      final results = await ServiceLocator.database.query(
        'playlists',
        orderBy: _sortBy,
      );

      _playlists = results.map((r) => Playlist.fromMap(r)).toList();
      ServiceLocator.log.d('Loaded ${_playlists.length} playlists from database', tag: 'PlaylistProvider');

      // Debug: Print EPG URL for each playlist from database
      for (final playlist in _playlists) {
        ServiceLocator.log.d('Playlist "${playlist.name}" (ID: ${playlist.id}) - epgUrl: ${playlist.epgUrl ?? "(Not configured)"}', tag: 'PlaylistProvider');
      }

      // Load channel counts for each playlist
      for (int i = 0; i < _playlists.length; i++) {
        final countResult = await ServiceLocator.database.rawQuery(
          'SELECT COUNT(*) as count, COUNT(DISTINCT group_name) as groups FROM channels WHERE playlist_id = ?',
          [_playlists[i].id],
        );

        if (countResult.isNotEmpty) {
          _playlists[i] = _playlists[i].copyWith(
            channelCount: countResult.first['count'] as int? ?? 0,
            groupCount: countResult.first['groups'] as int? ?? 0,
          );
        }
      }

      // Set active playlist if none selected
      if (_activePlaylist == null && _playlists.isNotEmpty) {
        _activePlaylist = _playlists.firstWhere(
          (p) => p.isActive,
          orElse: () => _playlists.first,
        );
        ServiceLocator.log.d('Set active playlist: ${_activePlaylist?.name}', tag: 'PlaylistProvider');
      }

      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i('Playlist loading completed, time taken: ${loadTime}ms', tag: 'PlaylistProvider');
      _error = null;
    } catch (e) {
      ServiceLocator.log.e('Failed to load playlists', tag: 'PlaylistProvider', error: e);
      _error = 'Failed to load playlists: $e';
      _playlists = [];
    }

    _isLoading = false;
    Future.microtask(() => notifyListeners());
  }

  /// Detect playlist format from URL or content
  /// Returns 'txt' for TXT format, 'm3u' for M3U format
  String _detectPlaylistFormat(String source, {String? content}) {
    // Check by extension first
    final lowerSource = source.toLowerCase();
    if (lowerSource.endsWith('.txt')) {
      return 'txt';
    }
    if (lowerSource.endsWith('.m3u') || lowerSource.endsWith('.m3u8')) {
      return 'm3u';
    }

    // Check by content if available
    if (content != null) {
      final trimmed = content.trim();
      // TXT format typically starts with category or has ,#genre# pattern
      if (trimmed.contains(',#genre#')) {
        return 'txt';
      }
      // M3U format starts with #EXTM3U
      if (trimmed.startsWith('#EXTM3U') || trimmed.startsWith('#EXTINF')) {
        return 'm3u';
      }
    }

    // Default to M3U
    return 'm3u';
  }

  // Add a new playlist from URL
  Future<Playlist?> addPlaylistFromUrl(String name, String url) async {
    ServiceLocator.log.i('Adding playlist from URL: $name', tag: 'PlaylistProvider');
    ServiceLocator.log.d('URL: $url', tag: 'PlaylistProvider');
    final startTime = DateTime.now();

    _isLoading = true;
    _importProgress = 0.0;
    _error = null;
    notifyListeners();

    int? playlistId;
    try {
      // Create playlist record
      final playlistData = Playlist(
        name: name,
        url: url,
        createdAt: DateTime.now(),
      ).toMap();

      playlistId = await ServiceLocator.database.insert('playlists', playlistData);

      _importProgress = 0.2;
      notifyListeners();

      // Detect format and parse accordingly
      final format = _detectPlaylistFormat(url);
      ServiceLocator.log.i('Detected playlist format: $format', tag: 'PlaylistProvider');

      final List<Channel> channels;
      if (format == 'txt') {
        channels = await TXTParser.parseFromUrl(url, playlistId);
      } else {
        channels = await M3UParser.parseFromUrl(url, playlistId);
      }

      // Check for EPG URL in M3U header (only for M3U format)
      if (format == 'm3u') {
        _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
        ServiceLocator.log.d('M3U parse result - EPG URL: ${_lastExtractedEpgUrl ?? "(Not found)"}', tag: 'PlaylistProvider');

        if (_lastExtractedEpgUrl != null) {
          ServiceLocator.log.d('Extracted EPG URL from M3U: $_lastExtractedEpgUrl', tag: 'PlaylistProvider');
          // Save EPG URL to playlist
          final updateCount = await ServiceLocator.database.update(
            'playlists',
            {'epg_url': _lastExtractedEpgUrl},
            where: 'id = ?',
            whereArgs: [playlistId],
          );
          ServiceLocator.log.d('EPG URL saved to database - updated rows: $updateCount', tag: 'PlaylistProvider');
        } else {
          ServiceLocator.log.d('No EPG URL found in M3U file (x-tvg-url or url-tvg)', tag: 'PlaylistProvider');
        }
      }

      _importProgress = 0.6;
      notifyListeners();

      if (channels.isEmpty) {
        ServiceLocator.log.w('No channels found in playlist', tag: 'PlaylistProvider');
        throw Exception('No channels found in playlist');
      }

      ServiceLocator.log.i('Parsed ${channels.length} channels', tag: 'PlaylistProvider');

      // Use batch for much faster insertion, split into chunks to avoid memory issues
      const chunkSize = 500; // Insert 500 channels at a time
      for (int i = 0; i < channels.length; i += chunkSize) {
        final end = (i + chunkSize < channels.length) ? i + chunkSize : channels.length;
        final chunk = channels.sublist(i, end);

        final batch = ServiceLocator.database.db.batch();
        for (final channel in chunk) {
          batch.insert('channels', channel.toMap());
        }
        await batch.commit(noResult: true);

        // Update progress
        _importProgress = 0.6 + (0.4 * (end / channels.length));
        notifyListeners();

        ServiceLocator.log.d('Inserted $end/${channels.length} channels', tag: 'PlaylistProvider');
      }

      // Update playlist with last updated timestamp and counts
      await ServiceLocator.database.update(
        'playlists',
        {
          'last_updated': DateTime.now().millisecondsSinceEpoch,
          'channel_count': channels.length, // Store locally to avoid immediate recounting
        },
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      _importProgress = 1.0;
      notifyListeners();

      // Reload playlists
      await loadPlaylists();

      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i('Playlist added successfully, total time taken: ${totalTime}ms', tag: 'PlaylistProvider');

      // Flush log buffer
      await ServiceLocator.log.flush();

      return _playlists.firstWhere((p) => p.id == playlistId);
    } catch (e) {
      ServiceLocator.log.e('Failed to add playlist', tag: 'PlaylistProvider', error: e);
      // If failed, delete the created playlist record
      if (playlistId != null) {
        try {
          await ServiceLocator.database.delete(
            'playlists',
            where: 'id = ?',
            whereArgs: [playlistId],
          );
        } catch (_) {}
      }
      _error = 'Failed to add playlist: $e';
      _isLoading = false;
      notifyListeners();
      rethrow; // Rethrow exception to show error in UI
    }
  }

  // Add a new playlist from M3U content directly (for QR import)
  Future<Playlist?> addPlaylistFromContent(String name, String content) async {
    _isLoading = true;
    _importProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      // Create playlist record
      final playlistData = Playlist(
        name: name,
        createdAt: DateTime.now(),
      ).toMap();

      final playlistId = await ServiceLocator.database.insert('playlists', playlistData);

      _importProgress = 0.2;
      notifyListeners();

      // Detect format and parse accordingly
      final format = _detectPlaylistFormat('', content: content);
      ServiceLocator.log.d('DEBUG: Detected playlist format: $format');

      final List<Channel> channels;
      if (format == 'txt') {
        channels = TXTParser.parse(content, playlistId);
      } else {
        channels = M3UParser.parse(content, playlistId);
      }

      // Check for EPG URL in M3U header (only for M3U format)
      if (format == 'm3u') {
        _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
        if (_lastExtractedEpgUrl != null) {
          ServiceLocator.log.d('DEBUG: Extracted EPG URL from M3U: $_lastExtractedEpgUrl');
          // Save EPG URL to playlist
          await ServiceLocator.database.update(
            'playlists',
            {'epg_url': _lastExtractedEpgUrl},
            where: 'id = ?',
            whereArgs: [playlistId],
          );
        }
      }

      _importProgress = 0.6;
      notifyListeners();

      if (channels.isEmpty) {
        throw Exception('No channels found in playlist');
      }

      // Use batch for much faster insertion, split into chunks to avoid memory issues
      const chunkSize = 500; // Insert 500 channels at a time
      for (int i = 0; i < channels.length; i += chunkSize) {
        final end = (i + chunkSize < channels.length) ? i + chunkSize : channels.length;
        final chunk = channels.sublist(i, end);
        
        final batch = ServiceLocator.database.db.batch();
        for (final channel in chunk) {
          batch.insert('channels', channel.toMap());
        }
        await batch.commit(noResult: true);
        
        // Update progress
        _importProgress = 0.6 + (0.4 * (end / channels.length));
        notifyListeners();
      }

      // Save the content as a temporary file for future refreshes
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = await File('${tempDir.path}/playlist_${playlistId}_$timestamp.m3u').writeAsString(content);

      ServiceLocator.log.d('DEBUG: Saving temporary playlist file: ${tempFile.path}');

      // Update playlist with last updated timestamp, counts and file path
      await ServiceLocator.database.update(
        'playlists',
        {
          'last_updated': DateTime.now().millisecondsSinceEpoch,
          'channel_count': channels.length,
          'file_path': tempFile.path, // Save temp file path for future refreshes
        },
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      _importProgress = 1.0;
      notifyListeners();

      // Reload playlists
      await loadPlaylists();

      return _playlists.firstWhere((p) => p.id == playlistId);
    } catch (e) {
      ServiceLocator.log.d('DEBUG: Error occurred while adding content playlist: $e');
      _error = 'Failed to add playlist: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Add a new playlist from local file
  Future<Playlist?> addPlaylistFromFile(String name, String filePath) async {
    _isLoading = true;
    _importProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      // Create playlist record
      final playlistData = Playlist(
        name: name,
        filePath: filePath,
        createdAt: DateTime.now(),
      ).toMap();

      final playlistId = await ServiceLocator.database.insert('playlists', playlistData);

      _importProgress = 0.2;
      notifyListeners();

      // Detect format and parse accordingly
      final format = _detectPlaylistFormat(filePath);
      ServiceLocator.log.d('DEBUG: Detected playlist format: $format');

      final List<Channel> channels;
      if (format == 'txt') {
        channels = await TXTParser.parseFromFile(filePath, playlistId);
      } else {
        channels = await M3UParser.parseFromFile(filePath, playlistId);
      }

      // Check for EPG URL in M3U header (only for M3U format)
      if (format == 'm3u') {
        _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
        if (_lastExtractedEpgUrl != null) {
          ServiceLocator.log.d('DEBUG: Extracted EPG URL from M3U: $_lastExtractedEpgUrl');
        }
      }

      _importProgress = 0.6;
      notifyListeners();

      // Insert channels using batch for performance, split into chunks
      const chunkSize = 500; // Insert 500 channels at a time
      for (int i = 0; i < channels.length; i += chunkSize) {
        final end = (i + chunkSize < channels.length) ? i + chunkSize : channels.length;
        final chunk = channels.sublist(i, end);
        
        final batch = ServiceLocator.database.db.batch();
        for (final channel in chunk) {
          batch.insert('channels', channel.toMap());
        }
        await batch.commit(noResult: true);
        
        // Update progress
        _importProgress = 0.6 + (0.4 * (end / channels.length));
        notifyListeners();
      }

      // Update playlist channel count
      await ServiceLocator.database.update(
        'playlists',
        {
          'last_updated': DateTime.now().millisecondsSinceEpoch,
          'channel_count': channels.length,
        },
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      _importProgress = 1.0;
      notifyListeners();

      // Reload playlists
      await loadPlaylists();

      return _playlists.firstWhere((p) => p.id == playlistId);
    } catch (e) {
      _error = 'Failed to add playlist: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Refresh a playlist from its source
  Future<bool> refreshPlaylist(Playlist playlist) async {
    if (playlist.id == null) return false;

    ServiceLocator.log.d('DEBUG: Starting to refresh playlist: ${playlist.name} (ID: ${playlist.id})');
    ServiceLocator.log.d('DEBUG: playlist.url = ${playlist.url}');
    ServiceLocator.log.d('DEBUG: playlist.filePath = ${playlist.filePath}');
    ServiceLocator.log.d('DEBUG: playlist.isRemote = ${playlist.isRemote}');
    ServiceLocator.log.d('DEBUG: playlist.isLocal = ${playlist.isLocal}');

    _isLoading = true;
    _importProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      // Reload playlist from database to ensure data is fresh
      final dbResults = await ServiceLocator.database.query(
        'playlists',
        where: 'id = ?',
        whereArgs: [playlist.id],
      );

      if (dbResults.isEmpty) {
        throw Exception('Playlist not found in database');
      }

      final freshPlaylist = Playlist.fromMap(dbResults.first);
      ServiceLocator.log.d('DEBUG: Reload from database - URL: ${freshPlaylist.url}, FilePath: ${freshPlaylist.filePath}');

      List<Channel> channels;

      ServiceLocator.log.d('DEBUG: Playlist source type: ${freshPlaylist.isRemote ? "Remote URL" : freshPlaylist.isLocal ? "Local file" : "Unknown"}');
      ServiceLocator.log.d('DEBUG: Playlist source path: ${freshPlaylist.sourcePath}');

      if (freshPlaylist.isRemote) {
        ServiceLocator.log.d('DEBUG: Starting to parse playlist from URL: ${freshPlaylist.url}');

        // Detect format and parse accordingly
        final format = _detectPlaylistFormat(freshPlaylist.url!);
        ServiceLocator.log.d('DEBUG: Detected playlist format: $format');

        if (format == 'txt') {
          channels = await TXTParser.parseFromUrl(freshPlaylist.url!, playlist.id!);
        } else {
          channels = await M3UParser.parseFromUrl(freshPlaylist.url!, playlist.id!);
        }

        // Check for EPG URL in M3U header (only for M3U format)
        if (format == 'm3u') {
          _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
          if (_lastExtractedEpgUrl != null) {
            ServiceLocator.log.d('DEBUG: Extracted EPG URL from M3U: $_lastExtractedEpgUrl');
          }
        }
      } else if (freshPlaylist.isLocal) {
        ServiceLocator.log.d('DEBUG: Starting to parse playlist from local file: ${freshPlaylist.filePath}');

        // Check if file exists before trying to parse
        final file = File(freshPlaylist.filePath!);
        if (!await file.exists()) {
          ServiceLocator.log.d('DEBUG: Local file does not exist: ${freshPlaylist.filePath}');
          throw Exception('Local playlist file not found: ${freshPlaylist.filePath}');
        }

        // Detect format and parse accordingly
        final format = _detectPlaylistFormat(freshPlaylist.filePath!);
        ServiceLocator.log.d('DEBUG: Detected playlist format: $format');

        if (format == 'txt') {
          channels = await TXTParser.parseFromFile(freshPlaylist.filePath!, playlist.id!);
        } else {
          channels = await M3UParser.parseFromFile(freshPlaylist.filePath!, playlist.id!);
        }

        // Check for EPG URL in M3U header (only for M3U format)
        if (format == 'm3u') {
          _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
          if (_lastExtractedEpgUrl != null) {
            ServiceLocator.log.d('DEBUG: Extracted EPG URL from M3U: $_lastExtractedEpgUrl');
          }
        }
      } else {
        // Check if this is a content-imported playlist without a proper file path
        ServiceLocator.log.d('DEBUG: Invalid playlist source, URL: ${freshPlaylist.url}, File path: ${freshPlaylist.filePath}');
        throw Exception('Invalid playlist source - URL: ${freshPlaylist.url}, File: ${freshPlaylist.filePath}');
      }

      ServiceLocator.log.d('DEBUG: Parsing completed, found ${channels.length} channels');

      _importProgress = 0.5;
      notifyListeners();

      // Save watch history channel info (name and URL) before deleting old channels
      ServiceLocator.log.d('DEBUG: Save watch history channel info...');
      final savedChannelInfo = await ServiceLocator.watchHistory.saveWatchHistoryChannelInfo(playlist.id!);
      ServiceLocator.log.d('DEBUG: Saved ${savedChannelInfo.length} watch history channel info items');

      // Use transaction for data consistency: delete old data first, then insert new data
      // If insertion fails, transaction will rollback, old data won't be lost
      await ServiceLocator.database.db.transaction((txn) async {
        // Delete existing channels
        ServiceLocator.log.d('DEBUG: Start deleting existing channel data...');
        final deleteResult = await txn.delete(
          'channels',
          where: 'playlist_id = ?',
          whereArgs: [playlist.id],
        );
        ServiceLocator.log.d('DEBUG: Deleted $deleteResult old channel records');

        // Insert new channels - Use batch insertion for performance, process in chunks to avoid memory issues
        const chunkSize = 500;
        for (int i = 0; i < channels.length; i += chunkSize) {
          final end = (i + chunkSize < channels.length) ? i + chunkSize : channels.length;
          final chunk = channels.sublist(i, end);

          final batch = txn.batch();
          for (final channel in chunk) {
            final channelMap = channel.toMap();
            batch.insert('channels', channelMap);
          }
          await batch.commit(noResult: true);
          ServiceLocator.log.d('DEBUG: Inserted $end/${channels.length} new channel records');
        }
      });

      // Update playlist timestamp and EPG URL
      ServiceLocator.log.d('DEBUG: Updating playlist timestamp and EPG URL...');
      final updateData = <String, dynamic>{
        'last_updated': DateTime.now().millisecondsSinceEpoch,
        'channel_count': channels.length,
      };

      // Update EPG URL in database if extracted
      if (_lastExtractedEpgUrl != null) {
        updateData['epg_url'] = _lastExtractedEpgUrl;
        ServiceLocator.log.d('DEBUG: Save EPG URL to database: $_lastExtractedEpgUrl');
      }

      await ServiceLocator.database.update(
        'playlists',
        updateData,
        where: 'id = ?',
        whereArgs: [playlist.id],
      );

      _importProgress = 1.0;
      ServiceLocator.log.d('DEBUG: Refresh completed, progress: 100%');
      notifyListeners();

      // Update watch history channel IDs (matching by name and URL)
      ServiceLocator.log.d('DEBUG: Start updating watch history channel IDs...');
      await ServiceLocator.watchHistory.updateChannelIdsAfterRefresh(playlist.id!, savedChannelInfo);
      ServiceLocator.log.d('DEBUG: Watch history channel ID update completed');

      // Clear redirect cache (since playlist has been updated, URLs might have changed)
      ServiceLocator.redirectCache.clearAllCache();
      ServiceLocator.log.d('Redirect cache cleared (refresh playlist)');

      // Reload playlists
      ServiceLocator.log.d('DEBUG: Reloading playlist data...');
      await loadPlaylists();

      ServiceLocator.log.d('DEBUG: Playlist refresh completed successfully');
      return true;
    } catch (e) {
      ServiceLocator.log.d('DEBUG: Error occurred while refreshing playlist: $e');
      ServiceLocator.log.d('DEBUG: Error stack: ${StackTrace.current}');
      _error = 'Failed to refresh playlist: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete a playlist
  Future<bool> deletePlaylist(int playlistId) async {
    try {
      // Find the playlist before deletion to check for temp files
      final playlist = _playlists.firstWhere((p) => p.id == playlistId, orElse: () => Playlist(name: ''));
      final wasActive = _activePlaylist?.id == playlistId;

      // Delete channels first (cascade should handle this, but being explicit)
      await ServiceLocator.database.delete(
        'channels',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );

      // Delete playlist
      await ServiceLocator.database.delete(
        'playlists',
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      // Delete temporary file if this is a temporary playlist
      if (playlist.isTemporary && playlist.filePath != null) {
        try {
          final file = File(playlist.filePath!);
          if (await file.exists()) {
            await file.delete();
            ServiceLocator.log.d('DEBUG: Deleted temporary playlist file: ${playlist.filePath}');
          }
        } catch (e) {
          ServiceLocator.log.d('DEBUG: Error deleting temporary file: $e');
        }
      }

      // Clear redirect cache (since playlist URL might be invalid)
      ServiceLocator.redirectCache.clearAllCache();
      ServiceLocator.log.d('Redirect cache cleared (delete playlist)');

      // Update local state
      _playlists.removeWhere((p) => p.id == playlistId);

      // If the deleted playlist was active, switch to the first available playlist
      if (wasActive) {
        if (_playlists.isNotEmpty) {
          _activePlaylist = _playlists.first;
          // Save the new active playlist to database
          await ServiceLocator.prefs.setInt('active_playlist_id', _activePlaylist!.id!);
          ServiceLocator.log.d('DEBUG: Switched to playlist after deletion: ${_activePlaylist!.name} (ID: ${_activePlaylist!.id})');
        } else {
          _activePlaylist = null;
          await ServiceLocator.prefs.remove('active_playlist_id');
          ServiceLocator.log.d('DEBUG: No remaining playlists');
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete playlist: $e';
      notifyListeners();
      return false;
    }
  }

  // Set active playlist
  void setActivePlaylist(Playlist playlist, {Function(int)? onPlaylistChanged, FavoritesProvider? favoritesProvider}) async {
    ServiceLocator.log.d('DEBUG: Set active playlist: ${playlist.name} (ID: ${playlist.id})');
    _activePlaylist = playlist;

    // Update database to mark this playlist as active
    if (playlist.id != null) {
      try {
        // Mark all playlists as inactive
        await ServiceLocator.database.update(
          'playlists',
          {'is_active': 0},
        );

        // Mark this playlist as active
        await ServiceLocator.database.update(
          'playlists',
          {'is_active': 1},
          where: 'id = ?',
          whereArgs: [playlist.id],
        );
      } catch (e) {
        ServiceLocator.log.d('DEBUG: Error updating database activation status: $e');
      }
    }

    // Notify listeners immediately for UI update
    notifyListeners();

    // Trigger channel loading via callback
    if (playlist.id != null && onPlaylistChanged != null) {
      try {
        ServiceLocator.log.d('DEBUG: Triggering playlist channel loading callback...');
        onPlaylistChanged(playlist.id!);
      } catch (e) {
        ServiceLocator.log.d('DEBUG: Error executing playlist channel loading callback: $e');
      }
    }

    // Update favorites provider with the new active playlist
    if (playlist.id != null && favoritesProvider != null) {
      try {
        ServiceLocator.log.d('DEBUG: Updating active playlist ID in favorites provider...');
        favoritesProvider.setActivePlaylistId(playlist.id!);
        await favoritesProvider.loadFavorites();
      } catch (e) {
        ServiceLocator.log.d('DEBUG: Error updating favorites: $e');
      }
    }
  }

  // Update playlist
  Future<bool> updatePlaylist(Playlist playlist) async {
    if (playlist.id == null) return false;

    try {
      await ServiceLocator.database.update(
        'playlists',
        playlist.toMap(),
        where: 'id = ?',
        whereArgs: [playlist.id],
      );

      final index = _playlists.indexWhere((p) => p.id == playlist.id);
      if (index != -1) {
        _playlists[index] = playlist;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update playlist: $e';
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
