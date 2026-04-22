import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../services/service_locator.dart';

/// Custom HTTP client with timeout for logo loading
class _TimeoutHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final Duration timeout;

  _TimeoutHttpClient({this.timeout = const Duration(seconds: 2)});  // Restore 2s timeout

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(timeout);
  }

  @override
  void close() {
    _inner.close();
  }
}

/// Custom cache manager with short timeout for logo loading
class LogoCacheManager extends CacheManager {
  static const key = 'logoCache';
  static LogoCacheManager? _instance;

  factory LogoCacheManager() {
    _instance ??= LogoCacheManager._();
    return _instance!;
  }

  LogoCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 500,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: HttpFileService(
              httpClient: _TimeoutHttpClient(timeout: const Duration(seconds: 2)),  // Restore 2s timeout
            ),
          ),
        );
}

/// Global logo state manager to persist logo loading states across widget rebuilds
class _LogoStateManager {
  static final _LogoStateManager _instance = _LogoStateManager._();
  factory _LogoStateManager() => _instance;
  _LogoStateManager._();

  // Track channels where M3U logo failed (using channel name as key)
  final Map<String, bool> _m3uLogoFailed = {};

  // Track database logo URL (using channel name as key)
  final Map<String, String?> _fallbackLogoUrls = {};

  // Track already tried channels (do not retry even if result is null)
  final Set<String> _fallbackLoaded = {};

  // Channels loading fallback
  final Set<String> _loadingFallback = {};

  // Concurrency control: limit concurrent logo loads
  static const int _maxConcurrentLoads = 20; // Restored: max 10 concurrent logo loads
  int _currentLoadingCount = 0;
  final List<Function> _pendingLoads = [];

  bool isM3uLogoFailed(String channelName) {
    return _m3uLogoFailed[channelName] ?? false;
  }

  void markM3uLogoFailed(String channelName) {
    _m3uLogoFailed[channelName] = true;
  }

  String? getFallbackLogoUrl(String channelName) {
    return _fallbackLogoUrls[channelName];
  }

  void setFallbackLogoUrl(String channelName, String? url) {
    _fallbackLogoUrls[channelName] = url;
    _fallbackLoaded.add(channelName); // Mark as loaded
  }

  bool isFallbackLoaded(String channelName) {
    return _fallbackLoaded.contains(channelName);
  }

  bool isLoadingFallback(String channelName) {
    return _loadingFallback.contains(channelName);
  }

  void markLoadingFallback(String channelName, bool loading) {
    if (loading) {
      _loadingFallback.add(channelName);
    } else {
      _loadingFallback.remove(channelName);
    }
  }

  /// Request fallback logo, queue if limit exceeded
  Future<void> requestLoadFallback(Function loadFunction) async {
    if (_currentLoadingCount < _maxConcurrentLoads) {
      _currentLoadingCount++;
      try {
        await loadFunction();
      } finally {
        _currentLoadingCount--;
        _processNextPendingLoad();
      }
    } else {
      // Join queue and wait
      _pendingLoads.add(loadFunction);
    }
  }

  void _processNextPendingLoad() {
    if (_pendingLoads.isNotEmpty && _currentLoadingCount < _maxConcurrentLoads) {
      final nextLoad = _pendingLoads.removeAt(0);
      _currentLoadingCount++;
      nextLoad().then((_) {
        _currentLoadingCount--;
        _processNextPendingLoad();
      }).catchError((_) {
        _currentLoadingCount--;
        _processNextPendingLoad();
      });
    }
  }

  void clear() {
    _m3uLogoFailed.clear();
    _fallbackLogoUrls.clear();
    _fallbackLoaded.clear();
    _loadingFallback.clear();
    _pendingLoads.clear();
    _currentLoadingCount = 0;
  }

  /// Clear pending loading queue (but keep loaded cache)
  void clearPendingLoads() {
    _pendingLoads.clear();
    ServiceLocator.log.d('Logo loading queue cleared, pending tasks: 0');
  }
}

/// Public access: Clear logo loading queue
void clearLogoLoadingQueue() {
  _LogoStateManager().clearPendingLoads();
}

/// Public access: Fully clear logo cache (including loaded)
void clearAllLogoCache() {
  _LogoStateManager().clear();
  ServiceLocator.log.d('Logo cache fully cleared');
}

/// Widget to display channel logo with fallback priority:
/// 1. M3U logo (if available and loads successfully)
/// 2. Database logo (fuzzy match by channel name)
/// 3. Default placeholder image
class ChannelLogoWidget extends StatefulWidget {
  final Channel channel;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool lazyLoad; // Whether to lazy load logo (for list optimization)

  const ChannelLogoWidget({
    super.key,
    required this.channel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.lazyLoad = true, // Lazy load enabled by default
  });

  @override
  State<ChannelLogoWidget> createState() => _ChannelLogoWidgetState();
}

class _ChannelLogoWidgetState extends State<ChannelLogoWidget> {
  final _logoState = _LogoStateManager();
  bool _isDisposed = false; // Add flag to prevent operations after dispose

  @override
  void initState() {
    super.initState();
    // Remove logs to reduce main thread load
    // ServiceLocator.log.d('ChannelLogoWidget.initState - ${widget.channel.name}, logoUrl: ${widget.channel.logoUrl}, lazyLoad: ${widget.lazyLoad}');

    // If not lazy load mode, or channel has no M3U logo, load database logo immediately
    if (!widget.lazyLoad || widget.channel.logoUrl == null || widget.channel.logoUrl!.isEmpty) {
      // ServiceLocator.log.d('ChannelLogoWidget: Load database logo immediately - ${widget.channel.name}');
      _loadFallbackLogo();
    }
  }

  @override
  void dispose() {
    _isDisposed = true; // Marked as disposed
    super.dispose();
  }

  Future<void> _loadFallbackLogo() async {
    final channelName = widget.channel.name;

    // If disposed, return
    if (_isDisposed) return;

    // If already loaded (regardless of result) or loading, return directly
    if (_logoState.isFallbackLoaded(channelName) ||
        _logoState.isLoadingFallback(channelName)) {
      return;
    }

    // Load with concurrency control
    await _logoState.requestLoadFallback(() async {
      // Check again if disposed
      if (_isDisposed) return;

      _logoState.markLoadingFallback(channelName, true);
      // ServiceLocator.log.d('ChannelLogoWidget: Started loading database logo - $channelName');

      try {
        final logoUrl = await ServiceLocator.channelLogo.findLogoUrl(channelName);
        // ServiceLocator.log.d('ChannelLogoWidget: Database logo query result - $channelName: $logoUrl');

        _logoState.setFallbackLogoUrl(channelName, logoUrl); // This will also mark as loaded
        _logoState.markLoadingFallback(channelName, false);

        // Check if disposed before calling setState
        if (!_isDisposed && mounted) {
          setState(() {});
          // ServiceLocator.log.d('ChannelLogoWidget: Database logo set - $channelName');
        }
      } catch (e) {
        ServiceLocator.log.w('Failed to load fallback logo for $channelName: $e');
        _logoState.setFallbackLogoUrl(channelName, null); // Mark as loaded even if null
        _logoState.markLoadingFallback(channelName, false);
        if (!_isDisposed && mounted) {
          setState(() {});
        }
      }
    });
  }

  void _ensureFallbackLoaded() {
    // If disposed, return directly
    if (_isDisposed) return;

    final channelName = widget.channel.name;
    // Lazy load: only load when needed
    if (widget.lazyLoad &&
        _logoState.isM3uLogoFailed(channelName) &&
        !_logoState.isFallbackLoaded(channelName) &&
        !_logoState.isLoadingFallback(channelName)) {
      // Use addPostFrameCallback to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted) {
          _loadFallbackLogo();
        }
      });
    }
  }

  void _onM3uLogoError() {
    // If disposed, return directly
    if (_isDisposed) return;

    final channelName = widget.channel.name;
    // Only trigger on first failure
    if (!_logoState.isM3uLogoFailed(channelName)) {
      // ServiceLocator.log.d('ChannelLogoWidget: M3U logo failed, trying database logo - $channelName');
      _logoState.markM3uLogoFailed(channelName);
      // Load database logo immediately
      if (!_logoState.isFallbackLoaded(channelName) &&
          !_logoState.isLoadingFallback(channelName)) {
        _loadFallbackLogo();
      } else if (!_isDisposed && mounted) {
        setState(() {});
      }
    }
  }

  Widget _buildLogo(String? logoUrl, {bool isM3uLogo = false}) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return _buildPlaceholder();
    }

    // ServiceLocator.log.d('ChannelLogoWidget: Attempting to load logo - ${widget.channel.name}: $logoUrl');

    return CachedNetworkImage(
      imageUrl: logoUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheManager: LogoCacheManager(), // Use custom cache manager
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) {
        // ServiceLocator.log.w('ChannelLogoWidget: Logo load failed - ${widget.channel.name}: $error');

        // Only trigger fallback on M3U logo failure
        if (isM3uLogo) {
          _onM3uLogoError();
        }
        return _buildPlaceholder();
      },
      httpHeaders: const {
        'Connection': 'close',
      },
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
      // Note: maxWidthDiskCache and maxHeightDiskCache cannot be used with custom CacheManager
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
      ),
      child: Image.asset(
        'assets/images/default_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // If default image fails, show icon
          return Icon(
            Icons.tv,
            size: (widget.width ?? 48) * 0.5,
            color: Colors.grey[600],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channelName = widget.channel.name;
    final m3uLogoFailed = _logoState.isM3uLogoFailed(channelName);
    final fallbackLogoUrl = _logoState.getFallbackLogoUrl(channelName);
    
    Widget logoWidget;

    // Priority 1: Try M3U logo if available and not failed
    if (!m3uLogoFailed && 
        widget.channel.logoUrl != null && 
        widget.channel.logoUrl!.isNotEmpty) {
      logoWidget = _buildLogo(widget.channel.logoUrl, isM3uLogo: true);
    }
    // Priority 2: Try database fallback logo
    else if (fallbackLogoUrl != null && fallbackLogoUrl.isNotEmpty) {
      logoWidget = _buildLogo(fallbackLogoUrl, isM3uLogo: false);
    }
    // Priority 3: Default placeholder (or loading fallback)
    else {
      // In lazy load mode, trigger fallback when M3U logo fails
      _ensureFallbackLoaded();
      logoWidget = _buildPlaceholder();
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: logoWidget,
      );
    }

    return logoWidget;
  }
}
