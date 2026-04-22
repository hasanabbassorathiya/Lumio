import 'dart:async';
import 'service_locator.dart';

/// Auto-refresh service
/// Regularly auto-refresh playlists
class AutoRefreshService {
  static final AutoRefreshService _instance = AutoRefreshService._internal();
  factory AutoRefreshService() => _instance;
  AutoRefreshService._internal();

  Timer? _timer;
  bool _isEnabled = false;
  int _intervalHours = 24;
  DateTime? _lastRefreshTime;
  Function()? _onRefreshCallback;

  bool get isEnabled => _isEnabled;
  int get intervalHours => _intervalHours;
  DateTime? get lastRefreshTime => _lastRefreshTime;

  /// Start auto-refresh
  void start({required int intervalHours, required Function() onRefresh}) {
    stop(); // Stop existing timer first

    _isEnabled = true;
    _intervalHours = intervalHours;
    _onRefreshCallback = onRefresh;

    ServiceLocator.log.i('Starting Auto-refresh service, interval: $intervalHours hours', tag: 'AutoRefresh');

    // Set up periodic check (check once an hour)
    _timer = Timer.periodic(const Duration(hours: 1), (timer) {
      _checkAndRefresh();
    });
  }

  /// Stop auto-refresh
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isEnabled = false;
    _onRefreshCallback = null;
    ServiceLocator.log.i('Stopping Auto-refresh service', tag: 'AutoRefresh');
  }

  /// Call after playlist is loaded to check if refresh is needed
  void checkOnStartup() {
    if (!_isEnabled || _onRefreshCallback == null) {
      ServiceLocator.log.d('AutoRefresh: Service not enabled or callback not set, skipping startup check');
      return;
    }
    
    ServiceLocator.log.d('Playlist loaded, performing startup check', tag: 'AutoRefresh');
    _checkAndRefresh();
  }

  /// Check and perform refresh
  void _checkAndRefresh() {
    if (!_isEnabled || _onRefreshCallback == null) {
      ServiceLocator.log.d('AutoRefresh: Service not enabled or callback not set, skipping check');
      return;
    }

    final now = DateTime.now();
    
    ServiceLocator.log.d('AutoRefresh: Checking refresh conditions');
    ServiceLocator.log.d('AutoRefresh: Current time: $now');
    ServiceLocator.log.d('AutoRefresh: Last refresh: $_lastRefreshTime');
    ServiceLocator.log.d('AutoRefresh: Refresh interval: $_intervalHours hours');
    
    // If never refreshed before, set current time as last refresh time
    if (_lastRefreshTime == null) {
      ServiceLocator.log.d('First run, set initial refresh time', tag: 'AutoRefresh');
      _lastRefreshTime = now;
      _saveLastRefreshTime();
      return;
    }

    // Check if refresh interval has passed
    final hoursSinceLastRefresh = now.difference(_lastRefreshTime!).inHours;
    ServiceLocator.log.d('AutoRefresh: $hoursSinceLastRefresh hours since last refresh');

    if (hoursSinceLastRefresh >= _intervalHours) {
      ServiceLocator.log.i('Refresh interval exceeded ($hoursSinceLastRefresh hours >= $_intervalHours hours), triggering auto-refresh', tag: 'AutoRefresh');
      _lastRefreshTime = now;
      _saveLastRefreshTime();
      _onRefreshCallback!();
    } else {
      final remainingHours = _intervalHours - hoursSinceLastRefresh;
      ServiceLocator.log.d('Refresh time not reached, still need to wait $remainingHours hours', tag: 'AutoRefresh');
    }
  }

  /// Load last refresh time from local storage
  Future<void> loadLastRefreshTime() async {
    try {
      final timestamp = ServiceLocator.prefs.getInt('last_auto_refresh_time');
      if (timestamp != null) {
        _lastRefreshTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        ServiceLocator.log.d('Loaded last refresh time: $_lastRefreshTime', tag: 'AutoRefresh');
      }
    } catch (e) {
      ServiceLocator.log.e('Failed to load last refresh time', tag: 'AutoRefresh', error: e);
    }
  }

  /// Save last refresh time to local storage
  Future<void> _saveLastRefreshTime() async {
    try {
      if (_lastRefreshTime != null) {
        await ServiceLocator.prefs.setInt(
          'last_auto_refresh_time',
          _lastRefreshTime!.millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      ServiceLocator.log.d('AutoRefresh: Failed to save refresh time: $e');
    }
  }

  /// Manually trigger refresh (reset timer)
  void manualRefresh() {
    _lastRefreshTime = DateTime.now();
    _saveLastRefreshTime();
    ServiceLocator.log.d('AutoRefresh: Manual refresh, reset timer');
  }

  /// Get remaining time until next refresh (hours)
  int? getHoursUntilNextRefresh() {
    if (_lastRefreshTime == null || !_isEnabled) return null;
    
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefreshTime!).inHours;
    final remaining = _intervalHours - elapsed;
    
    return remaining > 0 ? remaining : 0;
  }
}
