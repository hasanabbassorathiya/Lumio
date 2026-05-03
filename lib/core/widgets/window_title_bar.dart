import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_theme.dart';
import '../platform/windows_pip_channel.dart';

/// Auto-hiding Windows title bar
/// Show when hovering top, hide otherwise
class WindowTitleBar extends StatefulWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  const WindowTitleBar({
    super.key,
    this.title = 'Lumio IPTV',
    this.leading,
    this.actions,
  });

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> {
  bool _isVisible = false;
  Timer? _hideTimer;

  // Trigger zone height（Mouse entering this zone shows title bar）
  static const double _triggerHeight = 8.0;
  // Title bar height
  static const double _barHeight = 32.0;
  // Auto-hide delay
  static const Duration _hideDelay = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    // Listen for mini mode state changes
    WindowsPipChannel.pipModeNotifier.addListener(_onPipModeChanged);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    WindowsPipChannel.pipModeNotifier.removeListener(_onPipModeChanged);
    super.dispose();
  }

  void _onPipModeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showTitleBar() {
    _hideTimer?.cancel();
    if (!_isVisible) {
      setState(() => _isVisible = true);
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (mounted) {
        setState(() => _isVisible = false);
      }
    });
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return const SizedBox.shrink();
    }

    // Completely hide title bar in Mini mode
    if (WindowsPipChannel.isInPipMode) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Trigger zone (always exists to detect mouse entering)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _triggerHeight,
          child: MouseRegion(
            onEnter: (_) => _showTitleBar(),
            onExit: (_) => _startHideTimer(),
            child: Container(color: Colors.transparent),
          ),
        ),
        // Title bar (animated)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          top: _isVisible ? 0 : -_barHeight,
          left: 0,
          right: 0,
          height: _barHeight,
          child: MouseRegion(
            onEnter: (_) => _cancelHideTimer(),
            onExit: (_) => _startHideTimer(),
            child: GestureDetector(
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: Container(
                height: _barHeight,
                decoration: BoxDecoration(
                  color: AppTheme.getSurfaceColor(context),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    // App icon
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        width: 18,
                        height: 18,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.live_tv,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Title
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    // Draggable area
                    const Expanded(child: SizedBox()),
                    // Window buttons
                    _WindowButton(
                      icon: Icons.remove,
                      onPressed: () => windowManager.minimize(),
                    ),
                    _MaximizeButton(),
                    _WindowButton(
                      icon: Icons.close,
                      hoverColor: Colors.red,
                      onPressed: () => windowManager.close(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? hoverColor;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.hoverColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32,
          color: _isHovered ? (widget.hoverColor ?? const Color(0x33FFFFFF)) : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered && widget.hoverColor != null ? Colors.white : AppTheme.getTextSecondary(context),
          ),
        ),
      ),
    );
  }
}

class _MaximizeButton extends StatefulWidget {
  @override
  State<_MaximizeButton> createState() => _MaximizeButtonState();
}

class _MaximizeButtonState extends State<_MaximizeButton> {
  bool _isHovered = false;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _checkMaximized();
  }

  Future<void> _checkMaximized() async {
    _isMaximized = await windowManager.isMaximized();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () async {
          if (_isMaximized) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
          _checkMaximized();
        },
        child: Container(
          width: 46,
          height: 32,
          color: _isHovered ? const Color(0x33FFFFFF) : Colors.transparent,
          child: Icon(
            _isMaximized ? Icons.filter_none : Icons.crop_square,
            size: 14,
            color: AppTheme.getTextSecondary(context),
          ),
        ),
      ),
    );
  }
}
