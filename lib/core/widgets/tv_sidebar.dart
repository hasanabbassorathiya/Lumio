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
    final width = shouldExpand ? 160.0 : 64.0;

    return Row(
      children: [
        // Sidebar
        Focus(
          onFocusChange: (hasFocus) {
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
              color: AppTheme.getBackgroundColor(context),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Logo
                _buildLogo(),
                const SizedBox(height: 32),
                // Nav Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: navItems.length,
                    itemBuilder: (context, index) => _buildNavItem(index, navItems[index]),
                  ),
                ),
                const SizedBox(height: 16),
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
    final simpleMenu = context.watch<SettingsProvider>().simpleMenu;
    final shouldExpand = !simpleMenu;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: shouldExpand ? 16 : 0),
      child: shouldExpand
          ? Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/icons/app_icon.png', width: 28, height: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'LUMIO',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/icons/app_icon.png', width: 28, height: 28),
              ),
            ),
    );
  }

  Widget _buildNavItem(int index, _NavItem item) {
    final isSelected = widget.selectedIndex == index;
    final focusNode = index < _menuFocusNodes.length ? _menuFocusNodes[index] : null;
    final simpleMenu = context.watch<SettingsProvider>().simpleMenu;
    final shouldExpand = !simpleMenu;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Focus(
        focusNode: focusNode,
        autofocus: index == widget.selectedIndex,
        onFocusChange: (hasFocus) {
          if (mounted) setState(() {});
          if (hasFocus && index != widget.selectedIndex) {
            _navDelayTimer?.cancel();
            _pendingNavIndex = index;
            _navDelayTimer = Timer(const Duration(milliseconds: 500), () {
              if (mounted && _pendingNavIndex == index) {
                _onNavItemTap(index, item.route);
              }
            });
          } else if (!hasFocus && _pendingNavIndex == index) {
            _navDelayTimer?.cancel();
            _pendingNavIndex = null;
          }
        },
        onKey: (node, event) {
          final key = event.logicalKey;
          if (event is KeyDownEvent && (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space)) {
            _navDelayTimer?.cancel();
            _pendingNavIndex = null;
            _onNavItemTap(index, item.route);
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent && key == LogicalKeyboardKey.arrowRight && widget.onRight != null) {
            _navDelayTimer?.cancel();
            _pendingNavIndex = null;
            widget.onRight!();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp && index == 0) return KeyEventResult.handled;
          if (key == LogicalKeyboardKey.arrowDown && index == 5) return KeyEventResult.handled;
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _onNavItemTap(index, item.route),
            child: Builder(
              builder: (context) {
                final isFocused = focusNode?.hasFocus ?? false;

                return AnimatedScale(
                  scale: isFocused ? 1.1 : 1.0,
                  duration: AppTheme.animationFast,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: shouldExpand ? 12 : 8,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isFocused
                          ? Colors.white
                          : (isSelected ? AppTheme.getPrimaryColor(context).withOpacity(0.1) : Colors.transparent),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFocused ? Colors.white : Colors.transparent,
                        width: 2.0,
                      ),
                    ),
                    child: shouldExpand
                        ? Row(
                            children: [
                              Icon(
                                item.icon,
                                color: isFocused ? Colors.black : (isSelected ? AppTheme.getPrimaryColor(context) : Colors.white60),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label.toUpperCase(),
                                  style: TextStyle(
                                    color: isFocused ? Colors.black : (isSelected ? Colors.white : Colors.white60),
                                    fontSize: 12,
                                    fontWeight: isFocused || isSelected ? FontWeight.w900 : FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Icon(
                              item.icon,
                              color: isFocused ? Colors.black : (isSelected ? AppTheme.getPrimaryColor(context) : Colors.white60),
                              size: 22,
                            ),
                          ),
                  ),
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
