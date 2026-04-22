import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'tv_focusable.dart';

class ChannelCard extends StatefulWidget {
  final String name;
  final String? logoUrl;
  final String? currentProgram;
  final String? nextProgram;
  final String? groupName;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isFavorite;
  final bool isUnavailable;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocused;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onLeft;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onTest;
  final VoidCallback? onLongPress;

  const ChannelCard({
    super.key,
    required this.name,
    this.logoUrl,
    this.currentProgram,
    this.nextProgram,
    this.groupName,
    required this.onTap,
    this.isSelected = false,
    this.isFavorite = false,
    this.isUnavailable = false,
    this.autofocus = false,
    this.focusNode,
    this.onFocused,
    this.onFavoriteToggle,
    this.onLeft,
    this.onUp,
    this.onDown,
    this.onTest,
    this.onLongPress,
    // Note: We removed the 'channel' prop as it's not being used inside this widget
    // to avoid discrepancies between different model types across the app.
  });

  @override
  State<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<ChannelCard> {
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return TVFocusable(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      // Fixed: TVFocusable in this project uses onFocusChange instead of onFocusChange (Wait, the lint said onFocusChange isn't defined?)
      // I will check tv_focusable.dart to be sure.
      onFocus: () {
        setState(() => _isFocused = true);
        widget.onFocused?.call(true);
      },
      onBlur: () {
        setState(() => _isFocused = false);
        widget.onFocused?.call(false);
      },
      onSelect: widget.onTap,
      // onLongSelect was mentioned as not defined.
      onLeft: widget.onLeft,
      onUp: widget.onUp,
      onDown: widget.onDown,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppTheme.getPrimaryColor(context).withOpacity(0.2)
                  : (_isFocused || _isHovered
                      ? AppTheme.getSurfaceColor(context)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isSelected
                    ? AppTheme.getPrimaryColor(context)
                    : (_isFocused || _isHovered
                        ? AppTheme.getPrimaryColor(context).withOpacity(0.5)
                        : Colors.transparent),
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                _buildLogo(isMobile),
                const SizedBox(width: 12),
                _buildInfoSection(context, isMobile),
                if (widget.isFavorite)
                  Icon(Icons.favorite,
                      color: AppTheme.getPrimaryColor(context), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isMobile) {
    return Container(
      width: isMobile ? 40 : 50,
      height: isMobile ? 40 : 50,
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: widget.logoUrl != null && widget.logoUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.logoUrl!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.tv,
                    color: AppTheme.getPrimaryColor(context),
                    size: isMobile ? 24 : 30),
              ),
            )
          : Icon(Icons.tv,
              color: AppTheme.getPrimaryColor(context),
              size: isMobile ? 24 : 30),
    );
  }

  Widget _buildInfoSection(BuildContext context, bool isMobile) {
    final hasCurrentProgram =
        widget.currentProgram != null && widget.currentProgram!.isNotEmpty;
    final hasGroup = widget.groupName != null && widget.groupName!.isNotEmpty;

    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.name,
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (hasCurrentProgram) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.play_circle_filled,
                    color: AppTheme.getPrimaryColor(context), size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.currentProgram!,
                    style: TextStyle(
                      color: AppTheme.getPrimaryColor(context),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ] else if (hasGroup) ...[
            const SizedBox(height: 2),
            Text(
              widget.groupName!,
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
