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
        return Container(
          decoration: BoxDecoration(
            gradient: isFocused ? LinearGradient(colors: [cardColor.withAlpha(180), cardColor.withAlpha(120)]) : LinearGradient(colors: [cardColor.withAlpha(60), cardColor.withAlpha(30)]),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isFocused ? AppTheme.getPrimaryColor(context).withAlpha(200) : AppTheme.getGlassBorderColor(context),
              width: isFocused ? 2 : 1,
            ),
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('$channelCount Channels', style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11)),
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
