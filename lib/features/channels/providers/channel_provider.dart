import 'package:flutter/foundation.dart';
import '../../../core/models/channel.dart';
import '../../../core/models/channel_group.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/channel_logo_widget.dart';

class ChannelProvider extends ChangeNotifier {
  List<Channel> _channels = [];
  List<ChannelGroup> _groups = [];
  String? _selectedGroup;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Channel> get channels => _channels;
  List<ChannelGroup> get groups => _groups;
  String? get selectedGroup => _selectedGroup;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Channel> get filteredChannels {
    if (_selectedGroup == null) return _channels;
    // If invalid channel group is selected, return all invalid channels
    if (_selectedGroup == unavailableGroupName) {
      return _channels.where((c) => isUnavailableChannel(c.groupName)).toList();
    }
    return _channels.where((c) => c.groupName == _selectedGroup).toList();
  }

  int get totalChannelCount => _channels.length;

  // Load channels for a specific playlist
  Future<void> loadChannels(int playlistId) async {
    ServiceLocator.log.i('Loading playlist channels: $playlistId', tag: 'ChannelProvider');
    final startTime = DateTime.now();
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await ServiceLocator.database.query(
        'channels',
        where: 'playlist_id = ? AND is_active = 1',
        whereArgs: [playlistId],
        orderBy: 'id ASC',
      );

      _channels = results.map((r) => Channel.fromMap(r)).toList();
      ServiceLocator.log.d('Loaded ${_channels.length} channels', tag: 'ChannelProvider');

      _updateGroups();
      
      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i('Channel loading completed, time taken: ${loadTime}ms', tag: 'ChannelProvider');
      _error = null;
    } catch (e) {
      ServiceLocator.log.e('Failed to load channels', tag: 'ChannelProvider', error: e);
      _error = 'Failed to load channels: $e';
      _channels = [];
      _groups = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load all channels from all active playlists
  Future<void> loadAllChannels() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await ServiceLocator.database.rawQuery('''
        SELECT c.* FROM channels c
        INNER JOIN playlists p ON c.playlist_id = p.id
        WHERE c.is_active = 1 AND p.is_active = 1
        ORDER BY c.id ASC
      ''');

      _channels = results.map((r) => Channel.fromMap(r)).toList();

      _updateGroups();
      _error = null;
    } catch (e) {
      _error = 'Failed to load channels: $e';
      _channels = [];
      _groups = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void _updateGroups() {
    final Map<String, int> groupCounts = {};
    final List<String> groupOrder = []; // Keep original order
    int unavailableCount = 0;

    for (final channel in _channels) {
      final group = channel.groupName ?? 'Uncategorized';
      // Merge all invalid channels into one group
      if (isUnavailableChannel(group)) {
        unavailableCount++;
      } else {
        if (!groupCounts.containsKey(group)) {
          groupOrder.add(group); // Record order of first appearance
        }
        groupCounts[group] = (groupCounts[group] ?? 0) + 1;
      }
    }

    // Create group list in original order
    _groups = groupOrder.map((name) => ChannelGroup(name: name, channelCount: groupCounts[name] ?? 0)).toList();

    // If there are invalid channels, add to the end of the list
    if (unavailableCount > 0) {
      _groups.add(ChannelGroup(name: unavailableGroupName, channelCount: unavailableCount));
    }
  }

  // Select a group filter
  void selectGroup(String? groupName) {
    _selectedGroup = groupName;
    
    // Clear logo loading queue when switching categories to avoid buildup
    try {
      clearLogoLoadingQueue();
      ServiceLocator.log.d('Switch category to: $groupName, logo loading queue cleared');
    } catch (e) {
      ServiceLocator.log.w('Failed to clear logo queue: $e');
    }
    
    notifyListeners();
  }

  // Clear group filter
  void clearGroupFilter() {
    _selectedGroup = null;
    notifyListeners();
  }

  // Search channels by name
  List<Channel> searchChannels(String query) {
    if (query.isEmpty) return filteredChannels;

    final lowerQuery = query.toLowerCase();
    return _channels.where((c) {
      return c.name.toLowerCase().contains(lowerQuery) || (c.groupName?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // Get channels by group
  List<Channel> getChannelsByGroup(String groupName) {
    return _channels.where((c) => c.groupName == groupName).toList();
  }

  // Get a channel by ID
  Channel? getChannelById(int id) {
    try {
      return _channels.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Update favorite status for a channel
  void updateFavoriteStatus(int channelId, bool isFavorite) {
    final index = _channels.indexWhere((c) => c.id == channelId);
    if (index != -1) {
      _channels[index] = _channels[index].copyWith(isFavorite: isFavorite);
      notifyListeners();
    }
  }

  // Set currently playing channel
  void setCurrentlyPlaying(int? channelId) {
    for (int i = 0; i < _channels.length; i++) {
      final isPlaying = _channels[i].id == channelId;
      if (_channels[i].isCurrentlyPlaying != isPlaying) {
        _channels[i] = _channels[i].copyWith(isCurrentlyPlaying: isPlaying);
      }
    }
    notifyListeners();
  }

  // Add channels from parsing
  Future<void> addChannels(List<Channel> channels) async {
    try {
      for (final channel in channels) {
        await ServiceLocator.database.insert('channels', channel.toMap());
      }

      // Reload channels
      if (channels.isNotEmpty) {
        await loadChannels(channels.first.playlistId);
      }
    } catch (e) {
      _error = 'Failed to add channels: $e';
      notifyListeners();
    }
  }

  // Delete channels for a playlist
  Future<void> deleteChannelsForPlaylist(int playlistId) async {
    try {
      await ServiceLocator.database.delete(
        'channels',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );

      _channels.removeWhere((c) => c.playlistId == playlistId);
      _updateGroups();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete channels: $e';
      notifyListeners();
    }
  }

  // Invalid channel category name prefix
  static const String unavailableGroupPrefix = '⚠️ Invalid Channels';
  static const String unavailableGroupName = '⚠️ Invalid Channels';

  // Extract original group name from invalid group name
  static String? extractOriginalGroup(String? groupName) {
    if (groupName == null || !groupName.startsWith(unavailableGroupPrefix)) {
      return null;
    }
    // Format: "⚠️ Invalid Channels|Original Group Name"
    final parts = groupName.split('|');
    if (parts.length > 1) {
      return parts[1];
    }
    return 'Uncategorized';
  }

  // Check if it is an invalid channel
  static bool isUnavailableChannel(String? groupName) {
    return groupName != null && groupName.startsWith(unavailableGroupPrefix);
  }

  // Mark channel as invalid (move to invalid category, keep original group info)
  Future<void> markChannelsAsUnavailable(List<int> channelIds) async {
    if (channelIds.isEmpty) return;

    try {
      // Batch update channel groups, save original group name
      for (final id in channelIds) {
        final channel = _channels.firstWhere((c) => c.id == id, orElse: () => _channels.first);
        final originalGroup = channel.groupName ?? 'Uncategorized';
        // If already an invalid channel, do not mark again
        if (isUnavailableChannel(originalGroup)) continue;

        final newGroupName = '$unavailableGroupPrefix|$originalGroup';

        await ServiceLocator.database.update(
          'channels',
          {'group_name': newGroupName},
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      // Update channel data in memory
      for (int i = 0; i < _channels.length; i++) {
        if (channelIds.contains(_channels[i].id)) {
          final originalGroup = _channels[i].groupName ?? 'Uncategorized';
          if (!isUnavailableChannel(originalGroup)) {
            _channels[i] = _channels[i].copyWith(
              groupName: '$unavailableGroupPrefix|$originalGroup',
            );
          }
        }
      }

      _updateGroups();
      notifyListeners();

      ServiceLocator.log.d('DEBUG: Marked ${channelIds.length} channelsas invalid');
    } catch (e) {
      ServiceLocator.log.d('DEBUG: Error marking invalid channels: $e');
      _error = 'Failed to mark channels as unavailable: $e';
      notifyListeners();
    }
  }

  // Restore invalid channel to original group
  Future<bool> restoreChannel(int channelId) async {
    try {
      final channel = _channels.firstWhere((c) => c.id == channelId);
      final originalGroup = extractOriginalGroup(channel.groupName);

      if (originalGroup == null) {
        ServiceLocator.log.d('DEBUG: Channel is not an invalid channel, no need to restore');
        return false;
      }

      await ServiceLocator.database.update(
        'channels',
        {'group_name': originalGroup},
        where: 'id = ?',
        whereArgs: [channelId],
      );

      final index = _channels.indexWhere((c) => c.id == channelId);
      if (index != -1) {
        _channels[index] = _channels[index].copyWith(groupName: originalGroup);
      }

      _updateGroups();
      notifyListeners();

      ServiceLocator.log.d('DEBUG: Restored channel to group: $originalGroup');
      return true;
    } catch (e) {
      _error = 'Failed to restore channel: $e';
      notifyListeners();
      return false;
    }
  }

  // Delete all invalid channels
  Future<int> deleteAllUnavailableChannels() async {
    try {
      final count = await ServiceLocator.database.delete(
        'channels',
        where: 'group_name LIKE ?',
        whereArgs: ['$unavailableGroupPrefix%'],
      );

      _channels.removeWhere((c) => isUnavailableChannel(c.groupName));
      _updateGroups();
      notifyListeners();

      ServiceLocator.log.d('DEBUG: Deleted $count invalid channels');
      return count;
    } catch (e) {
      _error = 'Failed to delete unavailable channels: $e';
      notifyListeners();
      return 0;
    }
  }

  // Get number of invalid channels
  int get unavailableChannelCount {
    return _channels.where((c) => isUnavailableChannel(c.groupName)).length;
  }

  // Clear all data
  void clear() {
    _channels = [];
    _groups = [];
    _selectedGroup = null;
    _error = null;
    notifyListeners();
  }
}
