import 'package:flutter/foundation.dart';
import '../../../core/services/dlna_service.dart';
import '../../../core/services/service_locator.dart';

/// DLNA Service State Management
class DlnaProvider extends ChangeNotifier {
  final DlnaService _dlnaService = DlnaService();
  static const String _keyDlnaEnabled = 'dlna_enabled';

  bool _isEnabled = false;
  bool _isRunning = false;
  bool _isActiveSession = false; // Whether there is an active DLNA casting session
  String? _pendingUrl;
  String? _pendingTitle;

  bool get isEnabled => _isEnabled;
  bool get isRunning => _isRunning;
  bool get isActiveSession => _isActiveSession; // Whether DLNA casting is in progress
  String get deviceName => _dlnaService.deviceName;
  String? get pendingUrl => _pendingUrl;
  String? get pendingTitle => _pendingTitle;

  // Playback callbacks (set externally)
  Function(String url, String? title)? onPlayRequested;
  Function()? onPauseRequested;
  Function()? onStopRequested;
  Function(Duration position)? onSeekRequested;
  Function(int volume)? onVolumeRequested;

  DlnaProvider() {
    _setupCallbacks();
    // Asynchronously start DLNA service in the background
    Future.microtask(() => _autoStart());
  }

  /// Automatically start DLNA service (if previously enabled)
  Future<void> _autoStart() async {
    try {
      final prefs = ServiceLocator.prefs;
      // Print all SharedPreferences keys for debugging
      final allKeys = prefs.getKeys();
      ServiceLocator.log.d('SharedPreferences keys = $allKeys', tag: 'DLNA');

      final wasEnabled = prefs.getBool(_keyDlnaEnabled) ?? false;
      ServiceLocator.log.d('Checking auto-start status - key=$_keyDlnaEnabled, wasEnabled=$wasEnabled', tag: 'DLNA');

      if (wasEnabled) {
        ServiceLocator.log.d('Auto-starting service in background...', tag: 'DLNA');
        final success = await setEnabled(true);
        ServiceLocator.log.d('Auto-start ${success ? "successful" : "failed"}', tag: 'DLNA');
      }
    } catch (e, stack) {
      ServiceLocator.log.e('DLNA: Auto-start failed - $e');
      ServiceLocator.log.e('DLNA: Stack trace - $stack');
    }
  }

  void _setupCallbacks() {
    _dlnaService.onPlayUrl = (url, title) {
      _pendingUrl = url;
      _pendingTitle = title;
      _isActiveSession = true;
      notifyListeners();
      onPlayRequested?.call(url, title);
    };

    _dlnaService.onPause = () {
      onPauseRequested?.call();
    };

    _dlnaService.onStop = () {
      _pendingUrl = null;
      _pendingTitle = null;
      _isActiveSession = false;
      notifyListeners();
      onStopRequested?.call();
    };

    _dlnaService.onSetVolume = (volume) {
      onVolumeRequested?.call(volume);
    };

    _dlnaService.onSeek = (position) {
      onSeekRequested?.call(position);
    };
  }

  /// Enable/Disable DLNA service
  Future<bool> setEnabled(bool enabled) async {
    if (enabled == _isEnabled) return true;

    if (enabled) {
      final success = await _dlnaService.start();
      if (success) {
        _isEnabled = true;
        _isRunning = true;
        // Save enabled state
        try {
          final prefs = ServiceLocator.prefs;
          await prefs.setBool(_keyDlnaEnabled, true);
          ServiceLocator.log.d('Enabled state saved - key=$_keyDlnaEnabled, value=true', tag: 'DLNA');
          // Verify if save was successful
          final saved = prefs.getBool(_keyDlnaEnabled);
          ServiceLocator.log.d('Verify save result - saved=$saved', tag: 'DLNA');
        } catch (e) {
          ServiceLocator.log.d('Failed to save enabled state - $e', tag: 'DLNA');
        }
        notifyListeners();
        return true;
      }
      return false;
    } else {
      await _dlnaService.stop();
      _isEnabled = false;
      _isRunning = false;
      _isActiveSession = false;
      _pendingUrl = null;
      _pendingTitle = null;
      // Save disabled state
      try {
        final prefs = ServiceLocator.prefs;
        await prefs.setBool(_keyDlnaEnabled, false);
        ServiceLocator.log.d('Disabled state saved - key=$_keyDlnaEnabled, value=false', tag: 'DLNA');
      } catch (e) {
        ServiceLocator.log.d('Failed to save disabled state - $e', tag: 'DLNA');
      }
      notifyListeners();
      return true;
    }
  }

  /// Update playback state (called by PlayerProvider)
  void updatePlayState({
    String? state,
    Duration? position,
    Duration? duration,
  }) {
    _dlnaService.updatePlayState(
      state: state,
      position: position,
      duration: duration,
    );
  }

  /// Notify DLNA service that playback has stopped (called on active exit)
  void notifyPlaybackStopped() {
    _dlnaService.updatePlayState(state: 'STOPPED');
    _pendingUrl = null;
    _pendingTitle = null;
    _isActiveSession = false;
    notifyListeners();
  }

  /// Sync player state to DLNA (called periodically)
  void syncPlayerState({
    required bool isPlaying,
    required bool isPaused,
    required Duration position,
    required Duration duration,
  }) {
    String state;
    if (isPlaying) {
      state = 'PLAYING';
    } else if (isPaused) {
      state = 'PAUSED_PLAYBACK';
    } else {
      state = 'STOPPED';
    }

    _dlnaService.updatePlayState(
      state: state,
      position: position,
      duration: duration,
    );
  }

  /// Clear pending content
  void clearPending() {
    _pendingUrl = null;
    _pendingTitle = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _dlnaService.stop();
    super.dispose();
  }
}
