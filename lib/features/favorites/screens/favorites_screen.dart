import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/widgets/channel_logo_widget.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../channels/providers/channel_provider.dart';
import '../../multi_screen/providers/multi_screen_provider.dart';
import '../../../core/platform/native_player_channel.dart';
import '../../../core/services/service_locator.dart';

class FavoritesScreen extends StatefulWidget {
  final bool embedded;
  
  const FavoritesScreen({super.key, this.embedded = false});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesProvider>().loadFavorites();
    });
  }

  void _playChannel(dynamic channel) {
    final settingsProvider = context.read<SettingsProvider>();
    
    // 保存上次播放的频道ID
    if (settingsProvider.rememberLastChannel && channel.id != null) {
      settingsProvider.setLastChannelId(channel.id);
    }

    // 检查是否启用了分屏模式
    if (settingsProvider.enableMultiScreen) {
      // TV 端使用原生分屏播放器
      if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
        final channelProvider = context.read<ChannelProvider>();
        final channels = channelProvider.channels;
        
        // 找到当前点击频道的索引
        final clickedIndex = channels.indexWhere((c) => c.url == channel.url);
        
        // 准备频道数据
        final urls = channels.map((c) => c.url).toList();
        final names = channels.map((c) => c.name).toList();
        final groups = channels.map((c) => c.groupName ?? '').toList();
        final sources = channels.map((c) => c.sources).toList();
        final logos = channels.map((c) => c.logoUrl ?? '').toList();
        
        // 启动原生分屏播放器
        NativePlayerChannel.launchMultiScreen(
          urls: urls,
          names: names,
          groups: groups,
          sources: sources,
          logos: logos,
          initialChannelIndex: clickedIndex >= 0 ? clickedIndex : 0,
          volumeBoostDb: settingsProvider.volumeBoost,
          defaultScreenPosition: settingsProvider.defaultScreenPosition,
          showChannelName: settingsProvider.showMultiScreenChannelName,
          onClosed: () {
            ServiceLocator.log.d('FavoritesScreen: Native multi-screen closed');
          },
        );
      } else if (PlatformDetector.isDesktop) {
        final multiScreenProvider = context.read<MultiScreenProvider>();
        final defaultPosition = settingsProvider.defaultScreenPosition;
        // 设置音量增强到分屏Provider
        multiScreenProvider.setVolumeSettings(1.0, settingsProvider.volumeBoost);
        multiScreenProvider.playChannelAtDefaultPosition(channel, defaultPosition);
        
        Navigator.pushNamed(context, AppRouter.player, arguments: {
          'channelUrl': '',
          'channelName': '',
          'channelLogo': null,
        });
      } else {
        Navigator.pushNamed(context, AppRouter.player, arguments: {
          'channelUrl': channel.url,
          'channelName': channel.name,
          'channelLogo': channel.logoUrl,
        });
      }
    } else {
      Navigator.pushNamed(context, AppRouter.player, arguments: {
        'channelUrl': channel.url,
        'channelName': channel.name,
        'channelLogo': channel.logoUrl,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    final content = _buildContent(context);

    if (isTV) {
      return Scaffold(
        body: Container(
          color: AppTheme.getBackgroundColor(context),
          child: TVSidebar(
            selectedIndex: 3, // 收藏页
            child: content,
          ),
        ),
      );
    }

    // 嵌入模式不使用Scaffold
    if (widget.embedded) {
      final isMobile = PlatformDetector.isMobile;
      final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;

      return Column(
        children: [
          // 简化的标题栏 - Standard padding, SafeArea is handled by HomeScreen
          Container(
            height: isLandscape ? 40.0 : 56.0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  AppStrings.of(context)?.favorites ?? 'Favorites',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: isLandscape ? 16 : 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Consumer<FavoritesProvider>(
                  builder: (context, provider, _) {
                    if (provider.favorites.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: Icon(
                        Icons.delete_sweep_rounded,
                        color: AppTheme.getTextSecondary(context),
                        size: isLandscape ? 18 : 24,
                      ),
                      onPressed: () => _confirmClearAll(context, provider),
                      tooltip: AppStrings.of(context)?.clearAll ?? 'Clear All',
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppStrings.of(context)?.favorites ?? 'Favorites',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<FavoritesProvider>(
            builder: (context, provider, _) {
              if (provider.favorites.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                onPressed: () => _confirmClearAll(context, provider),
                tooltip: AppStrings.of(context)?.clearAll ?? 'Clear All',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: content,
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        if (provider.favorites.isEmpty) {
          return _buildEmptyState();
        }

        return _buildFavoritesList(provider);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              Icons.favorite_outline_rounded,
              size: 50,
              color: AppTheme.getTextMuted(context).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.of(context)?.noFavoritesYet ?? 'No Favorites Yet',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(context)?.favoritesHint ?? 'Long press on a channel to add it to favorites',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          TVFocusable(
            autofocus: true,
            showFocusBorder: false,
            onSelect: () => Navigator.pushNamed(context, AppRouter.channels, arguments: {'forceShowBackButton': true}),
            child: const SizedBox.shrink(),
            builder: (context, isFocused, child) {
              return AnimatedScale(
                scale: isFocused ? 1.05 : 1.0,
                duration: AppTheme.animationFast,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRouter.channels),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFocused ? Colors.white : AppTheme.getSurfaceColor(context),
                    foregroundColor: isFocused ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: isFocused ? Colors.white : Colors.white.withOpacity(0.05), width: 1.5),
                    elevation: 0,
                  ),
                  icon: Icon(Icons.live_tv_rounded, size: 22, color: isFocused ? Colors.black : AppTheme.getPrimaryColor(context)),
                  label: Text(
                    AppStrings.of(context)?.browseChannels.toUpperCase() ?? 'BROWSE CHANNELS',
                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(FavoritesProvider provider) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(20),
      buildDefaultDragHandles: false,
      itemCount: provider.favorites.length,
      onReorder: (oldIndex, newIndex) {
        provider.reorderFavorites(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Material(
              elevation: 8,
              color: Colors.transparent,
              shadowColor: AppTheme.primaryColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final channel = provider.favorites[index];

        return Padding(
          key: ValueKey(channel.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildFavoriteCard(provider, channel, index),
        );
      },
    );
  }

  Widget _buildFavoriteCard(FavoritesProvider provider, dynamic channel, int index) {
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;

    return TVFocusable(
      autofocus: index == 0,
      onSelect: () => _playChannel(channel),
      focusScale: 1.05,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          decoration: BoxDecoration(
            color: isFocused ? Colors.white : AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(16),
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
        padding: EdgeInsets.all(isLandscape ? 10 : 14),
        child: Row(
          children: [
            // Drag Handle - Modern minimal style
            ReorderableDragStartListener(
              index: index,
              child: Builder(builder: (context) {
                final isFocused = Focus.of(context).hasFocus;
                return Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: isFocused ? Colors.black26 : Colors.white24,
                    size: isLandscape ? 18 : 22,
                  ),
                );
              }),
            ),

            const SizedBox(width: 8),

            // Channel Logo - Sleeker presentation
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ChannelLogoWidget(
                channel: channel,
                width: isLandscape ? 60 : 76,
                height: isLandscape ? 44 : 56,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(width: 18),

            // Channel Info - Modern bold typography
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (context) {
                    final isFocused = Focus.of(context).hasFocus;
                    return Text(
                      channel.name.toUpperCase(),
                      style: TextStyle(
                        color: isFocused ? Colors.black : Colors.white,
                        fontSize: isLandscape ? 13 : 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  }),
                  if (channel.groupName != null) ...[
                    const SizedBox(height: 2),
                    Builder(builder: (context) {
                      final isFocused = Focus.of(context).hasFocus;
                      return Text(
                        channel.groupName!.toUpperCase(),
                        style: TextStyle(
                          color: isFocused ? Colors.black54 : Colors.white38,
                          fontSize: isLandscape ? 10 : 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),

            // Actions - Consistent high-level buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionIconButton(
                  icon: Icons.play_arrow_rounded,
                  color: AppTheme.getPrimaryColor(context),
                  onTap: () => _playChannel(channel),
                ),
                const SizedBox(width: 8),
                _buildActionIconButton(
                  icon: Icons.favorite_rounded,
                  color: AppTheme.errorColor,
                  onTap: () async {
                    await provider.removeFavorite(channel.id!);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Removed ${channel.name} from favorites'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TVFocusable(
      onSelect: onTap,
      focusScale: 1.1,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isFocused ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFocused ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: isFocused ? color : color.withOpacity(0.7),
            size: 18,
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }

  void _confirmClearAll(BuildContext context, FavoritesProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            AppStrings.of(context)?.clearAllFavorites ?? 'Clear All Favorites',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Text(
            AppStrings.of(context)?.clearFavoritesConfirm ?? 'Are you sure you want to remove all channels from your favorites?',
            style: TextStyle(color: AppTheme.getTextSecondary(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context)?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await provider.clearFavorites();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.of(context)?.allFavoritesCleared ?? 'All favorites cleared'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: Text(AppStrings.of(context)?.clearAll ?? 'Clear All'),
            ),
          ],
        );
      },
    );
  }
}
