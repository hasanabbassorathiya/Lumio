import 'package:flutter/material.dart';

/// Color scheme data model
/// Defines all color information for a single color scheme
class ColorSchemeData {
  /// Unique identifier, e.g., 'lumio', 'ocean'
  final String id;

  /// Localization key, e.g., 'colorSchemeLumio'
  final String nameKey;

  /// Primary color 1 (gradient start color)
  final Color primaryColor;

  /// Primary color 2 (gradient end color)
  final Color secondaryColor;

  /// Background color (only needed for light mode)
  final Color? backgroundColor;

  /// Localization key for features description
  final String descriptionKey;

  const ColorSchemeData({
    required this.id,
    required this.nameKey,
    required this.primaryColor,
    required this.secondaryColor,
    this.backgroundColor,
    required this.descriptionKey,
  });

  /// Get gradient colors
  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, secondaryColor],
      );

  /// Get focus color (usually primary color 1)
  Color get focusColor => primaryColor;

  /// Get focus border color (lighter version of primary color 1)
  Color get focusBorderColor {
    final hsl = HSLColor.fromColor(primaryColor);
    return hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();
  }

  /// Get soft gradient (40% opacity)
  LinearGradient get softGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor.withOpacity(0.4),
          secondaryColor.withOpacity(0.4),
        ],
      );
}

// ============ Dark Mode Color Schemes ============

/// Lumio - Pink-purple gradient, elegant and modern brand color
const darkLumio = ColorSchemeData(
  id: 'lumio',
  nameKey: 'colorSchemeLumio',
  primaryColor: Color(0xFFE91E8C),
  secondaryColor: Color(0xFF9C27B0),
  descriptionKey: 'colorSchemeDescLumio',
);

/// Ocean - Blue gradient, calm, professional, and eye-friendly
const darkOcean = ColorSchemeData(
  id: 'ocean',
  nameKey: 'colorSchemeOcean',
  primaryColor: Color(0xFF0EA5E9),
  secondaryColor: Color(0xFF0284C7),
  descriptionKey: 'colorSchemeDescOcean',
);

/// Forest - Green gradient, natural, comfortable, and eye-friendly
const darkForest = ColorSchemeData(
  id: 'forest',
  nameKey: 'colorSchemeForest',
  primaryColor: Color(0xFF10B981),
  secondaryColor: Color(0xFF059669),
  descriptionKey: 'colorSchemeDescForest',
);

/// Sunset - Orange-red gradient, warm, energetic, and eye-catching
const darkSunset = ColorSchemeData(
  id: 'sunset',
  nameKey: 'colorSchemeSunset',
  primaryColor: Color(0xFFF97316),
  secondaryColor: Color(0xFFDC2626),
  descriptionKey: 'colorSchemeDescSunset',
);

/// Lavender - Purple gradient, mysterious, noble, and soft
const darkLavender = ColorSchemeData(
  id: 'lavender',
  nameKey: 'colorSchemeLavender',
  primaryColor: Color(0xFF8B5CF6),
  secondaryColor: Color(0xFF6D28D9),
  descriptionKey: 'colorSchemeDescLavender',
);

/// Midnight - Deep blue gradient, deep, focused, and low-key
const darkMidnight = ColorSchemeData(
  id: 'midnight',
  nameKey: 'colorSchemeMidnight',
  primaryColor: Color(0xFF1E40AF),
  secondaryColor: Color(0xFF1E3A8A),
  descriptionKey: 'colorSchemeDescMidnight',
);

// ============ Light Mode Color Schemes ============

/// Lumio Light - Pink-purple gradient + light gray-white background
const lightLumio = ColorSchemeData(
  id: 'lumio-light',
  nameKey: 'colorSchemeLumioLight',
  primaryColor: Color(0xFFDB2777),
  secondaryColor: Color(0xFF7C3AED),
  backgroundColor: Color(0xFFF5F5F5),
  descriptionKey: 'colorSchemeDescLumioLight',
);

/// Sky - Sky blue gradient + light blue-white background
const lightSky = ColorSchemeData(
  id: 'sky',
  nameKey: 'colorSchemeSky',
  primaryColor: Color(0xFF0284C7),
  secondaryColor: Color(0xFF0369A1),
  backgroundColor: Color(0xFFF0F9FF),
  descriptionKey: 'colorSchemeDescSky',
);

/// Spring - Grass green gradient + light green-white background
const lightSpring = ColorSchemeData(
  id: 'spring',
  nameKey: 'colorSchemeSpring',
  primaryColor: Color(0xFF059669),
  secondaryColor: Color(0xFF047857),
  backgroundColor: Color(0xFFF0FDF4),
  descriptionKey: 'colorSchemeDescSpring',
);

/// Coral - Coral orange gradient + light orange-white background
const lightCoral = ColorSchemeData(
  id: 'coral',
  nameKey: 'colorSchemeCoral',
  primaryColor: Color(0xFFEA580C),
  secondaryColor: Color(0xFFC2410C),
  backgroundColor: Color(0xFFFFF7ED),
  descriptionKey: 'colorSchemeDescCoral',
);

/// Violet - Violet gradient + light purple-white background
const lightViolet = ColorSchemeData(
  id: 'violet',
  nameKey: 'colorSchemeViolet',
  primaryColor: Color(0xFF7C3AED),
  secondaryColor: Color(0xFF6D28D9),
  backgroundColor: Color(0xFFFAF5FF),
  descriptionKey: 'colorSchemeDescViolet',
);

/// Classic - Blue-gray gradient + pure white background
const lightClassic = ColorSchemeData(
  id: 'classic',
  nameKey: 'colorSchemeClassic',
  primaryColor: Color(0xFF475569),
  secondaryColor: Color(0xFF334155),
  backgroundColor: Color(0xFFFFFFFF),
  descriptionKey: 'colorSchemeDescClassic',
);
