import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/color_scheme_data.dart';
import '../i18n/app_strings.dart';
import 'tv_focusable.dart';

/// Color scheme card component
/// Displays a preview and name of a single color scheme
class ColorSchemeCard extends StatelessWidget {
  final ColorSchemeData scheme;
  final bool isSelected;
  final VoidCallback onTap;

  const ColorSchemeCard({
    super.key,
    required this.scheme,
    required this.isSelected,
    required this.onTap,
  });

  String _getColorSchemeName(BuildContext context) {
    final strings = AppStrings.of(context);
    switch (scheme.nameKey) {
      case 'colorSchemeLumio':
        return strings?.colorSchemeLumio ?? 'Lumio';
      case 'colorSchemeOcean':
        return strings?.colorSchemeOcean ?? 'Ocean';
      case 'colorSchemeForest':
        return strings?.colorSchemeForest ?? 'Forest';
      case 'colorSchemeSunset':
        return strings?.colorSchemeSunset ?? 'Sunset';
      case 'colorSchemeLavender':
        return strings?.colorSchemeLavender ?? 'Lavender';
      case 'colorSchemeMidnight':
        return strings?.colorSchemeMidnight ?? 'Midnight';
      case 'colorSchemeLumioLight':
        return strings?.colorSchemeLumioLight ?? 'Lumio Light';
      case 'colorSchemeSky':
        return strings?.colorSchemeSky ?? 'Sky';
      case 'colorSchemeSpring':
        return strings?.colorSchemeSpring ?? 'Spring';
      case 'colorSchemeCoral':
        return strings?.colorSchemeCoral ?? 'Coral';
      case 'colorSchemeViolet':
        return strings?.colorSchemeViolet ?? 'Violet';
      case 'colorSchemeClassic':
        return strings?.colorSchemeClassic ?? 'Classic';
      default:
        return scheme.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TVFocusable(
      onSelect: onTap,
      focusScale: 1.05,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused ? Colors.white : (isSelected ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
              width: 2.0,
            ),
            boxShadow: isFocused ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ] : null,
          ),
          child: child,
        );
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            gradient: scheme.gradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Gradient preview area (70%)
              const Spacer(flex: 7),

              // Name and selection indicator area (30%)
              Builder(builder: (context) {
                final isFocused = Focus.of(context).hasFocus;
                return AnimatedContainer(
                  duration: AppTheme.animationFast,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isFocused ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.6),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getColorSchemeName(context).toUpperCase(),
                          style: TextStyle(
                            color: isFocused ? Colors.black : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          color: isFocused ? Colors.black : Colors.white,
                          size: 18,
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
