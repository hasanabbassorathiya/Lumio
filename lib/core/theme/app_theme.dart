import 'package:flutter/material.dart';
import 'color_scheme_data.dart';
import 'color_scheme_manager.dart';
import '../services/service_locator.dart';

class AppTheme {
  // ============ Netflix-Style Dark Theme Tokens ============
  static const Color primaryColor = Color(0xFF6366F1); // Indigo
  static const Color accentColor = Color(0xFF2DD4BF); // Teal
  static const Color secondaryColor = Color(0xFF8B5CF6); // Violet

  // Spacing system
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;

  // Border radius - Modern high-level rounding
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;
  static const double radiusPill = 100.0;

  // Dark theme colors - Modern high-level style
  static const Color glassColorDark = Color(0x0DFFFFFF); // Lower opacity
  static const Color glassBorderColorDark = Color(0x1AFFFFFF);
  static const Color backgroundColorDark = Color(0xFF000000); // Pure black for depth
  static const Color surfaceColorDark = Color(0xFF0F0F0F); // Modern dark surface
  static const Color cardColorDark = Color(0xFF161616); // Card color with depth
  static const Color cardHoverColorDark = Color(0xFF1F1F1F);
  static const Color textPrimaryDark = Color(0xFFFFFFFF); // High contrast
  static const Color textSecondaryDark = Color(0xFFAAAAAA);
  static const Color textMutedDark = Color(0xFF777777);

  // ============ Light Theme Colors ============
  static const Color backgroundColorLight = Color(0xFFF5F5F5); // Light Grey
  static const Color surfaceColorLight = Color(0xFFFFFFFF); // White
  static const Color cardColorLight = Color(0xFFFFFFFF); // White
  static const Color cardHoverColorLight = Color(0xFFF0F0F0);
  static const Color focusBackgroundColorLight = Color(0xFFFCE4EC); // Light Pink for focus in light mode
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF616161);
  static const Color textMutedLight = Color(0xFF9E9E9E);
  static const Color glassColorLight = Color(0x1A000000);
  static const Color glassBorderColorLight = Color(0x33000000);

  // ============ Dynamic Colors (based on theme) ============
  // These are default values (dark theme), actual colors retrieved via of(context)
  static const Color backgroundColor = backgroundColorDark;
  static const Color surfaceColor = surfaceColorDark;
  static const Color cardColor = cardColorDark;
  static const Color cardHoverColor = cardHoverColorDark;
  static const Color textPrimary = textPrimaryDark;
  static const Color textSecondary = textSecondaryDark;
  static const Color textMuted = textMutedDark;
  static const Color glassColor = glassColorDark;
  static const Color glassBorderColor = glassBorderColorDark;
  static const Color glassHighlight = Color(0x0DFFFFFF);

  // Focus Colors (for TV navigation) - Lumio gradient
  static const Color focusColor = Color(0xFFE91E8C);
  static const Color focusBorderColor = Color(0xFFFF6EB4);

  // Status Colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFFF5252);
  static const Color warningColor = Color(0xFFFFB74D);
  static const Color infoColor = Color(0xFF29B6F6);

  // ============ Helper methods to get theme-aware colors ============
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? backgroundColorDark : backgroundColorLight;
  }

  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? surfaceColorDark : surfaceColorLight;
  }

  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? cardColorDark : cardColorLight;
  }

  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight;
  }

  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight;
  }

  static Color getTextMuted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textMutedDark : textMutedLight;
  }

  static Color getGlassColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? glassColorDark : glassColorLight;
  }

  static Color getGlassBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? glassBorderColorDark : glassBorderColorLight;
  }

  static Color getFocusBackgroundColor(BuildContext context) {
    // Use primary color from color scheme with opacity for focus background
    // Light theme requires higher opacity for visibility
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.1 : 0.15);
  }

  // Lumio Gradient
  static const LinearGradient lumioGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryColor, // Indigo
      secondaryColor, // Violet
    ],
  );

  static const LinearGradient lumioSoftGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x666366F1), // Indigo 40%
      Color(0x668B5CF6), // Violet 40%
    ],
  );
  
  /// Get current theme gradient (dynamic)
  static LinearGradient getGradient(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [colorScheme.primary, colorScheme.secondary],
    );
  }
  
  /// Get current theme primary color (dynamic)
  static Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }
  
  /// Get current theme secondary color (dynamic)
  static Color getSecondaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }
  
  /// Get current theme soft gradient (dynamic)
  static LinearGradient getSoftGradient(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colorScheme.primary.withOpacity(0.4),
        colorScheme.secondary.withOpacity(0.4),
      ],
    );
  }

  // Card Gradient - Glassmorphism

  /// Font mapping (using bundled font files)
  static const Map<String, String?> fontMap = {
    'System': null, // System font (all platforms)
    // Chinese fonts
    'Microsoft YaHei': 'MicrosoftYaHei',
    'SimHei': 'SimHei',
    'SimSun': 'SimSun',
    'KaiTi': 'KaiTi',
    'FangSong': 'FangSong',
    // English fonts
    'Arial': 'Arial',
    'Calibri': 'Calibri',
    'Georgia': 'Georgia',
    'Verdana': 'Verdana',
    'Tahoma': 'Tahoma',
    'Times New Roman': 'TimesNewRoman',
    'Segoe UI': 'SegoeUI',
    'Impact': 'Impact',
  };
  
  /// Get available font list based on platform and language
  /// All platforms show same font options (using bundled files)
  static List<String> getAvailableFonts([String? languageCode]) {
    final isChinese = languageCode == null || languageCode.startsWith('zh');
    
    if (isChinese) {
      return [
        'System',
        'Microsoft YaHei',
        'SimHei',
        'SimSun',
        'KaiTi',
        'FangSong',
        // Add common English fonts
        'Arial',
        'Segoe UI',
      ];
    } else {
      return [
        'System',
        // English fonts
        'Arial',
        'Segoe UI',
        'Calibri',
        'Georgia',
        'Verdana',
        'Tahoma',
        'Times New Roman',
        'Impact',
      ];
    }
  }
  
  /// Get fontFamily based on font name
  /// Using bundled files to ensure cross-platform consistency
  static String? resolveFontFamily(String fontName) {
    if (fontName == 'System') {
      return null;
    }
    return fontMap[fontName];
  }

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1AFFFFFF), // 10% white
      Color(0x0DFFFFFF), // 5% white
    ],
  );

  // Overlay Gradients for Player
  static const LinearGradient overlayGradientTop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xCC000000), // 80% black
      Colors.transparent,
    ],
    stops: [0.0, 1.0],
  );

  static const LinearGradient overlayGradientBottom = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0xE6000000), // 90% black
    ],
    stops: [0.0, 1.0],
  );

  // Spacing
  static const double spacingXLarge = 32.0;

  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      iconTheme: const IconThemeData(
        color: textSecondary,
        size: 24,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.25,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: textPrimaryDark, // High contrast button
          foregroundColor: backgroundColorDark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimaryDark,
          side: BorderSide(color: textPrimaryDark.withOpacity(0.3), width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimaryDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColorDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        hintStyle: const TextStyle(color: textMutedDark, fontSize: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColorDark,
        elevation: 24,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1F1F1F),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: glassColor,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withAlpha(51),
        trackHeight: 4,
      ),
    );
  }

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColorLight,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColorLight,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: cardColorLight,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColorLight,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimaryLight),
        titleTextStyle: TextStyle(
          color: textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColorLight,
        selectedItemColor: primaryColor,
        unselectedItemColor: textMutedLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      iconTheme: const IconThemeData(
        color: textSecondaryLight,
        size: 24,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimaryLight),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimaryLight),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimaryLight),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimaryLight),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimaryLight),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textPrimaryLight),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimaryLight),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimaryLight),
        titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondaryLight),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: textPrimaryLight),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: textSecondaryLight),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: textMutedLight),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimaryLight),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondaryLight),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: textMutedLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassColorLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: glassBorderColorLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: glassBorderColorLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor),
        ),
        hintStyle: const TextStyle(color: textMutedLight),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColorLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColorLight,
        contentTextStyle: const TextStyle(color: textPrimaryLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primaryColor),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: glassColorLight,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withAlpha(51),
        trackHeight: 4,
      ),
    );
  }
}

// Premium Solid Card Decoration (High-Level Redesign)
class GlassDecoration extends BoxDecoration {
  GlassDecoration({
    required BuildContext context,
    bool focused = false,
    double radius = AppTheme.radiusMedium,
    Color? glowColor,
  }) : super(
          borderRadius: BorderRadius.circular(radius),
          color: AppTheme.getCardColor(context),
          border: Border.all(
            color: focused
                ? (glowColor ?? AppTheme.getPrimaryColor(context))
                : Colors.white.withOpacity(0.05),
            width: focused ? 2.5 : 1,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: AppTheme.getPrimaryColor(context).withOpacity(0.3),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        );
}

// TV-specific focus decoration - Netflix white border style
class TVFocusDecoration extends BoxDecoration {
  TVFocusDecoration({required BuildContext context, bool focused = false})
      : super(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: focused ? Colors.white : Colors.transparent,
            width: focused ? 2.5 : 0,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(180),
                    blurRadius: 24,
                    spreadRadius: 6,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        );
}

// Netflix-style Card Widget
class GlassCard extends StatelessWidget {
  final Widget child;
  final bool focused;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? glowColor;

  const GlassCard({
    super.key,
    required this.child,
    this.focused = false,
    this.radius = AppTheme.radiusMedium,
    this.padding,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: focused ? 1.05 : 1.0,
      duration: AppTheme.animationFast,
      child: AnimatedContainer(
        duration: AppTheme.animationFast,
        decoration: GlassDecoration(
          context: context,
          focused: focused,
          radius: radius,
          glowColor: glowColor,
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

// ============ Dynamic Theme Generation with Color Schemes ============

extension AppThemeDynamic on AppTheme {
  /// Generate dark theme based on color scheme ID
  static ThemeData getDarkTheme(String schemeId, [String? fontFamily]) {
    final scheme = ColorSchemeManager.instance.getDarkScheme(schemeId);
    ServiceLocator.log.d('AppTheme: Generating dark theme - schemeId=$schemeId, primaryColor=${scheme.primaryColor}, secondaryColor=${scheme.secondaryColor}, fontFamily=$fontFamily');
    return _buildDarkTheme(scheme, fontFamily);
  }
  
  /// Generate light theme based on color scheme ID
  static ThemeData getLightTheme(String schemeId, [String? fontFamily]) {
    final scheme = ColorSchemeManager.instance.getLightScheme(schemeId);
    ServiceLocator.log.d('AppTheme: Generating light theme - schemeId=$schemeId, primaryColor=${scheme.primaryColor}, secondaryColor=${scheme.secondaryColor}, fontFamily=$fontFamily');
    return _buildLightTheme(scheme, fontFamily);
  }
  
  /// Build dark theme (using color scheme)
  static ThemeData _buildDarkTheme(ColorSchemeData scheme, [String? fontFamily]) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: scheme.primaryColor,
      scaffoldBackgroundColor: AppTheme.backgroundColorDark,
      fontFamily: fontFamily,
      hoverColor: scheme.primaryColor.withOpacity(0.08),
      focusColor: scheme.primaryColor.withOpacity(0.12),
      highlightColor: scheme.primaryColor.withOpacity(0.1),
      splashColor: scheme.primaryColor.withOpacity(0.12),
      colorScheme: ColorScheme.dark(
        primary: scheme.primaryColor,
        secondary: scheme.secondaryColor,
        surface: AppTheme.surfaceColorDark,
        error: AppTheme.errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppTheme.textPrimaryDark,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppTheme.cardColorDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppTheme.textPrimaryDark),
        titleTextStyle: TextStyle(
          color: AppTheme.textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppTheme.surfaceColorDark,
        selectedItemColor: scheme.primaryColor,
        unselectedItemColor: AppTheme.textMutedDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      iconTheme: const IconThemeData(
        color: AppTheme.textSecondaryDark,
        size: 24,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark, letterSpacing: -0.25),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryDark),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryDark),
        titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: AppTheme.textPrimaryDark),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: AppTheme.textSecondaryDark),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppTheme.textMutedDark),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryDark),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.textMutedDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimaryDark,
          side: BorderSide(color: AppTheme.textPrimaryDark.withOpacity(0.3), width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primaryColor,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.cardColorDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: scheme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: const BorderSide(color: AppTheme.errorColor, width: 1),
        ),
        hintStyle: const TextStyle(color: AppTheme.textMutedDark, fontSize: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTheme.surfaceColorDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        elevation: 24,
        shadowColor: Colors.black,
      ),
      listTileTheme: ListTileThemeData(
        selectedTileColor: scheme.primaryColor.withOpacity(0.1),
        selectedColor: scheme.primaryColor,
        iconColor: AppTheme.textSecondaryDark,
        textColor: AppTheme.textPrimaryDark,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTheme.cardColorDark,
        contentTextStyle: const TextStyle(color: AppTheme.textPrimaryDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1F1F1F),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primaryColor),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primaryColor,
        inactiveTrackColor: Colors.white.withOpacity(0.05),
        thumbColor: Colors.white,
        overlayColor: scheme.primaryColor.withOpacity(0.2),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 4),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.white70;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return scheme.primaryColor.withOpacity(0.6);
          return Colors.white.withOpacity(0.1);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
  
  /// Build light theme (using color scheme)
  static ThemeData _buildLightTheme(ColorSchemeData scheme, [String? fontFamily]) {
    final bgColor = scheme.backgroundColor ?? AppTheme.backgroundColorLight;
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: scheme.primaryColor,
      scaffoldBackgroundColor: bgColor,
      fontFamily: fontFamily,
      hoverColor: scheme.primaryColor.withOpacity(0.12),
      focusColor: scheme.primaryColor.withOpacity(0.15),
      highlightColor: scheme.primaryColor.withOpacity(0.15),
      splashColor: scheme.primaryColor.withOpacity(0.2),
      colorScheme: ColorScheme.light(
        primary: scheme.primaryColor,
        secondary: scheme.secondaryColor,
        surface: AppTheme.surfaceColorLight,
        error: AppTheme.errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppTheme.textPrimaryLight,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppTheme.cardColorLight,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.surfaceColorLight,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppTheme.textPrimaryLight),
        titleTextStyle: TextStyle(
          color: AppTheme.textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppTheme.surfaceColorLight,
        selectedItemColor: scheme.primaryColor,
        unselectedItemColor: AppTheme.textMutedLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      iconTheme: const IconThemeData(
        color: AppTheme.textSecondaryLight,
        size: 24,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryLight),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryLight),
        titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryLight),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: AppTheme.textPrimaryLight),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: AppTheme.textSecondaryLight),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppTheme.textMutedLight),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryLight),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryLight),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.textMutedLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primaryColor,
          side: BorderSide(color: scheme.primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.glassColorLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.glassBorderColorLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.glassBorderColorLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: scheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        hintStyle: const TextStyle(color: AppTheme.textMutedLight),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTheme.cardColorLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        elevation: 8,
        shadowColor: Colors.black26,
      ),
      listTileTheme: ListTileThemeData(
        selectedTileColor: scheme.primaryColor.withOpacity(0.15),
        selectedColor: scheme.primaryColor,
        iconColor: AppTheme.textSecondaryLight,
        textColor: AppTheme.textPrimaryLight,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTheme.cardColorLight,
        contentTextStyle: const TextStyle(color: AppTheme.textPrimaryLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primaryColor),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primaryColor,
        inactiveTrackColor: Colors.black.withOpacity(0.05),
        thumbColor: scheme.primaryColor,
        overlayColor: scheme.primaryColor.withOpacity(0.2),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 2),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.white70;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primaryColor;
          return Colors.black.withOpacity(0.1);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
