import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/widgets/channel_card.dart';
import '../../../core/widgets/category_card.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/platform/native_player_channel.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/channel_test_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/background_test_service.dart';
import '../../../core/models/channel.dart';
import '../../../core/utils/card_size_calculator.dart';
import '../providers/channel_provider.dart';
import '../widgets/channel_test_dialog.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';
import '../../multi_screen/providers/multi_screen_provider.dart';

class ChannelsScreen extends StatefulWidget {
  final String? groupName;
  final bool embedded; // Whether embedded in home bottom navigation
  final bool forceShowBackButton; // New: force show back button for mobile

  const ChannelsScreen({
    super.key,
    this.groupName,
    this.embedded = false,
    this.forceShowBackButton = false,
  });

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  String? _selectedGroup;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _groupScrollController = ScrollController();

  // For TV side category focus management
  final List<FocusNode> _groupFocusNodes = [];
  final List<FocusNode> _channelFocusNodes = [];
  int _currentGroupIndex = 0;
  int _lastChannelIndex = 0; // Remember last focused channel index

  // Timer for delayed category selection
  Timer? _groupSelectTimer;

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.groupName;

    // Clear category filter in embedded mode, show all channels
    if (widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ChannelProvider>().clearGroupFilter();
      });
    } else if (_selectedGroup != null) {
      context.read<ChannelProvider>().selectGroup(_selectedGroup!);

      // If jumped from home "More" button, delay focus jump to first channel
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (PlatformDetector.isTV) {
          // Delay a bit to ensure UI is fully built
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              // Find index of corresponding category
              final provider = context.read<ChannelProvider>();
              final groupIndex =
                  provider.groups.indexWhere((g) => g.name == _selectedGroup);
              if (groupIndex >= 0) {
                // +1 because the first is "All Channels"
                _currentGroupIndex = groupIndex + 1;
              }

              // Jump focus to first channel and remember index
              if (_channelFocusNodes.isNotEmpty) {
                _lastChannelIndex = 0; // Remember it is the first channel
                _channelFocusNodes[0].requestFocus();
              }
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _groupSelectTimer?.cancel();
    _scrollController.dispose();
    _groupScrollController.dispose();
    for (final node in _groupFocusNodes) {
      node.dispose();
    }
    for (final node in _channelFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    final content = Row(
      children: [
        // Groups Sidebar (for TV and Desktop)
        if (isTV) _buildGroupsSidebar(),
        // Channels Grid
        Expanded(child: _buildChannelsContent()),
      ],
    );

    if (isTV) {
      return Scaffold(
        body: Container(
          color: AppTheme.getBackgroundColor(context),
          child: TVSidebar(
            selectedIndex: 1, // Channels page
            onRight: () {
              // Press Right on main menu, jump to current category
              if (_groupFocusNodes.isNotEmpty &&
                  _currentGroupIndex < _groupFocusNodes.length) {
                _groupFocusNodes[_currentGroupIndex].requestFocus();
              }
            },
            child: content,
          ),
        ),
      );
    }

    // Embedded mode does not use Scaffold, return content directly
    if (widget.embedded) {
      final isMobile = PlatformDetector.isMobile;
      final isLandscape = isMobile && MediaQuery.of(context).size.width > 700;

      return Stack(
        children: [
          content,
          // Mobile embedded mode uses FAB to open categories
          Positioned(
            left: isLandscape ? 8 : 8, // Position in landscape
            top: isLandscape ? 12 : 16, // Fixed padding since it's already in a SafeArea in home
            child: Material(
              color: AppTheme.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(isLandscape ? 8 : 8), // Corner radius in landscape
              elevation: 2, // Add shadow to make it stand out
              child: InkWell(
                onTap: () => _showMobileGroupsBottomSheet(context),
                borderRadius: BorderRadius.circular(isLandscape ? 8 : 8),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 10 : 12, // Increased padding in landscape
                    vertical: isLandscape ? 6 : 8, // Increased padding in landscape
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_rounded,
                          color: AppTheme.getTextPrimary(context),
                          size: isLandscape ? 18 : 18), // Larger icon in landscape
                      const SizedBox(width: 6),
                      Text(
                        _selectedGroup ??
                            (AppStrings.of(context)?.allChannels ?? 'All'),
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontSize: isLandscape ? 14 : 13, // Larger font in landscape
                          fontWeight: FontWeight.w500, // Bold
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down,
                          color: AppTheme.getTextMuted(context),
                          size: isLandscape ? 18 : 18), // Larger icon in landscape
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: SafeArea(
        child: content,
      ),
      // Add category drawer for mobile
      drawer: _buildMobileGroupsDrawer(),
    );
  }

  /// Category bottom sheet for mobile embedded mode
  void _showMobileGroupsBottomSheet(BuildContext context) {
    final provider = context.read<ChannelProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              child: Text(
                AppStrings.of(context)?.categories ?? 'Categories',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildMobileGroupItem(
                    name: AppStrings.of(context)?.allChannels ?? 'All Channels',
                    count: provider.totalChannelCount,
                    isSelected: _selectedGroup == null,
                    onTap: () {
                      setState(() => _selectedGroup = null);
                      provider.clearGroupFilter();
                      Navigator.pop(ctx);
                    },
                  ),
                  ...provider.groups.map((group) => _buildMobileGroupItem(
                        name: group.name,
                        count: group.channelCount,
                        isSelected: _selectedGroup == group.name,
                        onTap: () {
                          setState(() => _selectedGroup = group.name);
                          provider.selectGroup(group.name);
                          Navigator.pop(ctx);
                        },
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsSidebar() {
    return Consumer<ChannelProvider>(
      builder: (context, provider, _) {
        // Ensure focus node count is correct (1 "All Channels" + category count)
        final totalGroups = provider.groups.length + 1;
        while (_groupFocusNodes.length < totalGroups) {
          _groupFocusNodes.add(FocusNode());
        }
        while (_groupFocusNodes.length > totalGroups) {
          _groupFocusNodes.removeLast().dispose();
        }

        return FocusTraversalGroup(
          child: Container(
            width: 240,
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.getSurfaceColor(context),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.03),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      TVFocusable(
                        onSelect: () => Navigator.of(context).pop(),
                        focusScale: 1.1,
                        showFocusBorder: false,
                        builder: (context, isFocused, child) {
                          return AnimatedContainer(
                            duration: AppTheme.animationFast,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isFocused ? Colors.white : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: isFocused ? Colors.black : Colors.white,
                              size: 20,
                            ),
                          );
                        },
                        child: const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        AppStrings.of(context)?.categories.toUpperCase() ?? 'CATEGORIES',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // All Channels Option
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: _buildGroupItem(
                    name: AppStrings.of(context)?.allChannels ?? 'All Channels',
                    count: provider.totalChannelCount,
                    isSelected: _selectedGroup == null,
                    focusNode: _groupFocusNodes.isNotEmpty
                        ? _groupFocusNodes[0]
                        : null,
                    groupIndex: 0,
                    onTap: () {
                      setState(() {
                        _selectedGroup = null;
                        _currentGroupIndex = 0;
                      });
                      provider.clearGroupFilter();
                    },
                  ),
                ),

                Divider(color: AppTheme.getCardColor(context), height: 1),

                // Groups List
                Expanded(
                  child: ListView.builder(
                    controller: _groupScrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: provider.groups.length,
                    itemBuilder: (context, index) {
                      final group = provider.groups[index];
                      final focusIndex = index + 1; // +1 because the first is "All Channels"
                      return _buildGroupItem(
                        name: group.name,
                        count: group.channelCount,
                        isSelected: _selectedGroup == group.name,
                        focusNode: focusIndex < _groupFocusNodes.length
                            ? _groupFocusNodes[focusIndex]
                            : null,
                        groupIndex: focusIndex,
                        onTap: () {
                          setState(() {
                            _selectedGroup = group.name;
                            _currentGroupIndex = focusIndex;
                          });
                          provider.selectGroup(group.name);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Mobile category drawer
  Widget _buildMobileGroupsDrawer() {
    return Consumer<ChannelProvider>(
      builder: (context, provider, _) {
        return Drawer(
          backgroundColor: AppTheme.getSurfaceColor(context),
          width: 220,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.getPrimaryColor(context),
                  ),
                  child: Text(
                    AppStrings.of(context)?.categories ?? 'Categories',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Image.asset('assets/icons/app_icon.jpg'),
                // All Channels Option
                _buildMobileGroupItem(
                  name: AppStrings.of(context)?.allChannels ?? 'All Channels',
                  count: provider.totalChannelCount,
                  isSelected: _selectedGroup == null,
                  onTap: () {
                    setState(() => _selectedGroup = null);
                    provider.clearGroupFilter();
                    Navigator.pop(context);
                  },
                ),

                const Divider(height: 1),

                // Groups List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: provider.groups.length,
                    itemBuilder: (context, index) {
                      final group = provider.groups[index];
                      return _buildMobileGroupItem(
                        name: group.name,
                        count: group.channelCount,
                        isSelected: _selectedGroup == group.name,
                        onTap: () {
                          setState(() => _selectedGroup = group.name);
                          provider.selectGroup(group.name);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Mobile category list item
  Widget _buildMobileGroupItem({
    required String name,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      leading: Icon(
        CategoryCard.getIconForCategory(name),
        color: isSelected
            ? AppTheme.getPrimaryColor(context)
            : AppTheme.getTextSecondary(context),
        size: 20,
      ),
      title: Text(
        name,
        style: TextStyle(
          color: isSelected
              ? AppTheme.getPrimaryColor(context)
              : AppTheme.getTextPrimary(context),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 13,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.getPrimaryColor(context).withOpacity(0.2)
              : AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          count.toString(),
          style: TextStyle(
            color: isSelected
                ? AppTheme.getPrimaryColor(context)
                : AppTheme.getTextMuted(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.getPrimaryColor(context).withOpacity(0.1),
      onTap: onTap,
    );
  }

  Widget _buildGroupItem({
    required String name,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    FocusNode? focusNode,
    int groupIndex = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: TVFocusable(
        focusNode: focusNode,
        onSelect: onTap,
        onFocus: PlatformDetector.isTV
            ? () {
                _currentGroupIndex = groupIndex;
                _groupSelectTimer?.cancel();
                _groupSelectTimer =
                    Timer(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    _lastChannelIndex = 0;
                    _scrollController.jumpTo(0);
                    onTap();
                  }
                });
              }
            : null,
        onRight: PlatformDetector.isTV
            ? () {
                if (_channelFocusNodes.isNotEmpty) {
                  final targetIndex =
                      _lastChannelIndex.clamp(0, _channelFocusNodes.length - 1);
                  _channelFocusNodes[targetIndex].requestFocus();
                }
              }
            : null,
        onLeft: PlatformDetector.isTV
            ? () {
                final menuNodes = TVSidebar.menuFocusNodes;
                if (menuNodes != null && menuNodes.length > 1) {
                  menuNodes[1].requestFocus();
                }
              }
            : null,
        focusScale: 1.05,
        showFocusBorder: false,
        builder: (context, isFocused, child) {
          final showHighlight = isSelected || isFocused;
          return AnimatedContainer(
            duration: AppTheme.animationFast,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isFocused
                  ? Colors.white
                  : (isSelected ? AppTheme.getPrimaryColor(context).withOpacity(0.15) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFocused ? Colors.white : (isSelected ? AppTheme.getPrimaryColor(context).withOpacity(0.5) : Colors.transparent),
                width: 2.0,
              ),
            ),
            child: Row(
              children: [
                // Selection dot indicator
                if (isSelected && !isFocused)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.getPrimaryColor(context),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.getPrimaryColor(context).withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),

                // Name
                Expanded(
                  child: Builder(builder: (context) {
                    final isFocused = Focus.of(context).hasFocus;
                    return Text(
                      name.toUpperCase(),
                      style: TextStyle(
                        color: isFocused ? Colors.black : (isSelected ? Colors.white : Colors.white60),
                        fontSize: 12,
                        fontWeight: (isFocused || isSelected) ? FontWeight.w900 : FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  }),
                ),

                // Count badge
                if (count > 0)
                  Builder(builder: (context) {
                    final isFocused = Focus.of(context).hasFocus;
                    return Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFocused ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: isFocused ? Colors.black54 : Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildChannelsContent() {
    return Consumer<ChannelProvider>(
      builder: (context, provider, _) {
        final channels = provider.filteredChannels;
        final isMobile = PlatformDetector.isMobile;
        final isLandscape = isMobile && MediaQuery.of(context).size.width > 700;

        // Refer to home screen settings, get status bar height and reduce spacing on mobile
        final statusBarHeight =
            isMobile ? MediaQuery.of(context).padding.top : 0.0;
        final topPadding = isMobile
            ? (statusBarHeight > 0 ? statusBarHeight - 15.0 : 0.0)
            : 0.0;

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              primary: true, // Enable auto SafeArea
              backgroundColor: Colors.transparent,
              toolbarHeight: isLandscape ? 40.0 : 64.0, // Increased height for better fit
              expandedHeight: 0,
              collapsedHeight: isLandscape ? 40.0 : 64.0, // Increased height
              titleSpacing: 16, // Add title spacing
              leadingWidth: isLandscape ? 40 : 56,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  color: AppTheme.getBackgroundColor(context),
                ),
              ),
              leading: isMobile
                  ? (widget.embedded
                      ? null // Embedded mode does not show menu button
                      : IconButton(
                          icon: Icon(
                              (Navigator.of(context).canPop() || widget.forceShowBackButton)
                                  ? Icons.arrow_back_rounded
                                  : Icons.menu_rounded,
                              color: AppTheme.getTextPrimary(context),
                              size: isLandscape ? 18 : 24),
                          padding: isLandscape ? const EdgeInsets.all(4) : null,
                          onPressed: () {
                            if (Navigator.of(context).canPop() || widget.forceShowBackButton) {
                              Navigator.pop(context);
                            } else {
                              Scaffold.of(context).openDrawer();
                            }
                          },
                        ))
                  : null,
              title: widget.embedded
                  ? null // Embedded mode does not show title (use FAB)
                  : Text(
                      _selectedGroup ??
                          (AppStrings.of(context)?.allChannels ??
                              'All Channels'),
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: isLandscape ? 13 : 20, // Smaller font in landscape
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              actions: [
                // Background test progress indicator
                _BackgroundTestIndicator(
                  onTap: () => _showBackgroundTestProgress(context),
                ),
                // Test channels button
                IconButton(
                  icon: const Icon(Icons.speed_rounded),
                  iconSize: isLandscape ? 16 : 24, // Smaller icon in landscape
                  padding: isLandscape
                      ? const EdgeInsets.all(2)
                      : null, // Reduce padding in landscape
                  color: AppTheme.getTextSecondary(context),
                  tooltip: "Test Channels",
                  onPressed: channels.isEmpty
                      ? null
                      : () => _showChannelTestDialog(context, channels),
                ),
                // Delete all unavailable channels button (only show when in unavailable group)
                if (_selectedGroup == ChannelProvider.unavailableGroupName &&
                    channels.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded),
                    iconSize: isLandscape ? 16 : 24, // Smaller icon in landscape
                    padding: isLandscape
                        ? const EdgeInsets.all(2)
                        : null, // Reduce padding in landscape
                    color: AppTheme.errorColor,
                    tooltip: "Delete all invalid channels",
                    onPressed: () =>
                        _confirmDeleteAllUnavailable(context, provider),
                  ),
                // Channel count badge
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 8 : 12,
                      vertical: isLandscape ? 4 : 6,
                    ),
                    margin: EdgeInsets.only(right: isLandscape ? 6 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                    ),
                    child: Text(
                      '${channels.length} CHANNELS',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isLandscape ? 8 : 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Channels Grid
            if (channels.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.live_tv_outlined,
                        size: 64,
                        color: AppTheme.getTextMuted(context).withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.of(context)?.noChannelsFound ??
                            'No channels found',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.only(
                  left: isMobile ? (isLandscape ? 4 : 8) : 20,
                  right: isMobile ? (isLandscape ? 4 : 8) : 20,
                  top: isMobile ? (isLandscape ? 4 : 8) : 20, // 4px top padding in landscape
                  bottom: isMobile ? (isLandscape ? 4 : 8) : 20,
                ),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.crossAxisExtent;
                    final crossAxisCount =
                        CardSizeCalculator.calculateCardsPerRow(availableWidth);

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: CardSizeCalculator.aspectRatio(),
                        crossAxisSpacing: CardSizeCalculator.spacing,
                        mainAxisSpacing: CardSizeCalculator.spacing,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final channel = channels[index];
                          final isFavorite = context
                              .watch<FavoritesProvider>()
                              .isFavorite(channel.id ?? 0);
                          final isUnavailable =
                              ChannelProvider.isUnavailableChannel(
                                  channel.groupName);

                          // Get EPG current and next programs
                          final epgProvider = context.watch<EpgProvider>();
                          final currentProgram = epgProvider.getCurrentProgram(
                              channel.epgId, channel.name);
                          final nextProgram = epgProvider.getNextProgram(
                              channel.epgId, channel.name);

                          // TV side: ensure focus node count is correct
                          if (PlatformDetector.isTV) {
                            while (_channelFocusNodes.length <= index) {
                              _channelFocusNodes.add(FocusNode());
                            }
                          }

                          // TV side: check if first column (need to handle Left navigation)
                          final isFirstColumn = index % crossAxisCount == 0;

                          // TV side: check if last row (need to handle Down to switch categories)
                          final totalRows =
                              (channels.length / crossAxisCount).ceil();
                          final currentRow = index ~/ crossAxisCount;
                          final isLastRow = currentRow == totalRows - 1;

                          return ChannelCard(
                            name: channel.name,
                            logoUrl: channel.logoUrl,
                            groupName: isUnavailable
                                ? ChannelProvider.extractOriginalGroup(
                                    channel.groupName)
                                : channel.groupName,
                            currentProgram: currentProgram?.title,
                            nextProgram: nextProgram?.title,
                            isFavorite: isFavorite,
                            isUnavailable: isUnavailable,
                            autofocus: index == 0,
                            focusNode: PlatformDetector.isTV &&
                                    index < _channelFocusNodes.length
                                ? _channelFocusNodes[index]
                                : null,
                            onFocused: PlatformDetector.isTV
                                ? (focused) {
                                    // Remember current focused channel index
                                    _lastChannelIndex = index;
                                  }
                                : null,
                            onLeft: (PlatformDetector.isTV && isFirstColumn)
                                ? () {
                                    // Press Left on first column, jump to currently selected category
                                    ServiceLocator.log.d(
                                        'ChannelsScreen: onLeft pressed, _currentGroupIndex=$_currentGroupIndex, _selectedGroup=$_selectedGroup');
                                    if (_currentGroupIndex <
                                        _groupFocusNodes.length) {
                                      _groupFocusNodes[_currentGroupIndex]
                                          .requestFocus();
                                    }
                                  }
                                : null,
                            onDown: (PlatformDetector.isTV && isLastRow)
                                ? () {
                                    // Press Down on last row, do nothing (prevent jump)
                                  }
                                : null,
                            onFavoriteToggle: () {
                              context
                                  .read<FavoritesProvider>()
                                  .toggleFavorite(channel);
                            },
                            onTest: () => _testSingleChannel(context, channel),
                            onTap: () async {
                              final settingsProvider =
                                  context.read<SettingsProvider>();

                              // Save last played channel ID
                              if (settingsProvider.rememberLastChannel &&
                                  channel.id != null) {
                                settingsProvider.setLastChannelId(channel.id);
                              }

                              ServiceLocator.log.d(
                                  'ChannelsScreen: onTap - enableMultiScreen=${settingsProvider.enableMultiScreen}, isDesktop=${PlatformDetector.isDesktop}, isTV=${PlatformDetector.isTV}');

                              // Check if multi-screen mode is enabled
                              if (settingsProvider.enableMultiScreen) {
                                // TV side uses native multi-screen player
                                if (PlatformDetector.isTV &&
                                    PlatformDetector.isAndroid) {
                                  ServiceLocator.log.d(
                                      'ChannelsScreen: TV Multi-screen mode, launching native multi-screen player');
                                  final channelProvider =
                                      context.read<ChannelProvider>();
                                  final favoritesProvider =
                                      context.read<FavoritesProvider>();
                                  final channels = channelProvider.channels;

                                  // Set providers for favorites feature
                                  NativePlayerChannel.setProviders(
                                      favoritesProvider,
                                      channelProvider,
                                      settingsProvider);

                                  // Find index of currently clicked channel
                                  final clickedIndex = channels
                                      .indexWhere((c) => c.url == channel.url);

                                  // TV side native multi-screen player also needs to record watch history
                                  if (channel.id != null &&
                                      channel.playlistId != null) {
                                    await ServiceLocator.watchHistory
                                        .addWatchHistory(
                                            channel.id!, channel.playlistId!);
                                    ServiceLocator.log.d(
                                        'ChannelsScreen: Recorded watch history for channel ${channel.name} (TV multi-screen)');
                                  }

                                  // Prepare channel data
                                  final urls =
                                      channels.map((c) => c.url).toList();
                                  final names =
                                      channels.map((c) => c.name).toList();
                                  final groups = channels
                                      .map((c) => c.groupName ?? '')
                                      .toList();
                                  final sources =
                                      channels.map((c) => c.sources).toList();
                                  final logos = channels
                                      .map((c) => c.logoUrl ?? '')
                                      .toList();

                                  // Start native multi-screen player, pass initial index and volume boost
                                  await NativePlayerChannel.launchMultiScreen(
                                    urls: urls,
                                    names: names,
                                    groups: groups,
                                    sources: sources,
                                    logos: logos,
                                    initialChannelIndex:
                                        clickedIndex >= 0 ? clickedIndex : 0,
                                    volumeBoostDb: settingsProvider.volumeBoost,
                                    defaultScreenPosition:
                                        settingsProvider.defaultScreenPosition,
                                    showChannelName: settingsProvider
                                        .showMultiScreenChannelName,
                                    onClosed: () {
                                      ServiceLocator.log.d(
                                          'ChannelsScreen: Native multi-screen closed');
                                    },
                                  );
                                } else if (PlatformDetector.isDesktop) {
                                  ServiceLocator.log.d(
                                      'ChannelsScreen: Desktop Multi-screen mode, playing channel: ${channel.name}');
                                  // Desktop multi-screen mode: play channel at specified position
                                  final multiScreenProvider =
                                      context.read<MultiScreenProvider>();
                                  final defaultPosition =
                                      settingsProvider.defaultScreenPosition;
                                  // Set volume boost to multi-screen provider
                                  multiScreenProvider.setVolumeSettings(
                                      1.0, settingsProvider.volumeBoost);
                                  multiScreenProvider
                                      .playChannelAtDefaultPosition(
                                          channel, defaultPosition);

                                  // Navigate to player in multi-screen mode without passing channel params (handled by MultiScreenProvider)
                                  Navigator.pushNamed(
                                    context,
                                    AppRouter.player,
                                    arguments: {
                                      'channelUrl': '', // Empty URL indicates multi-screen mode
                                      'channelName': '',
                                      'channelLogo': null,
                                    },
                                  );
                                } else {
                                  // Normal playback on other platforms
                                  Navigator.pushNamed(
                                    context,
                                    AppRouter.player,
                                    arguments: {
                                      'channelUrl': channel.url,
                                      'channelName': channel.name,
                                      'channelLogo': channel.logoUrl,
                                    },
                                  );
                                }
                              } else {
                                // Normal mode: navigate to player and pass channel params
                                Navigator.pushNamed(
                                  context,
                                  AppRouter.player,
                                  arguments: {
                                    'channelUrl': channel.url,
                                    'channelName': channel.name,
                                    'channelLogo': channel.logoUrl,
                                  },
                                );
                              }
                            },
                            onLongPress: () =>
                                _showChannelOptions(context, channel),
                          );
                        },
                        childCount: channels.length,
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteAllUnavailable(
      BuildContext context, ChannelProvider provider) async {
    final count = provider.unavailableChannelCount;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          AppStrings.of(context)?.deletePlaylist.toUpperCase() ?? 'DELETE INVALID CHANNELS',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0),
        ),
        content: Text(
          'Are you sure you want to delete all $count invalid channels? This action cannot be undone.',
          style: const TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('DELETE ALL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final deletedCount = await provider.deleteAllUnavailableChannels();

      // Switch to All Channels
      setState(() {
        _selectedGroup = null;
      });
      provider.clearGroupFilter();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $deletedCount invalid channels'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _testSingleChannel(BuildContext context, dynamic channel) async {
    final testService = ChannelTestService();
    final channelObj = channel as Channel;

    // Show testing hint
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text('Testing: ${channelObj.name}'),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    final result = await testService.testChannel(channelObj);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // If test passes and is an invalid channel, automatically restore to original category
      if (result.isAvailable &&
          ChannelProvider.isUnavailableChannel(channelObj.groupName)) {
        final provider = context.read<ChannelProvider>();
        final originalGroup =
            ChannelProvider.extractOriginalGroup(channelObj.groupName);
        await provider.restoreChannel(channelObj.id!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${channelObj.name} available, restored to "$originalGroup" category'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.isAvailable ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.isAvailable
                        ? '${channelObj.name} 可用 (${result.responseTime}ms)'
                        : '${channelObj.name} Unavailable: ${result.error}',
                  ),
                ),
              ],
            ),
            backgroundColor:
                result.isAvailable ? Colors.green : AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showChannelTestDialog(
      BuildContext context, List<dynamic> channels) async {
    final result = await showDialog<ChannelTestDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChannelTestDialog(
        channels: channels.cast<Channel>(),
      ),
    );

    if (result == null || !mounted) return;

    // If run in background
    if (result.runInBackground) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('Test has moved to background, ${result.remainingCount} channels remaining'),
            ],
          ),
          backgroundColor: AppTheme.getPrimaryColor(context),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: "View Progress",
            textColor: Colors.white,
            onPressed: () => _showBackgroundTestProgress(context),
          ),
        ),
      );
      return;
    }

    // If user chooses to move to invalid category
    if (result.movedToUnavailable) {
      final unavailableCount =
          result.results.where((r) => !r.isAvailable).length;

      // Show hint
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Moved $unavailableCount invalid channels to"${ChannelProvider.unavailableGroupName}"category'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: "View",
            textColor: Colors.white,
            onPressed: () {
              // Jump to invalid category
              setState(() {
                _selectedGroup = ChannelProvider.unavailableGroupName;
              });
              context
                  .read<ChannelProvider>()
                  .selectGroup(ChannelProvider.unavailableGroupName);
            },
          ),
        ),
      );

      // Automatically jump to invalid category
      setState(() {
        _selectedGroup = ChannelProvider.unavailableGroupName;
      });
      context
          .read<ChannelProvider>()
          .selectGroup(ChannelProvider.unavailableGroupName);
    }
  }

  void _showBackgroundTestProgress(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BackgroundTestProgressDialog(),
    );
  }

  // ignore: unused_element
  Future<void> _deleteUnavailableChannels(
      List<ChannelTestResult> results) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Delete',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Text(
          'Are you sure you want to delete ${results.length} unavailable channels? This action cannot be undone.',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        // Delete unavailable channels
        for (final result in results) {
          if (result.channel.id != null) {
            await ServiceLocator.database.delete(
              'channels',
              where: 'id = ?',
              whereArgs: [result.channel.id],
            );
          }
        }

        // Refresh channel list
        if (mounted) {
          context.read<ChannelProvider>().loadAllChannels();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted ${results.length} unavailable channels'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void _showChannelOptions(BuildContext context, dynamic channel) {
    final favoritesProvider = context.read<FavoritesProvider>();
    final isFavorite = favoritesProvider.isFavorite(channel.id ?? 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Channel name
              Text(
                channel.name,
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Options
              ListTile(
                leading: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite
                      ? AppTheme.accentColor
                      : AppTheme.getTextSecondary(context),
                ),
                title: Text(
                  isFavorite
                      ? (AppStrings.of(context)?.removeFavorites ??
                          'Remove from Favorites')
                      : (AppStrings.of(context)?.addFavorites ??
                          'Add to Favorites'),
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                onTap: () async {
                  await favoritesProvider.toggleFavorite(channel);
                  Navigator.pop(context);
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.getTextSecondary(context),
                ),
                title: Text(
                  AppStrings.of(context)?.channelInfo ?? 'Channel Info',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Show channel info dialog
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.speed_rounded,
                  color: AppTheme.getTextSecondary(context),
                ),
                title: Text(
                  'Test Channels',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _testSingleChannel(context, channel);
                },
              ),

              // If it is an invalid channel, show restore option
              if (ChannelProvider.isUnavailableChannel(channel.groupName))
                ListTile(
                  leading: const Icon(
                    Icons.restore_rounded,
                    color: Colors.orange,
                  ),
                  title: Text(
                    '恢复到原category (${ChannelProvider.extractOriginalGroup(channel.groupName)})',
                    style: TextStyle(color: AppTheme.getTextPrimary(context)),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final provider = context.read<ChannelProvider>();
                    final success = await provider.restoreChannel(channel.id!);
                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已恢复 ${channel.name} 到原category'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

/// 后台测试进度指示器
class _BackgroundTestIndicator extends StatefulWidget {
  final VoidCallback onTap;

  const _BackgroundTestIndicator({required this.onTap});

  @override
  State<_BackgroundTestIndicator> createState() =>
      _BackgroundTestIndicatorState();
}

class _BackgroundTestIndicatorState extends State<_BackgroundTestIndicator> {
  final BackgroundTestService _service = BackgroundTestService();
  late BackgroundTestProgress _progress;

  @override
  void initState() {
    super.initState();
    _progress = _service.currentProgress;
    _service.addListener(_onProgressUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onProgressUpdate);
    super.dispose();
  }

  void _onProgressUpdate(BackgroundTestProgress progress) {
    if (mounted) {
      setState(() {
        _progress = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show when running or has results
    if (!_progress.isRunning && !_progress.isComplete) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _progress.isRunning
              ? AppTheme.getPrimaryColor(context).withOpacity(0.2)
              : Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_progress.isRunning) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.getPrimaryColor(context),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_progress.completed}/${_progress.total}',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              const Icon(
                Icons.check_circle_outline,
                size: 16,
                color: Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                'Test complete (${_progress.unavailable}failed)',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
