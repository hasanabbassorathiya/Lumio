import '../database/database_helper.dart';
import '../models/channel.dart';
import '../services/service_locator.dart';

class WatchHistoryService {
  final DatabaseHelper _db = ServiceLocator.database;

  /// Add watch history
  Future<void> addWatchHistory(int channelId, int playlistId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check if a record for this channel already exists
      final existing = await _db.rawQuery('''
        SELECT id FROM watch_history 
        WHERE channel_id = ? AND playlist_id = ?
      ''', [channelId, playlistId]);
      
      if (existing.isNotEmpty) {
        // Update existing record timestamp
        await _db.update(
          'watch_history',
          {'watched_at': now},
          where: 'channel_id = ? AND playlist_id = ?',
          whereArgs: [channelId, playlistId],
        );
      } else {
        // Insert new record
        await _db.insert('watch_history', {
          'channel_id': channelId,
          'playlist_id': playlistId,
          'watched_at': now,
          'duration_seconds': 0,
        });
      }
    } catch (e) {
      ServiceLocator.log.e('Failed to add watch history: $e', tag: 'WatchHistoryService');
    }
  }

  /// Get watch history (grouped by playlist)
  /// limit parameter controls the maximum number of records returned, default is 20
  Future<List<Channel>> getWatchHistory(int playlistId, {int limit = 20}) async {
    try {
      // Use INNER JOIN to query watch history and corresponding channel info
      // Only return existing and active channels, ordered by watch time descending, limit count
      final result = await _db.rawQuery('''
        SELECT c.*, wh.watched_at
        FROM watch_history wh
        INNER JOIN channels c ON wh.channel_id = c.id
        WHERE wh.playlist_id = ? AND c.is_active = 1 AND c.playlist_id = ?
        ORDER BY wh.watched_at DESC
        LIMIT ?
      ''', [playlistId, playlistId, limit]);

      return result.map((row) {
        return Channel(
          id: row['id'] as int,
          name: row['name'] as String,
          url: row['url'] as String,
          logoUrl: row['logo_url'] as String?,
          groupName: row['group_name'] as String?,
          epgId: row['epg_id'] as String?,
          sources: _parseSources(row['sources'] as String?),
          playlistId: row['playlist_id'] as int,
          isActive: (row['is_active'] as int) == 1,
          createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        );
      }).toList();
    } catch (e, stackTrace) {
      ServiceLocator.log.e('Failed to get watch history: $e\n$stackTrace', tag: 'WatchHistoryService');
      return [];
    }
  }

  /// Get watch history for all playlists (used for home screen)
  Future<List<Channel>> getAllWatchHistory({int limit = 20}) async {
    try {
      final result = await _db.rawQuery('''
        SELECT c.*, wh.watched_at, p.name as playlist_name
        FROM watch_history wh
        INNER JOIN channels c ON wh.channel_id = c.id
        INNER JOIN playlists p ON wh.playlist_id = p.id
        WHERE c.is_active = 1 AND p.is_active = 1
        ORDER BY wh.watched_at DESC
        LIMIT ?
      ''', [limit]);

      return result.map((row) {
        return Channel(
          id: row['id'] as int,
          name: row['name'] as String,
          url: row['url'] as String,
          logoUrl: row['logo_url'] as String?,
          groupName: row['group_name'] as String?,
          epgId: row['epg_id'] as String?,
          sources: _parseSources(row['sources'] as String?),
          playlistId: row['playlist_id'] as int,
          isActive: (row['is_active'] as int) == 1,
          createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        );
      }).toList();
    } catch (e) {
      ServiceLocator.log.e('Failed to get all watch history: $e');
      return [];
    }
  }

  /// Clear watch history for a specific playlist
  Future<void> clearWatchHistory(int playlistId) async {
    try {
      await _db.delete(
        'watch_history',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );
      ServiceLocator.log.d('Cleared watch history for playlist$playlistId');
    } catch (e) {
      ServiceLocator.log.e('Failed to clear watch history: $e');
    }
  }

  /// Clear all watch history
  Future<void> clearAllWatchHistory() async {
    try {
      await _db.delete('watch_history');
      ServiceLocator.log.d('All watch history cleared');
    } catch (e) {
      ServiceLocator.log.e('Failed to clear all watch history: $e');
    }
  }

  /// Save watch history channel info before refreshing playlist
  /// Returns a Map where key is history ID and value is channel name and URL
  Future<Map<int, Map<String, String>>> saveWatchHistoryChannelInfo(int playlistId) async {
    try {
      ServiceLocator.log.i('Saving watch history channel info for playlist $playlistId', tag: 'WatchHistoryService');

      // Get watch history records and their corresponding channel info
      final historyRecords = await _db.rawQuery('''
        SELECT wh.id, c.name, c.url
        FROM watch_history wh
        INNER JOIN channels c ON wh.channel_id = c.id
        WHERE wh.playlist_id = ?
      ''', [playlistId]);

      final Map<int, Map<String, String>> channelInfo = {};
      for (final record in historyRecords) {
        final historyId = record['id'] as int;
        final name = record['name'] as String;
        final url = record['url'] as String;
        channelInfo[historyId] = {'name': name, 'url': url};
      }

      ServiceLocator.log.i('Saved ${channelInfo.length} watch history channel info records', tag: 'WatchHistoryService');
      return channelInfo;
    } catch (e) {
      ServiceLocator.log.e('Failed to save watch history channel info: $e', tag: 'WatchHistoryService');
      return {};
    }
  }

  /// Update watch history channel IDs after playlist refresh
  /// Match new channel IDs using previously saved channel info
  Future<void> updateChannelIdsAfterRefresh(
    int playlistId,
    Map<int, Map<String, String>> savedChannelInfo,
  ) async {
    try {
      ServiceLocator.log.i('Starting to update watch history channel IDs for playlist $playlistId', tag: 'WatchHistoryService');

      // 1. Delete old records exceeding 20
      final countResult = await _db.rawQuery('''
        SELECT COUNT(*) as count FROM watch_history WHERE playlist_id = ?
      ''', [playlistId]);
      final count = countResult.first['count'] as int;

      if (count > 20) {
        // Get IDs of the latest 20 records to keep
        final keepIds = await _db.rawQuery('''
          SELECT id FROM watch_history
          WHERE playlist_id = ?
          ORDER BY watched_at DESC
          LIMIT 20
        ''', [playlistId]);

        final keepIdList = keepIds.map((row) => row['id'] as int).join(',');

        // Delete records not in the keep list
        await _db.rawQuery('''
          DELETE FROM watch_history
          WHERE playlist_id = ? AND id NOT IN ($keepIdList)
        ''', [playlistId]);

        ServiceLocator.log.i('Deleted ${count - 20} old watch history records', tag: 'WatchHistoryService');
      }

      int updatedCount = 0;
      int deletedCount = 0;

      // 2. Iterate through saved channel info, update or delete watch history
      for (final entry in savedChannelInfo.entries) {
        final historyId = entry.key;
        final channelName = entry.value['name']!;
        final channelUrl = entry.value['url']!;

        // Check if this watch history record still exists (might have been deleted in step 1)
        final historyExists = await _db.rawQuery('''
          SELECT id FROM watch_history WHERE id = ?
        ''', [historyId]);

        if (historyExists.isEmpty) {
          // Watch history record deleted (exceeding 20), skipping
          continue;
        }

        // Find new channel ID by name and URL
        final newChannels = await _db.rawQuery('''
          SELECT id FROM channels
          WHERE name = ? AND url = ? AND playlist_id = ? AND is_active = 1
          LIMIT 1
        ''', [channelName, channelUrl, playlistId]);

        if (newChannels.isNotEmpty) {
          final newChannelId = newChannels.first['id'] as int;

          // Update channel ID
          await _db.update(
            'watch_history',
            {'channel_id': newChannelId},
            where: 'id = ?',
            whereArgs: [historyId],
          );
          updatedCount++;
        } else {
          // Channel no longer exists, deleting this watch history record
          await _db.delete(
            'watch_history',
            where: 'id = ?',
            whereArgs: [historyId],
          );
          deletedCount++;
          ServiceLocator.log.d('Deleting watch history record $historyId (channel "$channelName" does not exist)', tag: 'WatchHistoryService');
        }
      }

      ServiceLocator.log.i('Watch history update complete: updated $updatedCount records, deleted $deletedCount records (channel does not exist)', tag: 'WatchHistoryService');
    } catch (e) {
      ServiceLocator.log.e('Failed to update watch history channel ID: $e', tag: 'WatchHistoryService');
    }
  }

  /// Clean up watch history (delete old records exceeding 20)
  /// Clean up watch history after playlist refresh
  /// Only delete old records exceeding 20, keep latest 20
  Future<void> cleanupWatchHistoryAfterRefresh(int playlistId) async {
    try {
      ServiceLocator.log.i('Starting cleanup of watch history for playlist $playlistId', tag: 'WatchHistoryService');

      // Delete old records exceeding 20
      final countResult = await _db.rawQuery('''
        SELECT COUNT(*) as count FROM watch_history WHERE playlist_id = ?
      ''', [playlistId]);
      final count = countResult.first['count'] as int;

      if (count > 20) {
        // Get IDs of the latest 20 records to keep
        final keepIds = await _db.rawQuery('''
          SELECT id FROM watch_history
          WHERE playlist_id = ?
          ORDER BY watched_at DESC
          LIMIT 20
        ''', [playlistId]);

        final keepIdList = keepIds.map((row) => row['id'] as int).join(',');

        // Delete records not in the keep list
        await _db.rawQuery('''
          DELETE FROM watch_history
          WHERE playlist_id = ? AND id NOT IN ($keepIdList)
        ''', [playlistId]);

        ServiceLocator.log.i('Deleted ${count - 20} old watch history records, kept latest 20', tag: 'WatchHistoryService');
      } else {
        ServiceLocator.log.i('Watch history count $count <= 20, no cleanup needed', tag: 'WatchHistoryService');
      }
    } catch (e) {
      ServiceLocator.log.e('Failed to clean up watch history: $e', tag: 'WatchHistoryService');
    }
  }

  /// Parse multi-source string
  List<String> _parseSources(String? sourcesStr) {
    if (sourcesStr == null || sourcesStr.isEmpty) return [];
    try {
      // Assume sources are comma-separated string
      return sourcesStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }
}