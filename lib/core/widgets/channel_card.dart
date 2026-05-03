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
      onFocus: () {
        setState(() => _isFocused = true);
        widget.onFocused?.call(true);
      },
      onBlur: () {
        setState(() => _isFocused = false);
        widget.onFocused?.call(false);
      },
      onSelect: widget.onTap,
      onLeft: widget.onLeft,
      onUp: widget.onUp,
      onDown: widget.onDown,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedScale(
            scale: (_isFocused || _isHovered) ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: AppTheme.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(
                  color: (_isFocused || _isHovered)
                      ? Colors.white
                      : Colors.white.withOpacity(0.05),
                  width: (_isFocused || _isHovered) ? 2.5 : 1,
                ),
                boxShadow: (_isFocused || _isHovered)
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                          offset: const Offset(0, 12),
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Logo fills card
                  _buildPosterLogo(isMobile),
                  // Bottom gradient overlay - Modern sleek fade
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Container(
                      height: isMobile ? 44 : 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.9),
                          ],
                          stops: const [0.0, 0.8],
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 12,
                        vertical: isMobile ? 6 : 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            widget.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 11 : 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          if (widget.currentProgram != null && widget.currentProgram!.isNotEmpty)
                            Text(
                              widget.currentProgram!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: isMobile ? 9 : 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          else if (widget.groupName != null && widget.groupName!.isNotEmpty)
                            Text(
                              widget.groupName!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: isMobile ? 9 : 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Favorite badge (top-right)
                  if (widget.isFavorite)
                    Positioned(
                      top: 4, right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.favorite,
                          color: Colors.redAccent,
                          size: isMobile ? 10 : 14,
                        ),
                      ),
                    ),
                  // Unavailable badge
                  if (widget.isUnavailable)
                    Positioned(
                      top: 4, left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'N/A',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 7 : 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterLogo(bool isMobile) {
    return Container(
      color: AppTheme.getSurfaceColor(context),
      child: widget.logoUrl != null && widget.logoUrl!.isNotEmpty
          ? Image.network(
              widget.logoUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(Icons.tv,
                    color: AppTheme.getPrimaryColor(context),
                    size: isMobile ? 28 : 36),
              ),
            )
          : Center(
              child: Icon(Icons.tv,
                  color: AppTheme.getPrimaryColor(context),
                  size: isMobile ? 28 : 36),
            ),
    );
  }
}
