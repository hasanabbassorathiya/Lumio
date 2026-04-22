import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../navigation/app_router.dart';
import '../i18n/app_strings.dart';
import 'tv_focusable.dart';
import 'channel_logo_widget.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../services/service_locator.dart';

/// TV side shared sidebar component
/// Collapse on blur, expand on focus
class TVSidebar extends StatefulWidget {
  final int selectedIndex;
  final Widget child;
  final VoidCallback? onRight; // Callback for right key

  /// For external access to menu focus nodes
  static List<FocusNode>? menuFocusNodes;

  /// Currently selected menu index
  static int? selectedMenuIndex;

  const TVSidebar({
    super.key,
    required this.selectedIndex,
    required this.child,
    this.onRight,
  });

  @override
  State<TVSidebar> createState() => _TVSidebarState();
}

class _TVSidebarState extends State<TVSidebar> {
  final List<FocusNode> _menuFocusNodes = [];
  Timer? _navDelayTimer; // Delayed navigation timer
  int? _pendingNavIndex; // Pending navigation index

  @override
  void initState() {
    super.initState();
    // Create focus nodes for 6 menu items
    for (int i = 0; i < 6; i++) {
      _menuFocusNodes.add(FocusNode());
    }
    // Expose to external
    TVSidebar.menuFocusNodes = _menuFocusNodes;
    TVSidebar.selectedMenuIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(TVSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      TVSidebar.selectedMenuIndex = widget.selectedIndex;
    }
  }

  @override
  void dispose() {
    _navDelayTimer?.cancel();
    for (final node in _menuFocusNodes) {
      node.dispose();
    }
    // TVSidebar.menuFocusNodes = null;
    // TVSidebar.selectedMenuIndex = null;
    super.dispose();
  }

  List<_NavItem> _getNavItems(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.home_rounded, label: AppStrings.of(context)?.home ?? 'Home', route: null),
      _NavItem(icon: Icons.live_tv_rounded, label: AppStrings.of(context)?.channels ?? 'Channels', route: AppRouter.channels),
      _NavItem(icon: Icons.playlist_play_rounded, label: AppStrings.of(context)?.playlistList ?? 'Playlist List', route: AppRouter.playlistList),
      _NavItem(icon: Icons.favorite_rounded, label: AppStrings.of(context)?.favorites ?? 'Favorites', route: AppRouter.favorites),
      _NavItem(icon: Icons.search_rounded, label: AppStrings.of(context)?.search ?? 'Search', route: AppRouter.search),
      _NavItem(icon: Icons.settings_rounded, label: AppStrings.of(context)?.settings ?? 'Settings', route: AppRouter.settings),
    ];
    ServiceLocator.log.d('TVSidebar: _getNavItems returned ${items.length} items');
    return items;
  }

  void _onNavItemTap(int index, String? route) {
    if (index == widget.selectedIndex) return;

    // Clear logo loading queue on page switch
    clearLogoLoadingQueue();

    if (index == 0) {
      // Return home: pop until home
      Navigator.of(context).popUntil((r) => r.settings.name == AppRouter.home || r.isFirst);
    } else if (route != null) {
      if (widget.selectedIndex == 0) {
        // Push from home screen
        Navigator.pushNamed(context, route);
      } else {
        // Replacement push from other pages
        Navigator.pushReplacementNamed(context, route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _getNavItems(context);
    // Real-time reading of Simple Menu settings
    final simpleMenu = context.watch<SettingsProvider>().simpleMenu;
    // Decide whether to expand based on Simple Menu settings
    // Simple mode: Always collapsed, Non-simple mode: Always expanded
    final shouldExpand = !simpleMenu;
    final width = shouldExpand ? 150.0 : 52.0;

    return Row(
      children: [
        // Sidebar
        Focus(
          onFocusChange: (hasFocus) {
            // Auto-focus current selected menu item when Sidebar gains focus
            if (hasFocus && widget.selectedIndex < _menuFocusNodes.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final targetNode = _menuFocusNodes[widget.selectedIndex];
                if (targetNode.canRequestFocus && !targetNode.hasFocus) {
                  targetNode.requestFocus();
                }
              });
            }
          },
          child: Container(
            width: width,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [
                        AppTheme.getBackgroundColor(context),
                        AppTheme.getPrimaryColor(context).withOpacity(0.15),
                        AppTheme.getBackgroundColor(context),
                      ]
                    : [
                        AppTheme.getBackgroundColor(context),
                        AppTheme.getBackgroundColor(context).withOpacity(0.9),
                        AppTheme.getPrimaryColor(context).withOpacity(0.08),
                      ],
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Logo
                _buildLogo(),
                const SizedBox(height: 16),
                // Nav Items
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: shouldExpand ? 6 : 4),
                    itemCount: navItems.length,
                    itemBuilder: (context, index) => _buildNavItem(index, navItems[index]),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        // Main content
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _buildLogo() {
    // Real-time reading of Simple Menu settings
    final simpleMenu = context.watch<SettingsProvider>().simpleMenu;
    final shouldExpand = !simpleMenu;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: shouldExpand ? 10 : 8),
      child: shouldExpand
          ? Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset('assets/icons/app_icon.png', width: 24, height: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => AppTheme.getGradient(context).createShader(bounds),
                    child: const Text('Lotus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            )
          : Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/icons/app_icon.png', width: 24, height: 24),
              ),
            ),
    );
  }

  Widget _buildNavItem(int index, _NavItem item) {
    final isSelected = widget.selectedIndex == index;
    final focusNode = index < _menuFocusNodes.length ? _menuFocusNodes[index] : null;
    // Real-time reading of Simple Menu settings
    final simpleMenu = context.watch<SettingsProvider>().simpleMenu;
    final shouldExpand = !simpleMenu;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Focus(
        focusNode: focusNode,
        autofocus: index == widget.selectedIndex,
        onFocusChange: (hasFocus) {
          // Force UI refresh
          if (mounted) setState(() {});

          // Delayed navigation trigger
          if (hasFocus && index != widget.selectedIndex) {
            _navDelayTimer?.cancel();
            _pendingNavIndex = index;
            _navDelayTimer = Timer(const Duration(milliseconds: 500), () {
              if (mounted && _pendingNavIndex == index) {
                _onNavItemTap(index, item.route);
              }
            });
          } else if (!hasFocus && _pendingNavIndex == index) {
            // Cancel pending navigation on blur
            _navDelayTimer?.cancel();
            _pendingNavIndex = null;
          }
        },
        onKey: (node, event) {
          final key = event.logicalKey;

          // Handle select key
          if (event is KeyDownEvent && (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space)) {
            // Navigate immediately on manual confirm, cancel delay
            _navDelayTimer?.cancel();
            _pendingNavIndex = null;
            _onNavItemTap(index, item.route);
            return KeyEventResult.handled;
          }

          // Handle right key
          if (event is KeyDownEvent && key == LogicalKeyboardKey.arrowRight && widget.onRight != null) {
            // Cancel delayed navigation on right key
            _navDelayTimer?.cancel();
            _pendingNavIndex = null;
            widget.onRight!();
            return KeyEventResult.handled;
          }

          // Prevent directional navigation at boundaries - handles both KeyDown and KeyUp
          if (key == LogicalKeyboardKey.arrowUp && index == 0) {
            // Prevent UP from first item
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown && index == 5) {
            // Prevent DOWN from last item
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _onNavItemTap(index, item.route),
            child: Builder(
              builder: (context) {
                // Directly check actual focus status of FocusNode
                final isFocused = focusNode?.hasFocus ?? false;
                // Highlight current selected item（using gradient background）
                // Show highlight if focused but not selected
                final showSelectedHighlight = isSelected;
                final showFocusHighlight = isFocused && !isSelected;

                return Container(
                  padding: EdgeInsets.symmetric(horizontal: shouldExpand ? 10 : 8, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: (showSelectedHighlight || showFocusHighlight) ? AppTheme.getGradient(context) : null,
                    borderRadius: BorderRadius.circular(8),
                    // Show border whenever focused
                    border: isFocused
                        ? Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 2,
                          )
                        : null,
                  ),
                  child: shouldExpand
                      ? Row(
                          children: [
                            Icon(item.icon, color: (showSelectedHighlight || showFocusHighlight) ? Colors.white : AppTheme.getTextMuted(context), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(item.label,
                                  style: TextStyle(
                                    color: (showSelectedHighlight || showFocusHighlight) ? Colors.white : AppTheme.getTextSecondary(context),
                                    fontSize: 12,
                                    fontWeight: (showSelectedHighlight || showFocusHighlight) ? FontWeight.w600 : FontWeight.normal,
                                  )),
                            ),
                          ],
                        )
                      : Center(child: Icon(item.icon, color: (showSelectedHighlight || showFocusHighlight) ? Colors.white : (isSelected ? AppTheme.getPrimaryColor(context) : AppTheme.getTextMuted(context)), size: 18)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String? route;
  const _NavItem({required this.icon, required this.label, required this.route});
}
