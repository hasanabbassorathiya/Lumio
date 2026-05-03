import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/log_service.dart';

class SettingsProvider extends ChangeNotifier {
  // Keys for SharedPreferences
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyAutoRefresh = 'auto_refresh';
  static const String _keyRefreshInterval = 'refresh_interval';
  static const String _keyDefaultQuality = 'default_quality';
  static const String _keyHardwareDecoding = 'hardware_decoding';
  static const String _keyDecodingMode = 'decoding_mode'; // New: auto, hardware, software
  static const String _keyBufferSize = 'buffer_size';
  static const String _keyLastPlaylistId = 'last_playlist_id';
  static const String _keyEnableEpg = 'enable_epg';
  static const String _keyEpgUrl = 'epg_url';
  static const String _keyParentalControl = 'parental_control';
  static const String _keyParentalPin = 'parental_pin';
  static const String _keyAutoPlay = 'auto_play';
  static const String _keyRememberLastChannel = 'remember_last_channel';
  static const String _keyLastChannelId = 'last_channel_id';
  static const String _keyLocale = 'locale';
  static const String _keyVolumeNormalization = 'volume_normalization';
  static const String _keyVolumeBoost = 'volume_boost';
  static const String _keyBufferStrength = 'buffer_strength'; // fast, balanced, stable
  static const String _keyShowFps = 'show_fps';
  static const String _keyShowClock = 'show_clock';
  static const String _keyShowNetworkSpeed = 'show_network_speed';
  static const String _keyShowVideoInfo = 'show_video_info';
  static const String _keyProgressBarMode = 'progress_bar_mode'; // auto, always, never
  static const String _keyEnableMultiScreen = 'enable_multi_screen';
  static const String _keyDefaultScreenPosition = 'default_screen_position';
  static const String _keyActiveScreenIndex = 'active_screen_index';
  static const String _keyLastPlayMode = 'last_play_mode'; // 'single' or 'multi'
  static const String _keyLastMultiScreenChannels = 'last_multi_screen_channels'; // JSON string of channel IDs
  static const String _keyShowMultiScreenChannelName = 'show_multi_screen_channel_name'; // Whether to show channel name in multi-screen playback
  static const String _keyDarkColorScheme = 'dark_color_scheme';
  static const String _keyLightColorScheme = 'light_color_scheme';
  static const String _keyFontFamily = 'font_family';
  static const String _keySimpleMenu = 'simple_menu';
  static const String _keyLogLevel = 'log_level'; // debug, release, off
  static const String _keyMobileOrientation = 'mobile_orientation'; // portrait, landscape, auto
  static const String _keyLastAppVersion = 'last_app_version'; // Used for detecting version updates

  // Settings values
  String _themeMode = 'dark';
  bool _autoRefresh = false;
  int _refreshInterval = 24; // hours
  String _defaultQuality = 'auto';
  bool _hardwareDecoding = true;
  String _decodingMode = 'auto'; // New: auto, hardware, software
  int _bufferSize = 30; // seconds
  int? _lastPlaylistId;
  bool _enableEpg = true;
  String? _epgUrl;
  bool _parentalControl = false;
  String? _parentalPin;
  bool _autoPlay = false;
  bool _rememberLastChannel = true;
  int? _lastChannelId;
  Locale? _locale;
  bool _volumeNormalization = false;
  int _volumeBoost = 0; // -20 to +20 dB
  String _bufferStrength = 'fast'; // fast, balanced, stable
  bool _showFps = true; // Display FPS by default
  bool _showClock = true; // Display clock by default
  bool _showNetworkSpeed = true; // Display network speed by default
  bool _showVideoInfo = true; // Display resolution and bitrate by default
  String _progressBarMode = 'auto'; // Progress bar display mode: auto, always, never
  bool _enableMultiScreen = false; // Multi-screen disabled by default
  int _defaultScreenPosition = 1; // Default playback position (top-left)
  int _activeScreenIndex = 0; // Current active window index
  String _lastPlayMode = 'single'; // Last playback mode: 'single' or 'multi'
  List<int?> _lastMultiScreenChannels = [null, null, null, null]; // Multi-screen channel ID list
  bool _showMultiScreenChannelName = false; // Whether to show channel name in multi-screen playback (default off)
  String _darkColorScheme = 'lumio'; // Dark mode color scheme (default lumio)
  String _lightColorScheme = 'lumio-light'; // Light mode color scheme (default lumio-light)
  String _fontFamily = 'Arial'; // Font setting (default Arial, English environment)
  bool _simpleMenu = true; // Whether to use simple menu bar (no expansion) - default enabled
  String _logLevel = 'off'; // Log level: debug, release, off - default off
  String _mobileOrientation = 'portrait'; // Mobile screen orientation: portrait, landscape, auto - default portrait

  // Getters
  String get themeMode => _themeMode;
  bool get autoRefresh => _autoRefresh;
  int get refreshInterval => _refreshInterval;
  String get defaultQuality => _defaultQuality;
  bool get hardwareDecoding => _hardwareDecoding;
  String get decodingMode => _decodingMode;
  int get bufferSize => _bufferSize;
  int? get lastPlaylistId => _lastPlaylistId;
  bool get enableEpg => _enableEpg;
  String? get epgUrl => _epgUrl;
  bool get parentalControl => _parentalControl;
  bool get autoPlay => _autoPlay;
  bool get rememberLastChannel => _rememberLastChannel;
  int? get lastChannelId => _lastChannelId;
  Locale? get locale => _locale;
  bool get volumeNormalization => _volumeNormalization;
  int get volumeBoost => _volumeBoost;
  String get bufferStrength => _bufferStrength;
  bool get showFps => _showFps;
  bool get showClock => _showClock;
  bool get showNetworkSpeed => _showNetworkSpeed;
  bool get showVideoInfo => _showVideoInfo;
  String get progressBarMode => _progressBarMode;
  bool get enableMultiScreen => _enableMultiScreen;
  int get defaultScreenPosition => _defaultScreenPosition;
  int get activeScreenIndex => _activeScreenIndex;
  String get lastPlayMode => _lastPlayMode;
  List<int?> get lastMultiScreenChannels => _lastMultiScreenChannels;
  bool get showMultiScreenChannelName => _showMultiScreenChannelName;
  String get darkColorScheme => _darkColorScheme;
  String get lightColorScheme => _lightColorScheme;
  String get fontFamily => _fontFamily;
  bool get simpleMenu => _simpleMenu;
  String get logLevel => _logLevel;
  String get mobileOrientation => _mobileOrientation;
  
  /// Get the color scheme that should be currently used
  String get currentColorScheme {
    if (_themeMode == 'dark') return _darkColorScheme;
    if (_themeMode == 'light') return _lightColorScheme;
    // When following system, decide based on system brightness
    // Return dark mode scheme as default, actual decision made at UI layer
    return _darkColorScheme;
  }

  SettingsProvider() {
    _loadSettings();
    _checkVersionUpdate();
  }

  void _loadSettings() {
    final prefs = ServiceLocator.prefs;

    _themeMode = prefs.getString(_keyThemeMode) ?? 'dark';
    _autoRefresh = prefs.getBool(_keyAutoRefresh) ?? false;
    _refreshInterval = prefs.getInt(_keyRefreshInterval) ?? 24;
    _defaultQuality = prefs.getString(_keyDefaultQuality) ?? 'auto';
    _hardwareDecoding = prefs.getBool(_keyHardwareDecoding) ?? true;
    _decodingMode = prefs.getString(_keyDecodingMode) ?? 'auto';
    _bufferSize = prefs.getInt(_keyBufferSize) ?? 30;
    _lastPlaylistId = prefs.getInt(_keyLastPlaylistId);
    _enableEpg = prefs.getBool(_keyEnableEpg) ?? true;
    _epgUrl = prefs.getString(_keyEpgUrl);
    _parentalControl = prefs.getBool(_keyParentalControl) ?? false;
    _parentalPin = prefs.getString(_keyParentalPin);
    _autoPlay = prefs.getBool(_keyAutoPlay) ?? false;
    _rememberLastChannel = prefs.getBool(_keyRememberLastChannel) ?? true;
    _lastChannelId = prefs.getInt(_keyLastChannelId);

    final localeCode = prefs.getString(_keyLocale);
    if (localeCode != null) {
      final parts = localeCode.split('_');
      _locale = Locale(parts[0], parts.length > 1 ? parts[1] : null);
    }
    _volumeNormalization = prefs.getBool(_keyVolumeNormalization) ?? false;
    _volumeBoost = prefs.getInt(_keyVolumeBoost) ?? 0;
    _bufferStrength = prefs.getString(_keyBufferStrength) ?? 'fast';
    _showFps = prefs.getBool(_keyShowFps) ?? true;
    _showClock = prefs.getBool(_keyShowClock) ?? true;
    _showNetworkSpeed = prefs.getBool(_keyShowNetworkSpeed) ?? true;
    _showVideoInfo = prefs.getBool(_keyShowVideoInfo) ?? true;
    _progressBarMode = prefs.getString(_keyProgressBarMode) ?? 'auto';
    _enableMultiScreen = prefs.getBool(_keyEnableMultiScreen) ?? true;
    _defaultScreenPosition = prefs.getInt(_keyDefaultScreenPosition) ?? 1;
    _activeScreenIndex = prefs.getInt(_keyActiveScreenIndex) ?? 0;
    _lastPlayMode = prefs.getString(_keyLastPlayMode) ?? 'single';
    _showMultiScreenChannelName = prefs.getBool(_keyShowMultiScreenChannelName) ?? false;
    ServiceLocator.log.d('SettingsProvider: loaded showMultiScreenChannelName=$_showMultiScreenChannelName');

    // Load multi-screen channel ID list
    final multiScreenChannelsJson = prefs.getString(_keyLastMultiScreenChannels);
    if (multiScreenChannelsJson != null) {
      try {
        final List<dynamic> decoded = List<dynamic>.from(
          multiScreenChannelsJson.split(',').map((s) => s.isEmpty ? null : int.tryParse(s))
        );
        _lastMultiScreenChannels = decoded.map((e) => e as int?).toList();
        while (_lastMultiScreenChannels.length < 4) {
          _lastMultiScreenChannels.add(null);
        }
      } catch (_) {
        _lastMultiScreenChannels = [null, null, null, null];
      }
    }

    // Load color scheme settings
    _darkColorScheme = prefs.getString(_keyDarkColorScheme) ?? 'lumio';
    _lightColorScheme = prefs.getString(_keyLightColorScheme) ?? 'lumio-light';

    // Load font settings
    _fontFamily = prefs.getString(_keyFontFamily) ?? 'System';

    // Load simple menu settings
    _simpleMenu = prefs.getBool(_keySimpleMenu) ?? true;

    // Load log level settings
    _logLevel = prefs.getString(_keyLogLevel) ?? 'off';

    // Load mobile screen orientation settings
    _mobileOrientation = prefs.getString(_keyMobileOrientation) ?? 'portrait';

    // Do not call notifyListeners() in constructor to avoid triggering rebuild during build
  }

  /// Detect version update, automatically turn off developer logs if app updated
  Future<void> _checkVersionUpdate() async {
    try {
      final prefs = ServiceLocator.prefs;
      final lastVersion = prefs.getString(_keyLastAppVersion);

      // Get current version number
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // If versions differ, app has been updated
      if (lastVersion != null && lastVersion != currentVersion) {
        ServiceLocator.log.d('Version update detected: $lastVersion -> $currentVersion');

        // Automatically turn off developer logs
        if (_logLevel != 'off') {
          ServiceLocator.log.d('Automatically turning off developer logs');
          await setLogLevel('off');
        }
      }

      // Save current version number
      await prefs.setString(_keyLastAppVersion, currentVersion);
    } catch (e) {
      ServiceLocator.log.e('Version check failed: $e');
    }
  }

  Future<void> _saveSettings() async {
    final prefs = ServiceLocator.prefs;

    await prefs.setString(_keyThemeMode, _themeMode);
    await prefs.setBool(_keyAutoRefresh, _autoRefresh);
    await prefs.setInt(_keyRefreshInterval, _refreshInterval);
    await prefs.setString(_keyDefaultQuality, _defaultQuality);
    await prefs.setBool(_keyHardwareDecoding, _hardwareDecoding);
    await prefs.setString(_keyDecodingMode, _decodingMode);
    await prefs.setInt(_keyBufferSize, _bufferSize);
    if (_lastPlaylistId != null) {
      await prefs.setInt(_keyLastPlaylistId, _lastPlaylistId!);
    }
    await prefs.setBool(_keyEnableEpg, _enableEpg);
    if (_epgUrl != null) {
      await prefs.setString(_keyEpgUrl, _epgUrl!);
    }
    await prefs.setBool(_keyParentalControl, _parentalControl);
    if (_parentalPin != null) {
      await prefs.setString(_keyParentalPin, _parentalPin!);
    }
    await prefs.setBool(_keyAutoPlay, _autoPlay);
    await prefs.setBool(_keyRememberLastChannel, _rememberLastChannel);
    if (_lastChannelId != null) {
      await prefs.setInt(_keyLastChannelId, _lastChannelId!);
    }
    if (_locale != null) {
      await prefs.setString(_keyLocale, _locale!.languageCode);
    } else {
      await prefs.remove(_keyLocale);
    }
    await prefs.setBool(_keyVolumeNormalization, _volumeNormalization);
    await prefs.setInt(_keyVolumeBoost, _volumeBoost);
    await prefs.setString(_keyBufferStrength, _bufferStrength);
    await prefs.setBool(_keyShowFps, _showFps);
    await prefs.setBool(_keyShowClock, _showClock);
    await prefs.setBool(_keyShowNetworkSpeed, _showNetworkSpeed);
    await prefs.setBool(_keyShowVideoInfo, _showVideoInfo);
    await prefs.setString(_keyProgressBarMode, _progressBarMode);
    await prefs.setBool(_keyEnableMultiScreen, _enableMultiScreen);
    await prefs.setInt(_keyDefaultScreenPosition, _defaultScreenPosition);
    await prefs.setInt(_keyActiveScreenIndex, _activeScreenIndex);
    await prefs.setString(_keyLastPlayMode, _lastPlayMode);
    await prefs.setString(_keyLastMultiScreenChannels, _lastMultiScreenChannels.map((e) => e?.toString() ?? '').join(','));
    await prefs.setBool(_keyShowMultiScreenChannelName, _showMultiScreenChannelName);
    await prefs.setString(_keyDarkColorScheme, _darkColorScheme);
    await prefs.setString(_keyLightColorScheme, _lightColorScheme);
    await prefs.setString(_keyFontFamily, _fontFamily);
    await prefs.setBool(_keySimpleMenu, _simpleMenu);
    await prefs.setString(_keyLogLevel, _logLevel);
    await prefs.setString(_keyMobileOrientation, _mobileOrientation);
  }

  // Setters with persistence
  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAutoRefresh(bool value) async {
    _autoRefresh = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setRefreshInterval(int hours) async {
    _refreshInterval = hours;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDefaultQuality(String quality) async {
    _defaultQuality = quality;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setHardwareDecoding(bool enabled) async {
    _hardwareDecoding = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDecodingMode(String mode) async {
    _decodingMode = mode;
    // Also update hardwareDecoding based on mode for backward compatibility
    _hardwareDecoding = mode != 'software';
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setBufferSize(int seconds) async {
    _bufferSize = seconds;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setLastPlaylistId(int? id) async {
    _lastPlaylistId = id;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setEnableEpg(bool enabled) async {
    _enableEpg = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setEpgUrl(String? url) async {
    _epgUrl = url;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setParentalControl(bool enabled) async {
    _parentalControl = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setParentalPin(String? pin) async {
    _parentalPin = pin;
    await _saveSettings();
    notifyListeners();
  }

  bool validateParentalPin(String pin) {
    return _parentalPin == pin;
  }

  Future<void> setAutoPlay(bool enabled) async {
    _autoPlay = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setRememberLastChannel(bool enabled) async {
    _rememberLastChannel = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setLastChannelId(int? id) async {
    _lastChannelId = id;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setVolumeNormalization(bool enabled) async {
    _volumeNormalization = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setVolumeBoost(int db) async {
    _volumeBoost = db.clamp(-20, 20);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setBufferStrength(String strength) async {
    _bufferStrength = strength;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setShowFps(bool show) async {
    _showFps = show;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setShowClock(bool show) async {
    _showClock = show;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setShowNetworkSpeed(bool show) async {
    _showNetworkSpeed = show;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setShowVideoInfo(bool show) async {
    _showVideoInfo = show;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setProgressBarMode(String mode) async {
    if (mode == 'auto' || mode == 'always' || mode == 'never') {
      _progressBarMode = mode;
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> setEnableMultiScreen(bool enabled) async {
    _enableMultiScreen = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDefaultScreenPosition(int position) async {
    _defaultScreenPosition = position.clamp(1, 4);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setActiveScreenIndex(int index) async {
    _activeScreenIndex = index.clamp(0, 3);
    await _saveSettings();
    notifyListeners();
  }

  /// Set whether to show channel name in multi-screen playback
  Future<void> setShowMultiScreenChannelName(bool show) async {
    ServiceLocator.log.d('SettingsProvider: setShowMultiScreenChannelName($show)');
    _showMultiScreenChannelName = show;
    await _saveSettings();
    notifyListeners();
  }

  /// Set last playback mode
  Future<void> setLastPlayMode(String mode) async {
    _lastPlayMode = mode;
    await _saveSettings();
    notifyListeners();
  }

  /// Set multi-screen channel ID list
  Future<void> setLastMultiScreenChannels(List<int?> channelIds) async {
    _lastMultiScreenChannels = List<int?>.from(channelIds);
    while (_lastMultiScreenChannels.length < 4) {
      _lastMultiScreenChannels.add(null);
    }
    await _saveSettings();
    notifyListeners();
  }

  /// Save single channel playback status
  Future<void> saveLastSingleChannel(int? channelId) async {
    _lastPlayMode = 'single';
    if (channelId != null) {
      _lastChannelId = channelId;
    }
    await _saveSettings();
    notifyListeners();
  }

  /// Save multi-screen playback status
  Future<void> saveLastMultiScreen(List<int?> channelIds, int activeIndex) async {
    _lastPlayMode = 'multi';
    _lastMultiScreenChannels = List<int?>.from(channelIds);
    while (_lastMultiScreenChannels.length < 4) {
      _lastMultiScreenChannels.add(null);
    }
    _activeScreenIndex = activeIndex.clamp(0, 3);
    await _saveSettings();
    notifyListeners();
  }

  /// Check if there is a multi-screen state that can be restored
  bool get hasMultiScreenState {
    return _lastPlayMode == 'multi' && _lastMultiScreenChannels.any((id) => id != null);
  }

  /// Set dark mode color scheme
  Future<void> setDarkColorScheme(String scheme) async {
    ServiceLocator.log.d('SettingsProvider: Setting dark color scheme - $scheme');
    _darkColorScheme = scheme;
    await _saveSettings();
    ServiceLocator.log.d('SettingsProvider: Color scheme saved, notifying listeners');
    notifyListeners();
  }

  /// Set light mode color scheme
  Future<void> setLightColorScheme(String scheme) async {
    ServiceLocator.log.d('SettingsProvider: Setting light color scheme - $scheme');
    _lightColorScheme = scheme;
    await _saveSettings();
    ServiceLocator.log.d('SettingsProvider: Color scheme saved, notifying listeners');
    notifyListeners();
  }

  /// Set font
  Future<void> setFontFamily(String fontFamily) async {
    ServiceLocator.log.d('SettingsProvider: Setting font - $fontFamily');
    _fontFamily = fontFamily;
    await _saveSettings();
    notifyListeners();
  }

  /// Set simple menu bar
  Future<void> setSimpleMenu(bool value) async {
    ServiceLocator.log.d('SettingsProvider: Setting simple menu bar - $value');
    _simpleMenu = value;
    await _saveSettings();
    notifyListeners();
  }

  /// Set log level
  Future<void> setLogLevel(String level) async {
    debugPrint('SettingsProvider: Starting to set log level - $level');
    _logLevel = level;
    await _saveSettings();

    // Update log service
    final logLevel = switch (level) {
      'debug' => LogLevel.debug,
      'release' => LogLevel.release,
      'off' => LogLevel.off,
      _ => LogLevel.release,
    };

    debugPrint('SettingsProvider: Calling ServiceLocator.log.setLogLevel($logLevel)');
    await ServiceLocator.log.setLogLevel(logLevel);

    // Write test logs
    debugPrint('SettingsProvider: Writing test logs...');
    ServiceLocator.log.d('Test log: Log level switched to $level');
    ServiceLocator.log.i('Test log: Info level');
    ServiceLocator.log.w('Test log: Warning level');

    // Force flush log buffer
    await ServiceLocator.log.flush();
    debugPrint('SettingsProvider: Log buffer flushed');

    notifyListeners();
  }

  /// Set mobile screen orientation
  Future<void> setMobileOrientation(String orientation) async {
    ServiceLocator.log.d('SettingsProvider: Setting mobile screen orientation - $orientation');
    _mobileOrientation = orientation;
    await _saveSettings();
    notifyListeners();
  }

  // Reset all settings to defaults
  Future<void> resetSettings() async {
    _themeMode = 'dark';
    _autoRefresh = false;
    _refreshInterval = 24;
    _defaultQuality = 'auto';
    _hardwareDecoding = true;
    _bufferSize = 30;
    _enableEpg = true;
    _epgUrl = null;
    _parentalControl = false;
    _parentalPin = null;
    _autoPlay = false;
    _rememberLastChannel = true;
    _volumeNormalization = false;
    _volumeBoost = 0;
    _bufferStrength = 'fast';
    _showFps = true;
    _showClock = true;
    _showNetworkSpeed = true;
    _showVideoInfo = true;
    _progressBarMode = 'auto';
    _enableMultiScreen = true;
    _defaultScreenPosition = 1;
    _activeScreenIndex = 0;
    _darkColorScheme = 'lumio';
    _lightColorScheme = 'lumio-light';
    _fontFamily = 'Arial';

    await _saveSettings();

    // Reset log level to off (performance optimization)
    await ServiceLocator.prefs.setString('log_level', 'off');
    await ServiceLocator.log.setLogLevel(LogLevel.off);

    notifyListeners();
  }
}
