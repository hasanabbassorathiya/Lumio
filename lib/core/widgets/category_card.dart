import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../platform/platform_detector.dart';
import 'tv_focusable.dart';

/// A category chip/card for the home screen
/// TV optimization: no effects
class CategoryCard extends StatelessWidget {
  final String name;
  final int channelCount;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool autofocus;
  final FocusNode? focusNode;

  const CategoryCard({
    super.key,
    required this.name,
    required this.channelCount,
    this.icon = Icons.folder_rounded,
    this.color,
    this.onTap,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppTheme.getPrimaryColor(context);
    final isTV = PlatformDetector.isTV;

    return TVFocusable(
      autofocus: autofocus,
      focusNode: focusNode,
      onSelect: onTap,
      focusScale: isTV ? 1.0 : 1.03,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          decoration: BoxDecoration(
            color: isFocused
                ? Colors.white
                : AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: isFocused ? Colors.white : Colors.white.withOpacity(0.05),
              width: 2.0,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Builder(builder: (context) {
              final isFocused = Focus.of(context).hasFocus;
              return AnimatedContainer(
                duration: AppTheme.animationFast,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isFocused ? Colors.black.withOpacity(0.1) : AppTheme.getPrimaryColor(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: isFocused ? Colors.black : AppTheme.getPrimaryColor(context), size: 22),
              );
            }),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(builder: (context) {
                  final isFocused = Focus.of(context).hasFocus;
                  return Text(
                    name.toUpperCase(),
                    style: TextStyle(
                      color: isFocused ? Colors.black : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }),
                const SizedBox(height: 4),
                Builder(builder: (context) {
                  final isFocused = Focus.of(context).hasFocus;
                  return Text(
                    '$channelCount CHANNELS',
                    style: TextStyle(
                      color: isFocused ? Colors.black54 : Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData getIconForCategory(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('sport') || lowerName.contains('sports')) return Icons.sports_soccer_rounded;
    if (lowerName.contains('movie') || lowerName.contains('movie')) return Icons.movie_rounded;
    if (lowerName.contains('news') || lowerName.contains('news')) return Icons.newspaper_rounded;
    if (lowerName.contains('music') || lowerName.contains('music')) return Icons.music_note_rounded;
    if (lowerName.contains('kid') || lowerName.contains('kids')) return Icons.child_care_rounded;
    if (lowerName.contains('cctv') || lowerName.contains('cctv')) return Icons.account_balance_rounded;
    if (lowerName.contains('satellite')) return Icons.satellite_alt_rounded;
    return Icons.live_tv_rounded;
  }

  static Color getColorForIndex(int index) {
    final colors = [
      const Color(0xFFE91E8C),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFF4CAF50),
      const Color(0xFFFF5722),
      const Color(0xFF3F51B5),
    ];
    return colors[index % colors.length];
  }
}
