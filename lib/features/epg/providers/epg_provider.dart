import 'package:flutter/foundation.dart';
import '../../../core/services/epg_service.dart';
import '../../../core/services/service_locator.dart';

class EpgProvider extends ChangeNotifier {
  final EpgService _epgService = EpgService();

  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdate;

  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastUpdate => _lastUpdate ?? _epgService.lastUpdate;
  bool get hasData => _epgService.lastUpdate != null;

  EpgProvider() {
    _loadEpgIfEnabled();
  }

  Future<void> _loadEpgIfEnabled() async {
    final prefs = ServiceLocator.prefs;
    final enabled = prefs.getBool('enable_epg') ?? true;
    final url = prefs.getString('epg_url');

    if (enabled && url != null && url.isNotEmpty) {
      await loadEpg(url);
    }
  }

  Future<bool> loadEpg(String url, {String? fallbackUrl}) async {
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try primary URL first
      ServiceLocator.log.d('EPG: Attempting to load from primary URL: $url');
      final success = await _epgService.loadFromUrl(url);
      
      if (success) {
        _lastUpdate = DateTime.now();
        ServiceLocator.log.d('EPG: Successfully loaded from primary URL');
        return true;
      }
      
      // If primary failed and fallback is available, try fallback
      if (fallbackUrl != null && fallbackUrl.isNotEmpty && fallbackUrl != url) {
        ServiceLocator.log.d('EPG: Primary URL failed, trying fallback URL: $fallbackUrl');
        final fallbackSuccess = await _epgService.loadFromUrl(fallbackUrl);
        
        if (fallbackSuccess) {
          _lastUpdate = DateTime.now();
          ServiceLocator.log.d('EPG: Successfully loaded from fallback URL');
          return true;
        }
      }
      
      _error = 'Failed to load EPG data from all sources';
      return false;
    } catch (e) {
      _error = e.toString();
      ServiceLocator.log.d('EPG: Error loading: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get current program for channel
  EpgProgram? getCurrentProgram(String? channelId, String? channelName) {
    return _epgService.getCurrentProgram(channelId, channelName);
  }

  /// Get next program for channel
  EpgProgram? getNextProgram(String? channelId, String? channelName) {
    return _epgService.getNextProgram(channelId, channelName);
  }

  /// Get today's program list for channel
  List<EpgProgram> getTodayPrograms(String? channelId, String? channelName) {
    return _epgService.getTodayPrograms(channelId, channelName);
  }

  void clear() {
    _epgService.clear();
    _lastUpdate = null;
    _error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    final prefs = ServiceLocator.prefs;
    final url = prefs.getString('epg_url');
    if (url != null && url.isNotEmpty) {
      await loadEpg(url);
    }
  }
}
