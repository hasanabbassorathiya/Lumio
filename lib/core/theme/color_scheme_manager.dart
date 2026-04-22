import 'package:flutter/material.dart';
import 'color_scheme_data.dart';

/// Color scheme manager
/// Singleton pattern, manages all available color schemes
class ColorSchemeManager {
  // Singleton instance
  static final ColorSchemeManager instance = ColorSchemeManager._();

  ColorSchemeManager._();

  // ============ Dark Mode Color Scheme List ============
  static const List<ColorSchemeData> darkSchemes = [
    darkLumio,
    darkOcean,
    darkForest,
    darkSunset,
    darkLavender,
    darkMidnight,
  ];

  // ============ Light Mode Color Scheme List ============
  static const List<ColorSchemeData> lightSchemes = [
    lightLumio,
    lightSky,
    lightSpring,
    lightCoral,
    lightViolet,
    lightClassic,
  ];

  /// Get dark mode color scheme by ID
  /// If not found, returns the default Lumio scheme
  /// Supports custom color format: custom_AARRGGBB
  ColorSchemeData getDarkScheme(String id) {
    // Check if it is a custom color
    if (id.startsWith('custom_')) {
      return _createCustomScheme(id, isDark: true);
    }

    try {
      return darkSchemes.firstWhere((scheme) => scheme.id == id);
    } catch (_) {
      // Return default scheme when not found
      return darkLumio;
    }
  }

  /// Get light mode color scheme by ID
  /// If not found, returns the default Lumio Light scheme
  /// Supports custom color format: custom_AARRGGBB
  ColorSchemeData getLightScheme(String id) {
    // Check if it is a custom color
    if (id.startsWith('custom_')) {
      return _createCustomScheme(id, isDark: false);
    }

    try {
      return lightSchemes.firstWhere((scheme) => scheme.id == id);
    } catch (_) {
      // Return default scheme when not found
      return lightLumio;
    }
  }

  /// Create color scheme from custom color ID
  /// ID format: custom_AARRGGBB (e.g.: custom_ffe91e63)
  ColorSchemeData _createCustomScheme(String id, {required bool isDark}) {
    try {
      // Extract color value
      final colorHex = id.substring(7); // Remove "custom_" prefix
      final colorValue = int.parse(colorHex, radix: 16);
      final primaryColor = Color(colorValue);

      // Generate gradient color (slightly adjust hue)
      final hsl = HSLColor.fromColor(primaryColor);
      final secondaryColor = hsl.withHue((hsl.hue + 20) % 360).toColor();

      return ColorSchemeData(
        id: id,
        nameKey: 'colorSchemeCustom',
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        backgroundColor: isDark ? null : const Color(0xFFF5F5F5),
        descriptionKey: 'colorSchemeCustom',
      );
    } catch (e) {
      // Return default scheme if parsing fails
      return isDark ? darkLumio : lightLumio;
    }
  }

  /// Get all dark mode color schemes
  List<ColorSchemeData> getAllDarkSchemes() {
    return darkSchemes;
  }

  /// Get all light mode color schemes
  List<ColorSchemeData> getAllLightSchemes() {
    return lightSchemes;
  }

  /// Check if the color scheme ID is valid (Dark mode)
  bool isDarkSchemeValid(String id) {
    return darkSchemes.any((scheme) => scheme.id == id);
  }

  /// Check if the color scheme ID is valid (Light mode)
  bool isLightSchemeValid(String id) {
    return lightSchemes.any((scheme) => scheme.id == id);
  }
}
