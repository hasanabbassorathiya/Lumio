import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'windows_fullscreen_impl.dart';
import 'default_fullscreen_impl.dart';

abstract class FullscreenService {
  static bool toggleFullScreen() {
    if (kIsWeb) return FullscreenImplementation.toggleFullScreen();
    if (Platform.isWindows) return WindowsFullscreen.toggleFullScreen();
    return FullscreenImplementation.toggleFullScreen();
  }

  static bool enterFullScreen() {
    if (kIsWeb) return FullscreenImplementation.enterFullScreen();
    if (Platform.isWindows) return WindowsFullscreen.enterFullScreen();
    return FullscreenImplementation.enterFullScreen();
  }

  static bool exitFullScreen() {
    if (kIsWeb) return FullscreenImplementation.exitFullScreen();
    if (Platform.isWindows) return WindowsFullscreen.exitFullScreen();
    return FullscreenImplementation.exitFullScreen();
  }

  static bool isFullScreen() {
    if (kIsWeb) return FullscreenImplementation.isFullScreen();
    if (Platform.isWindows) return WindowsFullscreen.isFullScreen();
    return FullscreenImplementation.isFullScreen();
  }

  static bool initialize() {
    if (kIsWeb) return FullscreenImplementation.initialize();
    if (Platform.isWindows) return WindowsFullscreen.initialize();
    return FullscreenImplementation.initialize();
  }
}
