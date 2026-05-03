import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_update.dart';
import '../i18n/app_strings.dart';
// Comment out unused import
// import '../services/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final AppUpdate update;
  final VoidCallback onUpdate;
  final VoidCallback onCancel;

  const UpdateDialog({
    super.key,
    required this.update,
    required this.onUpdate,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        radius: AppTheme.radiusLarge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.getPrimaryColor(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(
                    Icons.system_update,
                    color: AppTheme.getPrimaryColor(context),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.of(context)?.newVersionAvailable ?? 'New version available',
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'v${update.version}',
                        style: TextStyle(
                          color: AppTheme.getPrimaryColor(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Release Notes
            Text(
              AppStrings.of(context)?.whatsNew ?? 'What\'s new',
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(
                  _formatReleaseNotes(update.releaseNotes),
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppStrings.of(context)?.updateLater.toUpperCase() ?? 'LATER',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'UPDATE NOW',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatReleaseNotes(String notes) {
    if (notes.isEmpty) {
      // Can't access context here directly, use a default
      return 'No release notes';
    }

    // Simple Markdown formatting
    String formatted = notes;

    // Remove redundant empty lines
    formatted = formatted.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');

    // Handle list items
    formatted = formatted.replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ');

    // Handle headers
    formatted = formatted.replaceAll(RegExp(r'^\s*#+\s+(.+)$', multiLine: true), '\\1');

    return formatted.trim();
  }
}
