import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import '../services/service_locator.dart';

// Windows mini-player mode control
class WindowsPipChannel {
  static bool _isInMiniMode = false;
  static bool _isPinned = false;
  static Size? _originalSize;
  static Offset? _originalPosition;
  static bool _wasMaximized = false;
  static bool _wasFullScreen = false;
  
  // Default dimensions for mini mode
  static const double _miniWidth = 400;
  static const double _miniHeight = 225; // 16:9 aspect ratio
  static const double _margin = 20;

  // State change notifier
  static final ValueNotifier<bool> pipModeNotifier = ValueNotifier<bool>(false);

  // Whether in mini mode
  static bool get isInPipMode => _isInMiniMode;

  // Whether always on top
  static bool get isPinned => _isPinned;

  // Whether supported (Windows desktop only)
  static bool get isSupported => !kIsWeb && Platform.isWindows;

  // Enter mini mode
  static Future<bool> enterPipMode() async {
    if (!isSupported || _isInMiniMode) return false;

    try {
      // Save original window state
      _wasFullScreen = await windowManager.isFullScreen();
      _wasMaximized = await windowManager.isMaximized();
      
      // If fullscreen, exit first
      if (_wasFullScreen) {
        await windowManager.setFullScreen(false);
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      // If maximized, unmaximize first
      if (_wasMaximized) {
        await windowManager.unmaximize();
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      _originalSize = await windowManager.getSize();
      _originalPosition = await windowManager.getPosition();

      // Get primary display dimensions
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final screenWidth = primaryDisplay.size.width;
      final screenHeight = primaryDisplay.size.height;
      
      ServiceLocator.log.d('WindowsPipChannel: Screen dimensions - $screenWidth x $screenHeight');
      
      // Calculate bottom-right position (overlaying taskbar)
      final x = screenWidth - _miniWidth - _margin;
      final y = screenHeight - _miniHeight - _margin;

      ServiceLocator.log.d('WindowsPipChannel: Target position - ($x, $y)');

      // Hide title bar
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      
      // Set window attributes
      await windowManager.setMinimumSize(const Size(320, 180));
      await windowManager.setSize(const Size(_miniWidth, _miniHeight));
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Move to bottom-right
      await windowManager.setPosition(Offset(x, y));
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Always on top + skip taskbar (Win+D won	 minimize, hides from taskbar)
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      
      _isInMiniMode = true;
      _isPinned = true;
      pipModeNotifier.value = true; // Notify state change
      
      ServiceLocator.log.d('WindowsPipChannel: Entered mini mode successfully');
      return true;
    } catch (e) {
      ServiceLocator.log.d('WindowsPipChannel: enterPipMode error: $e');
      return false;
    }
  }

  // Exit mini mode
  static Future<bool> exitPipMode() async {
    if (!isSupported || !_isInMiniMode) return false;

    try {
      // Disable always on top and skip taskbar
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSkipTaskbar(false);
      
      // Restore title bar
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      
      // Restore minimum size constraint
      await windowManager.setMinimumSize(const Size(360, 600));
      
      // Restore original size and position
      if (_originalSize != null) {
        await windowManager.setSize(_originalSize!);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      if (_originalPosition != null) {
        await windowManager.setPosition(_originalPosition!);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Restore maximized state
      if (_wasMaximized) {
        await Future.delayed(const Duration(milliseconds: 100));
        await windowManager.maximize();
      }
      
      // Restore fullscreen state - use microtask to avoid blocking
      if (_wasFullScreen) {
        Future.microtask(() async {
          await Future.delayed(const Duration(milliseconds: 200));
          try {
            await windowManager.setFullScreen(true);
            ServiceLocator.log.d('WindowsPipChannel: Fullscreen state restored');
          } catch (e) {
            ServiceLocator.log.d('WindowsPipChannel: Failed to restore fullscreen: $e');
          }
        });
      }

      _isInMiniMode = false;
      _isPinned = false;
      pipModeNotifier.value = false; // Notify state change
      
      ServiceLocator.log.d('WindowsPipChannel: Exited mini mode');
      return true;
    } catch (e) {
      ServiceLocator.log.d('WindowsPipChannel: exitPipMode error: $e');
      return false;
    }
  }

  // Toggle mini mode
  static Future<bool> togglePipMode() async {
    if (_isInMiniMode) {
      return exitPipMode();
    } else {
      return enterPipMode();
    }
  }

  // Toggle always on top
  static Future<bool> togglePin() async {
    if (!isSupported) return false;

    try {
      _isPinned = !_isPinned;
      await windowManager.setAlwaysOnTop(_isPinned);
      ServiceLocator.log.d('WindowsPipChannel: Always on top: $_isPinned');
      return true;
    } catch (e) {
      ServiceLocator.log.d('WindowsPipChannel: togglePin error: $e');
      return false;
    }
  }
  
  // Reset state (used on app exit)
  static void reset() {
    _isInMiniMode = false;
    _isPinned = false;
    _originalSize = null;
    _originalPosition = null;
    _wasMaximized = false;
    _wasFullScreen = false;
  }
}
