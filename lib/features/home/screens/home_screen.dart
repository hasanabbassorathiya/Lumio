import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/widgets/category_card.dart';
import '../../../core/widgets/channel_card.dart';
import '../../../core/widgets/channel_logo_widget.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/update_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/models/app_update.dart';
import '../../../core/utils/card_size_calculator.dart';
import '../../channels/providers/channel_provider.dart';
import '../../channels/screens/channels_screen.dart';
import '../../playlist/providers/playlist_provider.dart';
import '../../playlist/widgets/add_playlist_dialog.dart';
import '../../playlist/screens/playlist_list_screen.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../favorites/screens/favorites_screen.dart';
import '../../player/providers/player_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/screens/settings_screen.dart';
import '../../search/screens/search_screen.dart';
import '../../epg/providers/epg_provider.dart';
import '../../multi_screen/providers/multi_screen_provider.dart';
import '../../../core/platform/native_player_channel.dart';
import '../../../core/models/channel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  int _selectedNavIndex = 0;
  List<Channel> _watchHistoryChannels = [];
  int? _lastPlaylistId; // Track last playlist ID
  int _lastChannelCount = 0; // Track last channel count
  String _appVersion = '';
  AppUpdate? _availableUpdate; // Available update
  final ScrollController _scrollController = ScrollController(); // Add scroll controller
  final FocusNode _continueButtonFocusNode = FocusNode(); // Focus node for continue watching button

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Listen to app lifecycle

    // Defer data loading until after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadVersion();
      _checkForUpdates();
    });

    // Listen for channel changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChannelProvider>().addListener(_onChannelProviderChanged);
      context.read<PlaylistProvider>().addListener(_onPlaylistProviderChanged);
      context
          .read<FavoritesProvider>()
          .addListener(_onFavoritesProviderChanged);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register route listener
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      AppRouter.routeObserver.subscribe(this, route);
    }
    // Check if data needs reloading (app resume)
    _checkAndReloadIfNeeded();
  }

  // Triggered when returning from other pages
  @override
  void didPopNext() {
    super.didPopNext();
    ServiceLocator.log.i('Returned to home, refresh watch history', tag: 'HomeScreen');
    _refreshWatchHistory();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    ServiceLocator.log.i('App lifecycle changed: $state', tag: 'HomeScreen');

    // Check and reload data when app resumes from background
    if (state == AppLifecycleState.resumed) {
      ServiceLocator.log.i('App resumed from background, check data status', tag: 'HomeScreen');
      _checkAndReloadIfNeeded();
      // Refresh watch history
      _refreshWatchHistory();
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final updateService = UpdateService();
      // Force check for update on startup (ignore 24h limit)
      final update = await updateService.checkForUpdates(forceCheck: true);
      if (mounted && update != null) {
        setState(() {
          _availableUpdate = update;
        });
      }
    } catch (e) {
      // Silent failure, no impact on UX
    }
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Dispose scroll controller
    _continueButtonFocusNode.dispose(); // Dispose focus node
    WidgetsBinding.instance.removeObserver(this); // Remove lifecycle listener
    AppRouter.routeObserver.unsubscribe(this); // Remove route listener
    // Be careful when removing listeners because context might no longer be available
    super.dispose();
  }

  void _onChannelProviderChanged() {
    if (!mounted) return;
    final channelProvider = context.read<ChannelProvider>();

    // Refresh recommended channels when loading completes
    if (!channelProvider.isLoading && channelProvider.channels.isNotEmpty) {
      // Refresh when channel count changes or on first load
      if (channelProvider.channels.length != _lastChannelCount ||
          _watchHistoryChannels.isEmpty) {
        _lastChannelCount = channelProvider.channels.length;
        _refreshWatchHistory();
      }
    }
  }

  void _onPlaylistProviderChanged() {
    if (!mounted) return;
    final playlistProvider = context.read<PlaylistProvider>();
    final currentPlaylistId = playlistProvider.activePlaylist?.id;

    // Clear watch history and reload when playlist ID changes
    if (_lastPlaylistId != currentPlaylistId) {
      _lastPlaylistId = currentPlaylistId;
      _watchHistoryChannels = [];
      _lastChannelCount = 0;

      // Reload channels when playlist switches
      if (currentPlaylistId != null) {
        final channelProvider = context.read<ChannelProvider>();
        channelProvider.loadChannels(currentPlaylistId);
      }
    }

    // 当播放列表刷新完成时（isLoading 从 true 变为 false），Trigger channel reload
    // Ensures home screen updates correctly after M3U refresh
    if (!playlistProvider.isLoading && playlistProvider.hasPlaylists) {
      final channelProvider = context.read<ChannelProvider>();
      // Reload if channel provider is not loading and watch history is empty
      if (!channelProvider.isLoading && _watchHistoryChannels.isEmpty) {
        _refreshWatchHistory();
      }
    }
  }

  void _onFavoritesProviderChanged() {
    if (!mounted) return;
    // When favorite status changesRefresh watch history
    _refreshWatchHistory();
  }

  /// Check and reload data if needed (handle app resume)
  void _checkAndReloadIfNeeded() {
    final playlistProvider = context.read<PlaylistProvider>();
    final channelProvider = context.read<ChannelProvider>();

    // If playlist is loaded but channel list is empty, state might have been lost after app resume
    if (playlistProvider.hasPlaylists &&
        !playlistProvider.isLoading &&
        channelProvider.channels.isEmpty &&
        !channelProvider.isLoading) {
      ServiceLocator.log.w('Detected data state anomaly: playlist exists but channels are empty', tag: 'HomeScreen');
      _loadData();
    }
  }

  Future<void> _loadData() async {
    ServiceLocator.log.i('Start loading home screen data', tag: 'HomeScreen');
    final startTime = DateTime.now();

    final playlistProvider = context.read<PlaylistProvider>();
    final channelProvider = context.read<ChannelProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final epgProvider = context.read<EpgProvider>();

    // If playlist empty, load playlist first
    if (!playlistProvider.hasPlaylists) {
      ServiceLocator.log.w('Playlist empty, reloading', tag: 'HomeScreen');
      await playlistProvider.loadPlaylists();
    }

    if (playlistProvider.hasPlaylists) {
      final activePlaylist = playlistProvider.activePlaylist;
      _lastPlaylistId = activePlaylist?.id;
      ServiceLocator.log.d(
          'Active playlist: ${activePlaylist?.name} (ID: ${activePlaylist?.id})',
          tag: 'HomeScreen');

      if (activePlaylist != null && activePlaylist.id != null) {
        ServiceLocator.log
            .d('Loading playlist channels: ${activePlaylist.id}', tag: 'HomeScreen');
        await channelProvider.loadChannels(activePlaylist.id!);
      } else {
        ServiceLocator.log.d('Loading all channels', tag: 'HomeScreen');
        await channelProvider.loadAllChannels();
      }

      ServiceLocator.log.d('Loading favorite list', tag: 'HomeScreen');
      await favoritesProvider.loadFavorites();
      _refreshWatchHistory();

      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i(
          'Home screen data loaded, time taken: ${loadTime}ms，channels: ${channelProvider.channels.length}',
          tag: 'HomeScreen');

      // Load EPG (use playlist EPG URL, fallback to settings URL if it fails)
      ServiceLocator.log.d(
          'HomeScreen: Check EPG loading conditions - activePlaylist.epgUrl=${activePlaylist?.epgUrl}, settingsProvider.epgUrl=${settingsProvider.epgUrl}');
      print(
          'HomeScreen: Check EPG loading conditions - activePlaylist.epgUrl=${activePlaylist?.epgUrl}, settingsProvider.epgUrl=${settingsProvider.epgUrl}');
      if (activePlaylist?.epgUrl != null &&
          activePlaylist!.epgUrl!.isNotEmpty) {
        ServiceLocator.log
            .d('HomeScreen: Initially load playlist EPG URL: ${activePlaylist.epgUrl}');
        await epgProvider.loadEpg(
          activePlaylist.epgUrl!,
          fallbackUrl: settingsProvider.epgUrl,
        );
      } else if (settingsProvider.epgUrl != null &&
          settingsProvider.epgUrl!.isNotEmpty) {
        ServiceLocator.log
            .d('HomeScreen: Initially load fallback EPG URL from settings: ${settingsProvider.epgUrl}');
        await epgProvider.loadEpg(settingsProvider.epgUrl!);
      } else {
        ServiceLocator.log.d('HomeScreen: No available EPG URL (not configured in playlist or settings)');
      }

      // Auto-play feature: auto-play with 500ms delay after data is loaded
      if (settingsProvider.autoPlay && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;

          // Get last playback state
          final isMultiScreenMode = settingsProvider.lastPlayMode == 'multi' &&
              settingsProvider.hasMultiScreenState;
          Channel? lastChannel;

          if (settingsProvider.rememberLastChannel &&
              settingsProvider.lastChannelId != null) {
            try {
              lastChannel = channelProvider.channels.firstWhere(
                (c) => c.id == settingsProvider.lastChannelId,
              );
            } catch (_) {
              // Channel does not exist, using first channel
              lastChannel = channelProvider.channels.isNotEmpty
                  ? channelProvider.channels.first
                  : null;
            }
          } else {
            lastChannel = channelProvider.channels.isNotEmpty
                ? channelProvider.channels.first
                : null;
          }

          // Auto-trigger continue playback
          if (lastChannel != null || isMultiScreenMode) {
            ServiceLocator.log.d(
                'HomeScreen: Auto-play triggered - isMultiScreen=$isMultiScreenMode');
            _continuePlayback(channelProvider, lastChannel, isMultiScreenMode,
                settingsProvider);
          }
        });
      }
    }
  }

  void _refreshWatchHistory() async {
    if (!mounted) return;

    final playlistProvider = context.read<PlaylistProvider>();
    final activePlaylist = playlistProvider.activePlaylist;

    if (activePlaylist?.id == null) {
      if (_watchHistoryChannels.isNotEmpty) {
        setState(() {
          _watchHistoryChannels = [];
        });
      }
      return;
    }

    // Asynchronously load watch history
    ServiceLocator.watchHistory
        .getWatchHistory(activePlaylist!.id!, limit: 20)
        .then((history) {
      if (mounted) {
        setState(() {
          _watchHistoryChannels = history;
        });
      }
    }).catchError((e) {
      ServiceLocator.log.e('Failed to load watch history: $e', tag: 'HomeScreen');
      if (mounted) {
        setState(() {
          _watchHistoryChannels = [];
        });
      }
    });
  }

  List<_NavItem> _getNavItems(BuildContext context) {
    final strings = AppStrings.of(context);
    return [
      _NavItem(icon: Icons.home_rounded, label: strings?.home ?? 'Home'),
      _NavItem(
          icon: Icons.live_tv_rounded, label: strings?.channels ?? 'Channels'),
      _NavItem(
          icon: Icons.playlist_play_rounded,
          label: strings?.playlistList ?? 'Sources'),
      _NavItem(
          icon: Icons.favorite_rounded,
          label: strings?.favorites ?? 'Favorites'),
      _NavItem(
          icon: Icons.search_rounded,
          label: strings?.searchChannels ?? 'Search'),
      _NavItem(
          icon: Icons.settings_rounded, label: strings?.settings ?? 'Settings'),
    ];
  }

  void _onNavItemTap(int index) {
    if (index == _selectedNavIndex) return;

    // Clear logo loading queue when switching pages
    clearLogoLoadingQueue();

    setState(() => _selectedNavIndex = index);

    // 切换到首页时Refresh watch history
    if (index == 0) {
      _refreshWatchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    if (isTV) {
      return Scaffold(
        body: Container(
          color: AppTheme.getBackgroundColor(context),
          child: TVSidebar(
            selectedIndex: 0,
            child: _buildMainContent(context),
          ),
        ),
      );
    }

    // Mobile uses bottom navigation to switch pages
    return Scaffold(
      body: Container(
        color: AppTheme.getBackgroundColor(context),
        // Ensure content starts from top
        alignment: Alignment.topCenter,
        child: SafeArea(
          bottom: false,
          child: _buildMobileBody(),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
      // Add floating action button for orientation toggle (mobile only)
      floatingActionButton:
          PlatformDetector.isMobile ? _buildOrientationFab() : null,
    );
  }

  /// Build floating action button for orientation toggle
  Widget _buildOrientationFab() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final orientation = settings.mobileOrientation;
        IconData icon;
        String tooltip;

        // Only show current state, not next
        switch (orientation) {
          case 'landscape':
            icon = Icons.screen_rotation_rounded;
            tooltip = 'Landscape mode';
            break;
          case 'portrait':
          default:
            icon = Icons.stay_current_portrait_rounded;
            tooltip = 'Portrait mode';
            break;
        }

        return FloatingActionButton(
          mini: true,
          backgroundColor: AppTheme.getSurfaceColor(context).withOpacity(0.9),
          onPressed: () => _toggleOrientation(settings),
          tooltip: tooltip,
          child: Icon(icon, color: AppTheme.getPrimaryColor(context), size: 20),
        );
      },
    );
  }

  /// Toggle screen orientation (between landscape and portrait only)
  Future<void> _toggleOrientation(SettingsProvider settings) async {
    String newOrientation;
    List<DeviceOrientation> orientations;
    String message;

    // Toggle between landscape and portrait only
    if (settings.mobileOrientation == 'portrait') {
      newOrientation = 'landscape';
      orientations = [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];
      message = 'Switched to Landscape mode';
    } else {
      newOrientation = 'portrait';
      orientations = [
        DeviceOrientation.portraitUp,
      ];
      message = 'Switched to Portrait mode';
    }

    await settings.setMobileOrientation(newOrientation);
    await SystemChrome.setPreferredOrientations(orientations);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildMobileBody() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildMainContent(context);
      case 1:
        return const _EmbeddedChannelsScreen();
      case 2:
        return const _EmbeddedPlaylistListScreen();
      case 3:
        return const _EmbeddedFavoritesScreen();
      case 4:
        return const _EmbeddedSearchScreen();
      case 5:
        return const _EmbeddedSettingsScreen();
      default:
        return _buildMainContent(context);
    }
  }

  Widget _buildBottomNav(BuildContext context) {
    final navItems = _getNavItems(context);
    return Container(
      decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.03), width: 1.0))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = _selectedNavIndex == index;
              return GestureDetector(
                onTap: () => _onNavItemTap(index),
                child: AnimatedContainer(
                  duration: AppTheme.animationFast,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.getPrimaryColor(context).withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon,
                          color: isSelected
                              ? AppTheme.getPrimaryColor(context)
                              : AppTheme.getTextSecondary(context),
                          size: 22),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Consumer2<PlaylistProvider, ChannelProvider>(
      builder: (context, playlistProvider, channelProvider, _) {
        if (!playlistProvider.hasPlaylists) return _buildEmptyState();

        // Show loading state when playlist is refreshing or channels are loading
        if (playlistProvider.isLoading || channelProvider.isLoading) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        // If playlist loaded but channels empty, try reloading
        if (playlistProvider.hasPlaylists && channelProvider.channels.isEmpty) {
          // Use addPostFrameCallback to avoid calling setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !channelProvider.isLoading) {
              ServiceLocator.log.d('HomeScreen: Channel list empty, triggering reload');
              final activePlaylist = playlistProvider.activePlaylist;
              if (activePlaylist?.id != null) {
                channelProvider.loadChannels(activePlaylist!.id!);
              }
            }
          });
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        final favChannels = _getFavoriteChannels(channelProvider);

        return Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fixed header
            _buildCompactHeader(channelProvider),
            // Scrollable content
            Expanded(
              child: CustomScrollView(
                controller: _scrollController, // Add scroll controller
                slivers: [
                  // Category chips moved inside scroll view to prevent overflow when expanded
                  if (MediaQuery.of(context).size.width <= 700 ||
                      !PlatformDetector.isMobile)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: _buildCategoryChips(channelProvider),
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                        horizontal: PlatformDetector.isMobile ? 12 : 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Hero Section
                        _buildHeroSection(channelProvider),
                        const SizedBox(height: 24),
                        // Show only when watch history is not empty
                        if (_watchHistoryChannels.isNotEmpty)
                          SizedBox(height: PlatformDetector.isMobile ? 8 : 12),
                        ...channelProvider.groups
                            .take(8)
                            .toList()
                            .asMap()
                            .entries
                            .map((entry) {
                          final index = entry.key;
                          final group = entry.value;
                          // Take enough channels, actual display count depends on width
                          final channels = channelProvider.channels
                              .where((c) => c.groupName == group.name)
                              .take(20)
                              .toList();
                          return Padding(
                            padding: EdgeInsets.only(
                                bottom: PlatformDetector.isMobile ? 8 : 12),
                            child: _buildChannelRow(
                              group.name,
                              channels,
                              showMore: true,
                              onMoreTap: () => Navigator.pushNamed(
                                  context, AppRouter.channels,
                                  arguments: {'groupName': group.name}),
                              isFirstRow: index == 0 &&
                                  _watchHistoryChannels
                                      .isEmpty, // 如果没有Watch History，第一个categories是第一行
                            ),
                          );
                        }),
                        if (favChannels.isNotEmpty) ...[
                          _buildChannelRow(
                              AppStrings.of(context)?.myFavorites ??
                                  'My Favorites',
                              favChannels,
                              showMore: true,
                              onMoreTap: () => Navigator.pushNamed(
                                  context, AppRouter.favorites)),
                          SizedBox(height: PlatformDetector.isMobile ? 8 : 12),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactHeader(ChannelProvider provider) {
    // Get last played channel - use watch to listen for changes
    final settingsProvider = context.watch<SettingsProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();
    final activePlaylist = playlistProvider.activePlaylist;
    Channel? lastChannel;
    final bool isMultiScreenMode = settingsProvider.lastPlayMode == 'multi' &&
        settingsProvider.hasMultiScreenState;

    ServiceLocator.log.d(
        'HomeScreen: lastPlayMode=${settingsProvider.lastPlayMode}, hasMultiScreenState=${settingsProvider.hasMultiScreenState}, isMultiScreenMode=$isMultiScreenMode');
    ServiceLocator.log.d(
        'HomeScreen: lastMultiScreenChannels=${settingsProvider.lastMultiScreenChannels}');

    if (settingsProvider.rememberLastChannel &&
        settingsProvider.lastChannelId != null) {
      try {
        lastChannel = provider.channels.firstWhere(
          (c) => c.id == settingsProvider.lastChannelId,
        );
      } catch (_) {
        // Channel does not exist, using first channel
        lastChannel =
            provider.channels.isNotEmpty ? provider.channels.first : null;
      }
    } else {
      lastChannel =
          provider.channels.isNotEmpty ? provider.channels.first : null;
    }

    // Build playlist info
    String playlistInfo = '';
    if (activePlaylist != null) {
      final type = activePlaylist.isRemote ? 'URL' : 'Local';
      playlistInfo = ' · [$type] ${activePlaylist.name}';
      if (activePlaylist.url != null && activePlaylist.url!.isNotEmpty) {
        String url =
            activePlaylist.url!.replaceFirst(RegExp(r'^https?://'), '');
        if (url.length > 30) {
          url = '${url.substring(0, 30)}...';
        }
        playlistInfo += ' · $url';
      }
    }

    // Continue Watching button
    final continueLabel =
        AppStrings.of(context)?.continueWatching ?? 'Continue';
    final isMobile = PlatformDetector.isMobile;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape = isMobile && screenWidth > 700; // Mobile landscape

    return Container(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24,
          isMobile ? 12 : 24,
          isMobile ? 16 : 24,
          isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.getBackgroundColor(context),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.03), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/icons/app_icon.jpg',
                        height: isLandscape ? 30 : (isMobile ? 36 : 48),
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text Title
                    Expanded(
                      child: Text(
                        "LUMIO IPTV",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // App Version
                    Flexible(
                      child: Text('V$_appVersion',
                          style: TextStyle(
                              fontSize: isLandscape ? 9 : 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Colors.white38),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (_availableUpdate != null) ...[
                      const SizedBox(width: 12),
                      TVFocusable(
                        onSelect: () => Navigator.pushNamed(
                            context, AppRouter.settings,
                            arguments: {'autoCheckUpdate': true}),
                        focusScale: 1.0,
                        showFocusBorder: false,
                        builder: (context, isFocused, child) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isFocused
                                  ? AppTheme.getPrimaryColor(context)
                                  : AppTheme.successColor.withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(6),
                              border: Border.all(
                                  color: isFocused
                                      ? Colors.white
                                      : AppTheme.successColor.withOpacity(0.5),
                                  width: 1.5)
                            ),
                            child: child,
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.system_update_rounded,
                                size: 10, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('UPDATE',
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (!isMobile || MediaQuery.of(context).size.width <= 700) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${provider.totalChannelCount} CHANNELS · ${provider.groups.length} CATEGORIES',
                    style: TextStyle(
                        color: AppTheme.getTextMuted(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildHeaderButton(
                  Icons.play_arrow_rounded,
                  "CONTINUE",
                  true,
                  (lastChannel != null || isMultiScreenMode)
                      ? () => _continuePlayback(provider, lastChannel,
                          isMultiScreenMode, settingsProvider)
                      : null,
                  focusNode: _continueButtonFocusNode),
              _buildHeaderButton(
                  Icons.refresh_rounded,
                  "REFRESH",
                  false,
                  activePlaylist != null
                      ? () =>
                          _refreshCurrentPlaylist(playlistProvider, provider)
                      : null),
              _buildThemeToggleButton(),
            ],
          ),
        ],
      ),
    );
  }

  /// Continue Watching - 支持Single channel和Multi-screen模式
  void _continuePlayback(ChannelProvider provider, Channel? lastChannel,
      bool isMultiScreenMode, SettingsProvider settingsProvider) {
    ServiceLocator.log
        .i('Continue Watching - 模式: ${isMultiScreenMode ? "Multi-screen" : "Single channel"}', tag: 'HomeScreen');

    if (isMultiScreenMode) {
      // Recover Multi-screen mode
      _resumeMultiScreen(provider, settingsProvider);
    } else if (lastChannel != null) {
      // Recover Single channel playback
      ServiceLocator.log.d('Recover Single channel playback: ${lastChannel.name}', tag: 'HomeScreen');
      _playChannel(lastChannel);
    }
  }

  /// Show add playlist dialog
  Future<void> _showAddPlaylistDialog() async {
    final result = PlatformDetector.isMobile
        ? await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const AddPlaylistDialog(),
          )
        : await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AddPlaylistDialog(),
          );

    // If playlist added successfully, refresh data
    if (result == true && mounted) {
      _loadData();
    }
  }

  /// 刷新当前播放列表
  Future<void> _refreshCurrentPlaylist(PlaylistProvider playlistProvider,
      ChannelProvider channelProvider) async {
    ServiceLocator.log.i('开始刷新当前播放列表', tag: 'HomeScreen');
    final startTime = DateTime.now();

    final activePlaylist = playlistProvider.activePlaylist;
    if (activePlaylist == null) {
      ServiceLocator.log.w('No active playlist, cannot refresh', tag: 'HomeScreen');
      return;
    }

    // Clear logo loading queue and cache, prepare to reload
    clearAllLogoCache(); // Complete cleanup, including loaded cache

    // Show loading hint
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refreshing ${activePlaylist.name}...'),
        duration: const Duration(seconds: 2),
      ),
    );

    ServiceLocator.log.d(
        'Refresh playlist: ${activePlaylist.name} (ID: ${activePlaylist.id})',
        tag: 'HomeScreen');

    // Execute refresh
    final success = await playlistProvider.refreshPlaylist(activePlaylist);

    if (!mounted) return;

    if (success) {
      // Refresh successful，重新加载channels
      if (activePlaylist.id != null) {
        await channelProvider.loadChannels(activePlaylist.id!);
        // Refresh watch history
        _refreshWatchHistory();

        // 重新Load EPG (use playlist EPG URL, fallback to settings URL if it fails)
        final epgProvider = context.read<EpgProvider>();
        final settingsProvider = context.read<SettingsProvider>();

        // Reload playlist to get latest EPG URL
        await playlistProvider.loadPlaylists();
        final updatedPlaylist = playlistProvider.activePlaylist;

        if (updatedPlaylist?.epgUrl != null) {
          ServiceLocator.log.d(
              'HomeScreen: Reload using playlist EPG URL: ${updatedPlaylist!.epgUrl}');
          await epgProvider.loadEpg(
            updatedPlaylist.epgUrl!,
            fallbackUrl: settingsProvider.epgUrl,
          );
        } else if (settingsProvider.epgUrl != null) {
          ServiceLocator.log.d(
              'HomeScreen: Reload using fallback EPG URL from settings: ${settingsProvider.epgUrl}');
          await epgProvider.loadEpg(settingsProvider.epgUrl!);
        }
      }

      final refreshTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i('播放列表Refresh successful，time taken: ${refreshTime}ms', tag: 'HomeScreen');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Refresh successful'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      ServiceLocator.log.e('播放列表Refresh failed', tag: 'HomeScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Refresh failed: ${playlistProvider.error?.replaceAll("Exception:", "").trim() ?? ""}'),
          duration: const Duration(seconds: 5),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  /// 恢复Multi-screen播放
  Future<void> _resumeMultiScreen(
      ChannelProvider provider, SettingsProvider settingsProvider) async {
    ServiceLocator.log.i('开始恢复Multi-screen播放', tag: 'HomeScreen');

    final channels = provider.channels;
    final multiScreenChannelIds = settingsProvider.lastMultiScreenChannels;
    final activeIndex = settingsProvider.activeScreenIndex;

    ServiceLocator.log.d('Multi-screenchannelsID: $multiScreenChannelIds', tag: 'HomeScreen');
    ServiceLocator.log.d('Active screen index: $activeIndex', tag: 'HomeScreen');

    // Set providers for state saving
    final favoritesProvider = context.read<FavoritesProvider>();
    NativePlayerChannel.setProviders(
        favoritesProvider, provider, settingsProvider);

    // 将channelsID转换为channels索引
    final List<int?> restoreScreenChannels = [];
    int initialChannelIndex = 0;
    bool foundFirst = false;

    for (int i = 0; i < multiScreenChannelIds.length; i++) {
      final channelId = multiScreenChannelIds[i];
      if (channelId != null) {
        final index = channels.indexWhere((c) => c.id == channelId);
        if (index >= 0) {
          restoreScreenChannels.add(index);
          if (!foundFirst) {
            initialChannelIndex = index;
            foundFirst = true;
          }
        } else {
          restoreScreenChannels.add(null);
        }
      } else {
        restoreScreenChannels.add(null);
      }
    }

    ServiceLocator.log.d('恢复屏幕channels: $restoreScreenChannels', tag: 'HomeScreen');

    // 检查是否是 Android TV，使用Native Multi-screen
    if (PlatformDetector.isAndroid) {
      ServiceLocator.log.d('Use Android TV native Multi-screen', tag: 'HomeScreen');
      final urls = channels.map((c) => c.url).toList();
      final names = channels.map((c) => c.name).toList();
      final groups = channels.map((c) => c.groupName ?? '').toList();
      final sources = channels.map((c) => c.sources).toList();
      final logos = channels.map((c) => c.logoUrl ?? '').toList();

      await NativePlayerChannel.launchMultiScreen(
        urls: urls,
        names: names,
        groups: groups,
        sources: sources,
        logos: logos,
        initialChannelIndex: initialChannelIndex,
        volumeBoostDb: settingsProvider.volumeBoost,
        defaultScreenPosition: settingsProvider.defaultScreenPosition,
        restoreActiveIndex: activeIndex,
        restoreScreenChannels: restoreScreenChannels,
        showChannelName: settingsProvider.showMultiScreenChannelName,
        onClosed: () {
          ServiceLocator.log.i('Native Multi-screen player closed, Refresh watch history', tag: 'HomeScreen');
          // TV sideNative Multi-screen播放器关闭后，Refresh watch history
          _refreshWatchHistory();
        },
      );
      ServiceLocator.log.i('Native Multi-screen player started successfully', tag: 'HomeScreen');
    } else {
      // Windows/other platforms use Flutter Multi-screen
      ServiceLocator.log.d('使用 Flutter Multi-screen', tag: 'HomeScreen');
      if (!mounted) return;

      // 预先设置 MultiScreenProvider 的channels状态
      final multiScreenProvider = context.read<MultiScreenProvider>();

      // Set volume boost (must be set before playback)
      multiScreenProvider.setVolumeSettings(1.0, settingsProvider.volumeBoost);

      // Set active screen (must be set before playback)
      multiScreenProvider.setActiveScreen(activeIndex);

      // 恢复每个屏幕的channels（等待所有播放完成）
      final futures = <Future>[];
      for (int i = 0; i < multiScreenChannelIds.length && i < 4; i++) {
        final channelId = multiScreenChannelIds[i];
        if (channelId != null) {
          final channel = channels.firstWhere(
            (c) => c.id == channelId,
            orElse: () => channels.first,
          );
          // 播放channels到对应屏幕
          futures.add(multiScreenProvider.playChannelOnScreen(i, channel));
        }
      }

      // 等待所有channels开始播放
      await Future.wait(futures);

      ServiceLocator.log.d('所有Multi-screenchannels加载完成', tag: 'HomeScreen');

      // Wait briefly to ensure all players have started playing
      await Future.delayed(const Duration(milliseconds: 500));

      // 所有channels加载完成后，重新应用音量设置确保只有活动屏幕有声音
      await multiScreenProvider.reapplyVolumeToAllScreens();

      ServiceLocator.log.i('Flutter Multi-screen playback recovery successful', tag: 'HomeScreen');

      // 找到初始channels（用于路由参数）
      Channel? initialChannel;
      if (initialChannelIndex >= 0 && initialChannelIndex < channels.length) {
        initialChannel = channels[initialChannelIndex];
      } else if (channels.isNotEmpty) {
        initialChannel = channels.first;
      }

      if (initialChannel != null && mounted) {
        Navigator.pushNamed(
          context,
          AppRouter.player,
          arguments: {
            'channelUrl': initialChannel.url,
            'channelName': initialChannel.name,
            'isMultiScreen': true,
          },
        );
      }
    }
  }

  Widget _buildHeaderButton(
      IconData icon, String label, bool isPrimary, VoidCallback? onTap,
      {FocusNode? focusNode}) {
    final isMobile = PlatformDetector.isMobile;
    return TVFocusable(
      focusNode: focusNode,
      onSelect: onTap,
      focusScale: 1.05,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 20, vertical: isMobile ? 10 : 14),
          decoration: BoxDecoration(
            color: isFocused
                ? Colors.white
                : (isPrimary ? AppTheme.getPrimaryColor(context).withOpacity(0.15) : AppTheme.getSurfaceColor(context)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFocused ? Colors.white : (isPrimary ? AppTheme.getPrimaryColor(context).withOpacity(0.3) : Colors.white.withOpacity(0.05)),
              width: 2.0,
            ),
            boxShadow: isFocused ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ] : null,
          ),
          child: child,
        );
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          final contentColor = isFocused
              ? Colors.black
              : (isPrimary ? AppTheme.getPrimaryColor(context) : Colors.white70);

          if (isMobile && !isPrimary) {
            return Icon(icon, color: contentColor, size: 20);
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: contentColor, size: 20),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: contentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(ChannelProvider provider) {
    final settings = context.watch<SettingsProvider>();
    final isMobile = PlatformDetector.isMobile;

    Channel? heroChannel;
    if (settings.lastChannelId != null) {
      try {
        heroChannel = provider.channels.firstWhere((c) => c.id == settings.lastChannelId);
      } catch (_) {}
    }
    heroChannel ??= provider.channels.isNotEmpty ? provider.channels.first : null;

    if (heroChannel == null) return const SizedBox.shrink();

    return Container(
      height: isMobile ? 220 : 380,
      margin: const EdgeInsets.only(bottom: 12),
      child: TVFocusable(
        onSelect: () => _playChannel(heroChannel!),
        focusScale: 1.02,
        showFocusBorder: false,
        builder: (context, isFocused, child) {
          return AnimatedContainer(
            duration: AppTheme.animationFast,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isFocused ? Colors.white : Colors.white.withOpacity(0.05),
                width: isFocused ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Logo/Placeholder
            Container(
              color: const Color(0xFF141414),
              child: Opacity(
                opacity: 0.4,
                child: ChannelLogoWidget(
                  channel: heroChannel,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Premium Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.9),
                  ],
                  stops: const [0.0, 0.4, 0.9],
                ),
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(isMobile ? 20 : 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.getPrimaryColor(context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PREMIUM CONTENT',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    heroChannel.name.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 24 : 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (heroChannel.groupName != null)
                    Text(
                      heroChannel.groupName!.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: isMobile ? 12 : 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildHeroButton(
                        Icons.play_arrow_rounded,
                        'PLAY NOW',
                        true,
                        () => _playChannel(heroChannel!),
                      ),
                      if (!isMobile)
                        _buildHeroButton(
                          Icons.info_outline_rounded,
                          'CHANNEL INFO',
                          false,
                          () => _showChannelOptions(context, heroChannel!),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroButton(IconData icon, String label, bool isPrimary, VoidCallback onTap) {
    return TVFocusable(
      onSelect: onTap,
      focusScale: 1.1,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: isFocused
                ? (isPrimary ? Colors.white : Colors.white.withOpacity(0.2))
                : (isPrimary ? Colors.white : Colors.white.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        );
      },
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;
        final color = isFocused ? Colors.black : Colors.white;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildCategoryChips(ChannelProvider provider) {
    return _ResponsiveCategoryChips(
      groups: provider.groups,
      onGroupTap: (groupName) => Navigator.pushNamed(
          context, AppRouter.channels,
          arguments: {'groupName': groupName}),
    );
  }

  Widget _buildChannelRow(String title, List<Channel> channels,
      {bool showMore = false,
      VoidCallback? onMoreTap,
      bool isFirstRow = false}) {
    // Add isFirstRow parameter
    if (channels.isEmpty) return const SizedBox.shrink();
    final isMobile = PlatformDetector.isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title.toUpperCase(),
                style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: isMobile ? 13 : 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0)),
            const Spacer(),
            if (showMore)
              TVFocusable(
                onSelect: onMoreTap,
                focusScale: 1.05,
                showFocusBorder: false,
                builder: (context, isFocused, child) {
                  return AnimatedContainer(
                    duration: AppTheme.animationFast,
                    padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 14,
                        vertical: isMobile ? 5 : 7),
                    decoration: BoxDecoration(
                      color: isFocused ? Colors.white : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Builder(builder: (context) {
                      final isFocused = Focus.of(context).hasFocus;
                      return Text(AppStrings.of(context)?.more.toUpperCase() ?? 'MORE',
                          style: TextStyle(
                              color: isFocused ? Colors.black : AppTheme.getTextMuted(context),
                              fontWeight: FontWeight.w900,
                              fontSize: isMobile ? 10 : 11));
                    }),
                    const SizedBox(width: 4),
                    Builder(builder: (context) {
                      final isFocused = Focus.of(context).hasFocus;
                      return Icon(Icons.chevron_right_rounded,
                          color: isFocused ? Colors.black : AppTheme.getTextMuted(context),
                          size: isMobile ? 14 : 16);
                    }),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: isMobile ? 6 : 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // 如果没有channels，不显示任何内容
            if (channels.isEmpty) {
              return const SizedBox.shrink();
            }

            final availableWidth = constraints.maxWidth;
            // Home screen uses specialized calculation to show more smaller cards
            final cardsPerRow =
                CardSizeCalculator.calculateHomeCardsPerRow(availableWidth);
            final cardSpacing = CardSizeCalculator.spacing;
            final totalSpacing = (cardsPerRow - 1) * cardSpacing;
            final cardWidth = (availableWidth - totalSpacing) / cardsPerRow;
            final cardHeight = cardWidth / CardSizeCalculator.aspectRatio();

            // 显示数量不能超过实际channels数量
            final displayCount = cardsPerRow.clamp(1, channels.length);

            return SizedBox(
              height: cardHeight,
              child: Row(
                children: List.generate(displayCount, (index) {
                  final channel = channels[index];

                  return Padding(
                    padding: EdgeInsets.only(
                        right: index < displayCount - 1 ? cardSpacing : 0),
                    child: SizedBox(
                      width: cardWidth,
                      child: _OptimizedChannelCard(
                        channel: channel,
                        onTap: () => _playChannel(channel),
                        onUp: isFirstRow && PlatformDetector.isTV
                            ? () {
                                // TV side第一行（Watch History）When pressing UP, jump to "Continue Watching" button
                                if (_scrollController.hasClients &&
                                    _scrollController.offset > 0) {
                                  // If not at top, scroll to top first
                                  _scrollController.animateTo(
                                    0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                }
                                // Request focus for "Continue Watching" button
                                _continueButtonFocusNode.requestFocus();
                              }
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _playChannel(Channel channel) async {
    ServiceLocator.log
        .i('播放channels: ${channel.name} (ID: ${channel.id})', tag: 'HomeScreen');
    // final startTime = DateTime.now();

    // 保存上次播放的channelsID
    final settingsProvider = context.read<SettingsProvider>();
    final channelProvider = context.read<ChannelProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();

    // Set providers for state saving和favorites功能
    NativePlayerChannel.setProviders(
        favoritesProvider, channelProvider, settingsProvider);

    if (settingsProvider.rememberLastChannel && channel.id != null) {
      // Save Single channel playback state
      settingsProvider.saveLastSingleChannel(channel.id);
    }

    // Check if Multi-screen mode is enabled
    if (settingsProvider.enableMultiScreen) {
      // TV 端使用Native Multi-screen播放器
      if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
        final channels = channelProvider.channels;

        // 找到当前点击channels的索引
        final clickedIndex = channels.indexWhere((c) => c.url == channel.url);

        // TV sideNative Multi-screen播放器 also needs to record Watch History
        if (channel.id != null && channel.playlistId != null) {
          await ServiceLocator.watchHistory
              .addWatchHistory(channel.id!, channel.playlistId!);
          ServiceLocator.log.d(
              'HomeScreen: Recorded watch history for channel ${channel.name} (TV multi-screen)');
        }

        // 准备channels数据
        final urls = channels.map((c) => c.url).toList();
        final names = channels.map((c) => c.name).toList();
        final groups = channels.map((c) => c.groupName ?? '').toList();
        final sources = channels.map((c) => c.sources).toList();
        final logos = channels.map((c) => c.logoUrl ?? '').toList();

        // Start Native Multi-screen播放器
        await NativePlayerChannel.launchMultiScreen(
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
            ServiceLocator.log.d(
                'HomeScreen: Native multi-screen closed, refreshing watch history');
            // TV sideNative Multi-screen播放器关闭后，Refresh watch history
            _refreshWatchHistory();
          },
        );
      } else if (PlatformDetector.isDesktop) {
        // 桌面端Multi-screen模式：在指定位置播放channels
        final multiScreenProvider = context.read<MultiScreenProvider>();
        final defaultPosition = settingsProvider.defaultScreenPosition;
        // Set volume boost to Multi-screenProvider
        multiScreenProvider.setVolumeSettings(
            1.0, settingsProvider.volumeBoost);
        multiScreenProvider.playChannelAtDefaultPosition(
            channel, defaultPosition);

        // Multi-screen模式下导航到播放器页面，但不传递channels参数（由MultiScreenProvider处理播放）
        Navigator.pushNamed(context, AppRouter.player, arguments: {
          'channelUrl': '', // Empty URL indicates Multi-screen mode
          'channelName': '',
          'channelLogo': null,
        });
      } else {
        // Normal playback on other platforms
        context.read<PlayerProvider>().playChannel(channel);
        Navigator.pushNamed(context, AppRouter.player, arguments: {
          'channelUrl': channel.url,
          'channelName': channel.name,
          'channelLogo': channel.logoUrl,
        });
      }
    } else {
      // Normal mode: navigate to player page directly, without calling PlayerProvider.playChannel()
      // Avoid duplicate Watch History recording (PlayerScreen will record it)
      Navigator.pushNamed(context, AppRouter.player, arguments: {
        'channelUrl': channel.url,
        'channelName': channel.name,
        'channelLogo': channel.logoUrl,
      });
    }
  }

  List<Channel> _getFavoriteChannels(ChannelProvider provider) {
    final favProvider = context.read<FavoritesProvider>();
    // Take up to 20 as candidates, actual display count depends on width
    return provider.channels
        .where((c) => favProvider.isFavorite(c.id ?? 0))
        .take(20)
        .toList();
  }

  Widget _buildThemeToggleButton() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final isDark = settings.themeMode == 'dark' ||
            (settings.themeMode == 'system' &&
                MediaQuery.of(context).platformBrightness == Brightness.dark);

        return TVFocusable(
          onSelect: () {
            settings.setThemeMode(isDark ? 'light' : 'dark');
          },
          focusScale: 1.1,
          showFocusBorder: false,
          child: const SizedBox.shrink(),
          builder: (context, isFocused, child) {
            return AnimatedContainer(
              duration: AppTheme.animationFast,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isFocused ? Colors.white : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 20,
                color: isFocused ? Colors.black : Colors.white70,
              ),
            );
          },
        );
      },
    );
  }

  void _showChannelOptions(BuildContext context, Channel channel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.getBackgroundColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.play_arrow_rounded),
                  title: Text(AppStrings.of(context)?.play ?? 'Play'),
                  onTap: () {
                    Navigator.pop(context);
                    _playChannel(channel);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.favorite_rounded),
                  title:
                      Text(AppStrings.of(context)?.addFavorites ?? 'Add to Favorites'),
                  onTap: () {
                    context.read<FavoritesProvider>().toggleFavorite(channel);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
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
                gradient: AppTheme.getGradient(context),
                borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.playlist_add_rounded,
                size: 48, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(AppStrings.of(context)?.noPlaylistYet ?? 'No Playlists Yet',
              style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
              AppStrings.of(context)?.addM3uToStart ??
                  'Add M3U playlist to start watching',
              style: TextStyle(
                  color: AppTheme.getTextSecondary(context), fontSize: 13)),
          const SizedBox(height: 24),
          TVFocusable(
            autofocus: false,
            onSelect: () => _showAddPlaylistDialog(),
            focusScale: 1.0,
            showFocusBorder: false,
            builder: (context, isFocused, child) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppTheme.getGradient(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: isFocused
                      ? Border.all(
                          color: AppTheme.getPrimaryColor(context), width: 2)
                      : null,
                ),
                child: child,
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  AppStrings.of(context)?.addPlaylist ?? 'Add Playlist',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

/// 响应式categories标签组件 - 根据宽度自适应，超出时折叠
class _ResponsiveCategoryChips extends StatefulWidget {
  final List<dynamic> groups;
  final Function(String) onGroupTap;

  const _ResponsiveCategoryChips({
    required this.groups,
    required this.onGroupTap,
  });

  @override
  State<_ResponsiveCategoryChips> createState() =>
      _ResponsiveCategoryChipsState();
}

class _ResponsiveCategoryChipsState extends State<_ResponsiveCategoryChips> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformDetector.isMobile;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = isMobile ? 12.0 : 24.0;
        final availableWidth = constraints.maxWidth - horizontalPadding * 2;

        // Calculate approximate width of each chip (icon + text + padding)
        // Use smaller estimated width on mobile
        final estimatedChipWidth = isMobile ? 75.0 : 110.0;
        final maxVisibleCount = (availableWidth / estimatedChipWidth).floor();

        // 如果所有categories都能显示，直接用 Wrap
        if (widget.groups.length <= maxVisibleCount || _isExpanded) {
          return _buildExpandedView(isMobile, horizontalPadding);
        }

        // Otherwise show some + expand button
        return _buildCollapsedView(
            maxVisibleCount, isMobile, horizontalPadding);
      },
    );
  }

  Widget _buildExpandedView(bool isMobile, double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: isMobile ? 6 : 8,
          runSpacing: isMobile ? 6 : 8,
          alignment: WrapAlignment.start,
          children: [
            ...widget.groups.map((group) => _buildChip(group.name, isMobile)),
            if (widget.groups.length > 6) _buildCollapseButton(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedView(
      int maxVisible, bool isMobile, double horizontalPadding) {
    // Show at least 4, leave one space for expand button
    final visibleCount = (maxVisible - 1).clamp(3, widget.groups.length);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: isMobile ? 6 : 8,
          runSpacing: isMobile ? 6 : 8,
          alignment: WrapAlignment.start,
          children: [
            ...widget.groups
                .take(visibleCount)
                .map((group) => _buildChip(group.name, isMobile)),
            _buildExpandButton(widget.groups.length - visibleCount, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String name, bool isMobile) {
    return TVFocusable(
      onSelect: () => widget.onGroupTap(name),
      focusScale: 1.05,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 20,
              vertical: isMobile ? 8 : 12),
          decoration: BoxDecoration(
            color: isFocused ? Colors.white : AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: isFocused ? Colors.white : Colors.white.withOpacity(0.05),
              width: 1.5,
            ),
          ),
          child: child,
        );
      },
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;
        final color = isFocused ? Colors.black : AppTheme.getTextPrimary(context);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CategoryCard.getIconForCategory(name),
                size: isMobile ? 14 : 16,
                color: color),
            SizedBox(width: isMobile ? 6 : 10),
            Text(name.toUpperCase(),
                style: TextStyle(
                    color: color,
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
          ],
        );
      }),
    );
  }

  Widget _buildExpandButton(int hiddenCount, bool isMobile) {
    return TVFocusable(
      onSelect: () => setState(() => _isExpanded = true),
      focusScale: 1.05,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 20,
              vertical: isMobile ? 8 : 12),
          decoration: BoxDecoration(
            color: isFocused ? Colors.white : AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: isFocused ? Colors.white : Colors.white.withOpacity(0.05),
              width: 1.5,
            ),
          ),
          child: child,
        );
      },
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;
        final color = isFocused ? Colors.black : AppTheme.getTextPrimary(context);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz_rounded,
                size: isMobile ? 14 : 16,
                color: color),
            SizedBox(width: isMobile ? 4 : 6),
            Text('+$hiddenCount',
                style: TextStyle(
                    color: color,
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w900)),
          ],
        );
      }),
    );
  }

  Widget _buildCollapseButton(bool isMobile) {
    return TVFocusable(
      onSelect: () => setState(() => _isExpanded = false),
      focusScale: 1.05,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 20,
              vertical: isMobile ? 8 : 12),
          decoration: BoxDecoration(
            color: isFocused ? Colors.white : AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: isFocused ? Colors.white : Colors.white.withOpacity(0.05),
              width: 1.5,
            ),
          ),
          child: child,
        );
      },
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;
        final color = isFocused ? Colors.black : AppTheme.getTextPrimary(context);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.unfold_less_rounded,
                size: isMobile ? 14 : 16,
                color: color),
            SizedBox(width: isMobile ? 4 : 6),
            Text(AppStrings.of(context)?.collapse.toUpperCase() ?? 'COLLAPSE',
                style: TextStyle(
                    color: color,
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
          ],
        );
      }),
    );
  }
}

/// 优化的channels卡片组件 - 使用 Selector 精确控制重建
class _OptimizedChannelCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final VoidCallback? onUp; // Add onUp callback

  const _OptimizedChannelCard({
    required this.channel,
    required this.onTap,
    this.onUp, // Add onUp parameter
  });

  @override
  Widget build(BuildContext context) {
    // 使用 Selector 监听favorites状态和 EPG 数据变化
    return Selector2<FavoritesProvider, EpgProvider, _ChannelCardData>(
      selector: (_, favProvider, epgProvider) {
        final currentProgram =
            epgProvider.getCurrentProgram(channel.epgId, channel.name);
        final nextProgram =
            epgProvider.getNextProgram(channel.epgId, channel.name);
        return _ChannelCardData(
          isFavorite: favProvider.isFavorite(channel.id ?? 0),
          currentProgram: currentProgram?.title,
          nextProgram: nextProgram?.title,
        );
      },
      builder: (context, data, _) {
        return ChannelCard(
          name: channel.name,
          logoUrl: channel.logoUrl,
          groupName: channel.groupName,
          currentProgram: data.currentProgram,
          nextProgram: data.nextProgram,
          isFavorite: data.isFavorite,
          onFavoriteToggle: () =>
              context.read<FavoritesProvider>().toggleFavorite(channel),
          onTap: onTap,
          onUp: onUp, // Pass onUp callback
        );
      },
    );
  }
}

/// channels卡片数据，用于 Selector 比较
class _ChannelCardData {
  final bool isFavorite;
  final String? currentProgram;
  final String? nextProgram;

  _ChannelCardData({
    required this.isFavorite,
    this.currentProgram,
    this.nextProgram,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ChannelCardData &&
        other.isFavorite == isFavorite &&
        other.currentProgram == currentProgram &&
        other.nextProgram == nextProgram;
  }

  @override
  int get hashCode => Object.hash(isFavorite, currentProgram, nextProgram);
}

/// Embedded channel page（手机端底部导航用）
class _EmbeddedChannelsScreen extends StatefulWidget {
  const _EmbeddedChannelsScreen();

  @override
  State<_EmbeddedChannelsScreen> createState() =>
      _EmbeddedChannelsScreenState();
}

class _EmbeddedChannelsScreenState extends State<_EmbeddedChannelsScreen> {
  @override
  void initState() {
    super.initState();
    // 每次显示时清除categories筛选
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChannelProvider>().clearGroupFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const ChannelsScreen(embedded: true);
  }
}

/// Embedded favorites page
class _EmbeddedFavoritesScreen extends StatelessWidget {
  const _EmbeddedFavoritesScreen();

  @override
  Widget build(BuildContext context) {
    return const FavoritesScreen(embedded: true);
  }
}

/// Embedded playlist page
class _EmbeddedPlaylistListScreen extends StatelessWidget {
  const _EmbeddedPlaylistListScreen();

  @override
  Widget build(BuildContext context) {
    return const PlaylistListScreen();
  }
}

/// Embedded search page
class _EmbeddedSearchScreen extends StatelessWidget {
  const _EmbeddedSearchScreen();

  @override
  Widget build(BuildContext context) {
    return const SearchScreen(embedded: true);
  }
}

/// Embedded settings page
class _EmbeddedSettingsScreen extends StatelessWidget {
  const _EmbeddedSettingsScreen();

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen(embedded: true);
  }
}
