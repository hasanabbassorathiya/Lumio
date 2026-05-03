import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/platform/platform_detector.dart';
import '../providers/playlist_provider.dart';
import '../../channels/providers/channel_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';

/// 直播源列表页面 - 只显示已保存的播放列表（只读）
class PlaylistListScreen extends StatefulWidget {
  const PlaylistListScreen({super.key});

  @override
  State<PlaylistListScreen> createState() => _PlaylistListScreenState();
}

class _PlaylistListScreenState extends State<PlaylistListScreen> {
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
            selectedIndex: 2, // 直播源列表页
            child: content,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              title: Text(
                AppStrings.of(context)?.playlistList ?? 'Playlist List',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  '${(provider.importProgress * 100).toInt()}%',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.of(context)?.processing ??
                      'Processing, please wait...',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (provider.playlists.isEmpty) {
          return _buildEmptyState();
        }

        return _buildPlaylistsList(provider);
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
              Icons.playlist_add_rounded,
              size: 50,
              color: AppTheme.getTextMuted(context).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.of(context)?.noPlaylists ?? 'No Playlists',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(context)?.goToHomeToAdd ??
                'Go to Home to add playlists',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsList(PlaylistProvider provider) {
    // 按照 ID 降序排序（最新的在前面）
    final sortedPlaylists = List.from(provider.playlists)
      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sortedPlaylists.length,
      itemBuilder: (context, index) {
        final playlist = sortedPlaylists[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPlaylistCard(provider, playlist, index),
        );
      },
    );
  }

  Widget _buildPlaylistCard(
      PlaylistProvider provider, dynamic playlist, int index) {
    final isActive = provider.activePlaylist?.id == playlist.id;
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;

    return TVFocusable(
      autofocus: index == 0,
      onSelect: () {
        provider.setActivePlaylist(
          playlist,
          onPlaylistChanged: (playlistId) {
            context.read<ChannelProvider>().loadChannels(playlistId);
          },
          favoritesProvider: context.read<FavoritesProvider>(),
        );
      },
      focusScale: 1.05,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        final showHighlight = isFocused || isActive;
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          padding: EdgeInsets.all(isLandscape ? 8 : 14),
          decoration: BoxDecoration(
            color: isFocused
                ? Colors.white
                : (isActive ? AppTheme.getPrimaryColor(context).withOpacity(0.15) : AppTheme.getSurfaceColor(context)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused ? Colors.white : (isActive ? AppTheme.getPrimaryColor(context).withOpacity(0.5) : Colors.white.withOpacity(0.05)),
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
      child: Row(
        children: [
          // Icon - Modern sleek icon container
          Builder(builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            return AnimatedContainer(
              duration: AppTheme.animationFast,
              width: isLandscape ? 44 : 56,
              height: isLandscape ? 44 : 56,
              decoration: BoxDecoration(
                color: isFocused
                    ? Colors.black.withOpacity(0.1)
                    : (isActive ? AppTheme.getPrimaryColor(context).withOpacity(0.2) : Colors.white.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                playlist.isRemote ? Icons.cloud_outlined : Icons.folder_outlined,
                color: isFocused
                    ? Colors.black
                    : (isActive ? AppTheme.getPrimaryColor(context) : Colors.white70),
                size: isLandscape ? 22 : 28,
              ),
            );
          }),

          SizedBox(width: isLandscape ? 14 : 20),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Builder(builder: (context) {
                        final isFocused = Focus.of(context).hasFocus;
                        return Text(
                          playlist.name.toUpperCase(),
                          style: TextStyle(
                            color: isFocused ? Colors.black : Colors.white,
                            fontSize: isLandscape ? 13 : 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }),
                    ),
                    if (isActive)
                      Builder(builder: (context) {
                        final isFocused = Focus.of(context).hasFocus;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isFocused ? Colors.black.withOpacity(0.1) : AppTheme.getPrimaryColor(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: isFocused ? Colors.black : Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        );
                      }),
                  ],
                ),
                const SizedBox(height: 4),
                Builder(builder: (context) {
                  final isFocused = Focus.of(context).hasFocus;
                  return Text(
                    '${playlist.format} · ${playlist.isRemote ? 'REMOTE' : 'LOCAL'} · ${playlist.channelCount} CHANNELS',
                    style: TextStyle(
                      color: isFocused ? Colors.black54 : Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  );
                }),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Copy URL
              if (playlist.isRemote && playlist.url != null)
                _buildActionIconButton(
                  icon: Icons.link_rounded,
                  color: Colors.white60,
                  onTap: () => _copyUrl(playlist.url!),
                ),
              const SizedBox(width: 8),
              // Refresh
              _buildActionIconButton(
                icon: Icons.refresh_rounded,
                color: AppTheme.getPrimaryColor(context),
                onTap: () => _refreshPlaylist(provider, playlist),
              ),
              const SizedBox(width: 8),
              // Delete
              _buildActionIconButton(
                icon: Icons.delete_outline_rounded,
                color: AppTheme.errorColor,
                onTap: () => _confirmDelete(provider, playlist),
              ),
            ],
          ),
        ],
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}${AppStrings.of(context)?.minutesAgo ?? 'm ago'}';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}${AppStrings.of(context)?.hoursAgo ?? 'h ago'}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}${AppStrings.of(context)?.daysAgo ?? 'd ago'}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _refreshPlaylist(
      PlaylistProvider provider, dynamic playlist) async {
    final success = await provider.refreshPlaylist(playlist);
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      if (success) {
        final channelProvider = context.read<ChannelProvider>();
        if (provider.activePlaylist?.id == playlist.id) {
          await channelProvider.loadChannels(playlist.id);
        }

        if (mounted) {
          final settingsProvider = context.read<SettingsProvider>();
          final epgProvider = context.read<EpgProvider>();

          if (settingsProvider.enableEpg) {
            final playlistEpgUrl = provider.lastExtractedEpgUrl;
            final fallbackEpgUrl = settingsProvider.epgUrl;

            if (playlistEpgUrl != null && playlistEpgUrl.isNotEmpty) {
              epgProvider.loadEpg(playlistEpgUrl, fallbackUrl: fallbackEpgUrl);
            } else if (fallbackEpgUrl != null && fallbackEpgUrl.isNotEmpty) {
              epgProvider.loadEpg(fallbackEpgUrl);
            }
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (AppStrings.of(context)?.playlistRefreshed ??
                      'Playlist refreshed successfully')
                  : '${AppStrings.of(context)?.playlistRefreshFailed ?? "Failed to refresh playlist"}: ${provider.error?.replaceAll("Exception:", "").trim() ?? ""}',
            ),
            backgroundColor:
                success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL已复制到剪贴板'),
          duration: Duration(seconds: 2),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  void _confirmDelete(PlaylistProvider provider, dynamic playlist) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            AppStrings.of(context)?.deletePlaylist ?? 'Delete Playlist',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Text(
            (AppStrings.of(context)?.deleteConfirmation ??
                    'Are you sure you want to delete "{name}"? This will also remove all channels from this playlist.')
                .replaceAll('{name}', playlist.name),
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
                final success = await provider.deletePlaylist(playlist.id);

                if (mounted && success) {
                  final channelProvider = context.read<ChannelProvider>();

                  if (provider.activePlaylist != null &&
                      provider.activePlaylist!.id != null) {
                    await channelProvider
                        .loadChannels(provider.activePlaylist!.id!);
                  } else {
                    await channelProvider.loadAllChannels();
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.of(context)?.playlistDeleted ??
                          'Playlist deleted'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: Text(AppStrings.of(context)?.delete ?? 'Delete'),
            ),
          ],
        );
      },
    );
  }
}
