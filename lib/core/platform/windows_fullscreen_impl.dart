import 'windows_fullscreen_native.dart';
import 'fullscreen_interface.dart';

class WindowsFullscreen implements FullscreenService {
  static bool toggleFullScreen() => WindowsFullscreenNative.toggleFullScreen();
  static bool enterFullScreen() => WindowsFullscreenNative.enterFullScreen();
  static bool exitFullScreen() => WindowsFullscreenNative.exitFullScreen();
  static bool isFullScreen() => WindowsFullscreenNative.isFullScreen();
  static bool initialize() => WindowsFullscreenNative.initialize();
}
