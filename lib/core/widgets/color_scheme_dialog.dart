import 'package:flutter/material.dart';
import '../../features/settings/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/color_scheme_manager.dart';
import '../i18n/app_strings.dart';
import 'color_scheme_card.dart';

/// Color scheme selection dialog
class ColorSchemeDialog extends StatelessWidget {
  const ColorSchemeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final strings = AppStrings.of(context);
    final manager = ColorSchemeManager.instance;

    final isDarkMode = settings.themeMode == 'dark' ||
        (settings.themeMode == 'system' &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final schemes =
        isDarkMode ? manager.getAllDarkSchemes() : manager.getAllLightSchemes();
    final currentSchemeId =
        isDarkMode ? settings.darkColorScheme : settings.lightColorScheme;

    return AlertDialog(
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      contentPadding: EdgeInsets.zero,
      content: GlassCard(
        radius: AppTheme.radiusLarge,
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 400,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.5,
            ),
            itemCount: schemes.length,
            itemBuilder: (context, index) {
              final scheme = schemes[index];
              return ColorSchemeCard(
                scheme: scheme,
                isSelected: scheme.id == currentSchemeId,
                onTap: () {
                  if (isDarkMode) {
                    settings.setDarkColorScheme(scheme.id);
                  } else {
                    settings.setLightColorScheme(scheme.id);
                  }
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
