import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../i18n/app_strings.dart';
import '../../features/settings/providers/settings_provider.dart';
import 'tv_focusable.dart';
import '../services/service_locator.dart';

/// Custom Color Picker Dialog
/// Allows users to select custom theme colors via palette
class CustomColorPickerDialog extends StatefulWidget {
  const CustomColorPickerDialog({super.key});

  @override
  State<CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<CustomColorPickerDialog> {
  Color _selectedColor = const Color(0xFFB39DDB); // Default lavender
  final FocusNode _firstColorFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    
    // Read current color scheme, init if custom
    _loadCurrentCustomColor();
    
    // Delay focus request to ensure dialog is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _firstColorFocusNode.requestFocus();
      }
    });
  }
  
  /// Load current custom color (if any)
  void _loadCurrentCustomColor() {
    final settings = context.read<SettingsProvider>();
    
    // Get color scheme ID based on current theme mode
    final isDarkMode = _isDarkMode(context, settings);
    final currentSchemeId = isDarkMode 
        ? settings.darkColorScheme 
        : settings.lightColorScheme;
    
    // Check if it is a custom color
    if (currentSchemeId.startsWith('custom_')) {
      try {
        // Extract color value: custom_AARRGGBB
        final colorHex = currentSchemeId.substring(7); // Remove "custom_" prefix
        final colorValue = int.parse(colorHex, radix: 16);
        _selectedColor = Color(colorValue);
      } catch (e) {
        // Keep default color on parse failure
        ServiceLocator.log.d('Failed to parse custom color: $e');
      }
    }
  }
  
  @override
  void dispose() {
    _firstColorFocusNode.dispose();
    super.dispose();
  }
  
  // Preset color palette - soft and elegant
  static const List<Color> _presetColors = [
    // Row 1: Light pink-purple
    Color(0xFFF8BBD0), // Light Pink
    Color(0xFFF48FB1),
    Color(0xFFE1BEE7), // Light Purple
    Color(0xFFCE93D8),
    Color(0xFFD1C4E9), // Light Lavender
    Color(0xFFB39DDB),

    // Row 2: Light blue
    Color(0xFFBBDEFB), // Light Blue
    Color(0xFF90CAF9),
    Color(0xFFB3E5FC), // Light Sky Blue
    Color(0xFF81D4FA),
    Color(0xFFB2EBF2), // Light Cyan
    Color(0xFF80DEEA),

    // Row 3: Light green
    Color(0xFFC8E6C9), // Light Green
    Color(0xFFA5D6A7),
    Color(0xFFB2DFDB), // Light Teal
    Color(0xFF80CBC4),
    Color(0xFFDCEDC8), // Light Lime
    Color(0xFFC5E1A5),

    // Row 4: Light yellow-orange
    Color(0xFFFFF9C4), // Light Yellow
    Color(0xFFFFF59D),
    Color(0xFFFFECB3), // Light Amber
    Color(0xFFFFE082),
    Color(0xFFFFE0B2), // Light Orange
    Color(0xFFFFCC80),

    // Row 5: Light warm colors
    Color(0xFFFFCCBC), // Light Deep Orange
    Color(0xFFFFAB91),
    Color(0xFFFFCDD2), // Light Red
    Color(0xFFEF9A9A),
    Color(0xFFF8BBD0), // Light Fuchsia
    Color(0xFFF48FB1),

    // Row 6: Light gray
    Color(0xFFCFD8DC), // Light Blue Gray
    Color(0xFFB0BEC5),
    Color(0xFFE0E0E0), // Light Gray
    Color(0xFFBDBDBD),
    Color(0xFFEEEEEE), // Off White
    Color(0xFFF5F5F5),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // Back key closes without applying color
      },
      child: Dialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.5),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title bar
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings?.customColorPicker.toUpperCase() ?? 'CUSTOM COLOR PICKER',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  TVFocusable(
                    onSelect: () => Navigator.pop(context),
                    focusScale: 1.1,
                    showFocusBorder: false,
                    builder: (context, isFocused, child) {
                      return AnimatedContainer(
                        duration: AppTheme.animationFast,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isFocused
                              ? Colors.white
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.close_rounded, size: 20, color: isFocused ? Colors.black : Colors.white60),
                      );
                    },
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Current color preview
              GlassCard(
                radius: AppTheme.radiusMedium,
                padding: EdgeInsets.zero,
                child: _buildColorPreview(),
              ),
              const SizedBox(height: 24),
              
              // Color palette
              Expanded(
                child: _buildColorPalette(),
              ),
              
              const SizedBox(height: 16),
              
              // Hint text
              Center(
                child: Text(
                  'Press OK to apply · Press Back to cancel',
                  style: TextStyle(
                    color: AppTheme.getTextMuted(context),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build color preview area
  Widget _buildColorPreview() {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: _selectedColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _selectedColor.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.of(context)?.selectedColor ?? 'Selected Color',
              style: TextStyle(
                color: _getContrastColor(_selectedColor),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
              style: TextStyle(
                color: _getContrastColor(_selectedColor),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Color palette
  Widget _buildColorPalette() {
    return FocusTraversalGroup(
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: _presetColors.length,
        itemBuilder: (context, index) {
          final color = _presetColors[index];
          final isSelected = color.value == _selectedColor.value;
          
          return TVFocusable(
            focusNode: index == 0 ? _firstColorFocusNode : null,
            autofocus: index == 0,
            onSelect: () {
              // Press OK to apply color directly
              setState(() {
                _selectedColor = color;
              });
              _applyColor(context);
            },
            focusScale: 1.0,
            showFocusBorder: false,
            builder: (context, isFocused, child) {
              // Determine border color based on luminance
              final isLightColor = _isLightColor(color);
              final borderColor = isLightColor ? Colors.black : Colors.white;
              
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                        ? borderColor
                        : isFocused
                            ? borderColor.withOpacity(0.8)
                            : Colors.transparent,
                    width: isSelected ? 3 : isFocused ? 2 : 1,
                  ),
                  boxShadow: [
                    if (isFocused || isSelected)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: isFocused ? 16 : 12,
                        spreadRadius: isFocused ? 3 : 2,
                      ),
                  ],
                ),
                child: child,
              );
            },
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                  _applyColor(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          color: _getContrastColor(color),
                          size: 28,
                        )
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Determine if color is light
  bool _isLightColor(Color color) {
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.7; // Threshold increased to 0.7, more accurate for light colors
  }

  /// Apply selected color
  void _applyColor(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final strings = AppStrings.of(context);

    // Create custom color scheme ID
    final customSchemeId = 'custom_${_selectedColor.value.toRadixString(16)}';

    // Save based on current theme mode
    final isDarkMode = _isDarkMode(context, settings);
    if (isDarkMode) {
      settings.setDarkColorScheme(customSchemeId);
    } else {
      settings.setLightColorScheme(customSchemeId);
    }

    // Close Custom Color Picker Dialog
    Navigator.pop(context);

    // Delay closing color scheme dialog, ensure first dialog is closed
    Future.delayed(const Duration(milliseconds: 100), () {
      if (context.mounted) {
        // Close color scheme dialog
        Navigator.pop(context);
        
        // Show success hint
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings?.customColorApplied ?? 'Custom color applied',
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  /// Determine if currently in dark mode
  bool _isDarkMode(BuildContext context, SettingsProvider settings) {
    if (settings.themeMode == 'dark') {
      return true;
    } else if (settings.themeMode == 'light') {
      return false;
    } else {
      final brightness = MediaQuery.of(context).platformBrightness;
      return brightness == Brightness.dark;
    }
  }

  /// Get contrast color (for text)
  Color _getContrastColor(Color color) {
    // Calculate luminance
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
