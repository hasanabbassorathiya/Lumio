import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/local_server_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/i18n/app_strings.dart';
import '../../channels/providers/channel_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';
import '../providers/playlist_provider.dart';
import '../../favorites/providers/favorites_provider.dart';

/// Dialog for scanning QR code to import playlist on TV
class QrImportDialog extends StatefulWidget {
  const QrImportDialog({super.key});

  @override
  State<QrImportDialog> createState() => _QrImportDialogState();
}

class _QrImportDialogState extends State<QrImportDialog> {
  final LocalServerService _serverService = LocalServerService();
  bool _isLoading = true;
  bool _isServerRunning = false;
  String? _error;
  String? _receivedMessage;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  @override
  void dispose() {
    _serverService.stop();
    super.dispose();
  }

  Future<void> _startServer() async {
    ServiceLocator.log.d('Starting local server...');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Set up callbacks
    _serverService.onUrlReceived = _handleUrlReceived;
    _serverService.onContentReceived = _handleContentReceived;

    final success = await _serverService.start();
    ServiceLocator.log.d('Server start result: ${success ? "Success" : "Failed"}');
    if (success) {
      ServiceLocator.log.d('Server URL: ${_serverService.serverUrl}');
    }

    setState(() {
      _isLoading = false;
      _isServerRunning = success;
      if (!success) {
        // Use detailed error information returned by the server
        _error = _serverService.lastError ??
                (AppStrings.of(context)?.serverStartFailed ?? 'Failed to start local server. Please check network connection.');
      }
    });
  }

  void _handleUrlReceived(String url, String name) async {
    if (_isImporting) return;

    ServiceLocator.log.d('Received URL import request - Name: $name, URL: $url');

    setState(() {
      _isImporting = true;
      _receivedMessage = '${AppStrings.of(context)?.importingPlaylist ?? "Importing"}: $name';
    });

    try {
      final provider = context.read<PlaylistProvider>();
      ServiceLocator.log.d('Starting to add playlist via URL...');
      final playlist = await provider.addPlaylistFromUrl(name, url);

      if (playlist != null && mounted) {
        ServiceLocator.log.d('Playlist added successfully: ${playlist.name} (ID: ${playlist.id})');

        // Set newly imported playlist as active
        final playlistProvider = context.read<PlaylistProvider>();
        final favoritesProvider = context.read<FavoritesProvider>();
        playlistProvider.setActivePlaylist(playlist, favoritesProvider: favoritesProvider);

        // Load channels for the new playlist
        final channelProvider = context.read<ChannelProvider>();
        if (playlist.id != null) {
          ServiceLocator.log.d('Loading channels for newly imported playlist...');
          await channelProvider.loadChannels(playlist.id!);
        }

        // Auto-load EPG: Try playlist EPG URL first, fallback to settings EPG URL
        if (mounted) {
          final settingsProvider = context.read<SettingsProvider>();
          final epgProvider = context.read<EpgProvider>();

          if (settingsProvider.enableEpg) {
            final playlistEpgUrl = provider.lastExtractedEpgUrl;
            final fallbackEpgUrl = settingsProvider.epgUrl;

            if (playlistEpgUrl != null && playlistEpgUrl.isNotEmpty) {
              ServiceLocator.log.d('Loading playlist EPG: $playlistEpgUrl (Fallback: $fallbackEpgUrl)');
              await epgProvider.loadEpg(playlistEpgUrl, fallbackUrl: fallbackEpgUrl);
            } else if (fallbackEpgUrl != null && fallbackEpgUrl.isNotEmpty) {
              ServiceLocator.log.d('Using fallback EPG URL: $fallbackEpgUrl');
              await epgProvider.loadEpg(fallbackEpgUrl);
            }
          }
        }

        setState(() {
          _receivedMessage = '✓ ${AppStrings.of(context)?.importSuccess ?? "Import successful"}: ${playlist.name}';
          _isImporting = false;
        });

        // Auto close after success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        ServiceLocator.log.d('Failed to add playlist');
        setState(() {
          _receivedMessage = '✗ ${AppStrings.of(context)?.importFailed ?? "Import failed"}';
          _isImporting = false;
        });
      }
    } catch (e) {
      ServiceLocator.log.d('Error occurred during URL import: $e');
      ServiceLocator.log.d('Error stack trace: ${StackTrace.current}');
      setState(() {
        _receivedMessage = '✗ ${AppStrings.of(context)?.importFailed ?? "Import failed"}: $e';
        _isImporting = false;
      });
    }
  }

  void _handleContentReceived(String content, String name) async {
    if (_isImporting) return;

    ServiceLocator.log.d('Received content import request - Name: $name, Content length: ${content.length}');

    setState(() {
      _isImporting = true;
      _receivedMessage = '${AppStrings.of(context)?.importingPlaylist ?? "Importing"}: $name';
    });

    try {
      final provider = context.read<PlaylistProvider>();
      ServiceLocator.log.d('Starting to add playlist via content...');
      final playlist = await provider.addPlaylistFromContent(name, content);

      if (playlist != null && mounted) {
        ServiceLocator.log.d('Playlist added successfully: ${playlist.name} (ID: ${playlist.id})');

        // Set newly imported playlist as active
        final playlistProvider = context.read<PlaylistProvider>();
        final favoritesProvider = context.read<FavoritesProvider>();
        playlistProvider.setActivePlaylist(playlist, favoritesProvider: favoritesProvider);

        // Load channels for the new playlist
        final channelProvider = context.read<ChannelProvider>();
        if (playlist.id != null) {
          ServiceLocator.log.d('Loading channels for newly imported playlist...');
          await channelProvider.loadChannels(playlist.id!);
        }

        // Auto-load EPG: Try playlist EPG URL first, fallback to settings EPG URL
        if (mounted) {
          final settingsProvider = context.read<SettingsProvider>();
          final epgProvider = context.read<EpgProvider>();

          if (settingsProvider.enableEpg) {
            final playlistEpgUrl = provider.lastExtractedEpgUrl;
            final fallbackEpgUrl = settingsProvider.epgUrl;

            if (playlistEpgUrl != null && playlistEpgUrl.isNotEmpty) {
              ServiceLocator.log.d('Loading playlist EPG: $playlistEpgUrl (Fallback: $fallbackEpgUrl)');
              await epgProvider.loadEpg(playlistEpgUrl, fallbackUrl: fallbackEpgUrl);
            } else if (fallbackEpgUrl != null && fallbackEpgUrl.isNotEmpty) {
              ServiceLocator.log.d('Using fallback EPG URL: $fallbackEpgUrl');
              await epgProvider.loadEpg(fallbackEpgUrl);
            }
          }
        }

        setState(() {
          _receivedMessage = '✓ ${AppStrings.of(context)?.importSuccess ?? "Import successful"}: ${playlist.name}';
          _isImporting = false;
        });

        // Auto close after success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        ServiceLocator.log.d('Failed to add playlist');
        setState(() {
          _receivedMessage = '✗ ${AppStrings.of(context)?.importFailed ?? "Import failed"}';
          _isImporting = false;
        });
      }
    } catch (e) {
      ServiceLocator.log.d('Error occurred during content import: $e');
      ServiceLocator.log.d('Error stack trace: ${StackTrace.current}');
      setState(() {
        _receivedMessage = '✗ ${AppStrings.of(context)?.importFailed ?? "Import failed"}: $e';
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // 手机横屏：宽度600-900，高度小于宽度
    final isLandscape = screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;
    final isMobile = screenWidth < 600;
    
    return Dialog(
      backgroundColor: AppTheme.getSurfaceColor(context),
      insetPadding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isLandscape ? 12 : 20),  // 横屏时圆角更小
        child: Container(
          width: isLandscape ? 420 : (isMobile ? null : 520),  // 横屏时宽度更小：480→420
          constraints: isLandscape 
              ? const BoxConstraints(maxHeight: 320)  // 横屏时限制高度：350→320
              : (isMobile ? const BoxConstraints(maxWidth: 400) : null),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
          ),
          padding: EdgeInsets.all(isLandscape ? 10 : 20),  // 横屏10，竖屏恢复到20
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isLandscape ? 6 : 8),  // 横屏时padding更小
                        decoration: BoxDecoration(
                          gradient: AppTheme.getGradient(context),
                          borderRadius: BorderRadius.circular(isLandscape ? 8 : 10),
                        ),
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: isLandscape ? 18 : 22,  // 横屏时图标更小
                        ),
                      ),
                      SizedBox(width: isLandscape ? 10 : 12),  // 横屏时间距更小
                      Expanded(
                        child: Text(
                          AppStrings.of(context)?.scanToImport ?? 'Scan to Import Playlist',
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: isLandscape ? 13 : (isMobile ? 16 : 18),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // Leave space for close button
                    ],
                  ),

                  SizedBox(height: isLandscape ? 6 : 12),

                  // Content
                  if (_isLoading)
                    _buildLoadingState(isLandscape)
                  else if (_error != null)
                    _buildErrorState(isLandscape)
                  else if (_isServerRunning)
                    _buildQrCodeState(isMobile, isLandscape),
                ],
              ),

              // Top right close button
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  iconSize: isLandscape ? 16 : 24,  // 横屏图标更小：20→16
                  onPressed: () => Navigator.of(context).pop(false),
                  color: AppTheme.getTextMuted(context),
                  padding: EdgeInsets.all(isLandscape ? 2 : 8),  // 横屏padding更小：4→2
                  constraints: const BoxConstraints(),
                  tooltip: AppStrings.of(context)?.close ?? 'Close',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isLandscape) {
    return Column(
      children: [
        SizedBox(
          width: isLandscape ? 28 : 48,  // 横屏时进度条更小：32→28
          height: isLandscape ? 28 : 48,
          child: const CircularProgressIndicator(
            strokeWidth: 3,
            color: AppTheme.primaryColor,
          ),
        ),
        SizedBox(height: isLandscape ? 8 : 16),  // 横屏时间距更小：10→8
        Text(
          AppStrings.of(context)?.startingServer ?? 'Starting server...',
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: isLandscape ? 10 : 14,  // 横屏时字体更小：11→10
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isLandscape) {
    return Column(
      children: [
        Icon(
          Icons.error_outline_rounded,
          color: AppTheme.errorColor,
          size: isLandscape ? 28 : 48,  // 横屏时图标更小：32→28
        ),
        SizedBox(height: isLandscape ? 8 : 16),  // 横屏时间距更小：10→8
        Text(
          _error!,
          style: TextStyle(
            color: AppTheme.errorColor,
            fontSize: isLandscape ? 10 : 14,  // 横屏时字体更小：11→10
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isLandscape ? 8 : 16),  // 横屏时间距更小：10→8
        TVFocusable(
          onSelect: _startServer,
          child: ElevatedButton(
            onPressed: _startServer,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 12 : 24,  // 横屏padding更小：16→12
                vertical: isLandscape ? 6 : 12,  // 横屏padding更小：8→6
              ),
            ),
            child: Text(
              AppStrings.of(context)?.retry ?? 'Retry',
              style: TextStyle(fontSize: isLandscape ? 10 : 14),  // 横屏时字体更小：11→10
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrCodeState(bool isMobile, bool isLandscape) {
    if (isMobile || isLandscape) {
      // 手机端（竖屏或横屏）：纵向布局
      return Column(
        children: [
          // QR Code
          Container(
            padding: EdgeInsets.all(isLandscape ? 6 : 6),  // Reduce padding
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isLandscape ? 6 : 6),  // Reduce corner radius
            ),
            child: QrImageView(
              data: _serverService.importUrl,
              version: QrVersions.auto,
              size: isLandscape ? 90 : 160,  // 90 in landscape, back to 160 in portrait
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),

          SizedBox(height: isLandscape ? 5 : 12),  // 5 in landscape, back to 12 in portrait

          // Instructions
          Container(
            padding: EdgeInsets.all(isLandscape ? 5 : 8),  // 5 in landscape, back to 8 in portrait
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context),
              borderRadius: BorderRadius.circular(isLandscape ? 6 : 6),  // Reduce corner radius
              border: Border.all(
                color: AppTheme.getPrimaryColor(context).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildStep('1', AppStrings.of(context)?.qrStep1 ?? 'Scan the QR code with your phone', isLandscape),
                SizedBox(height: isLandscape ? 2 : 6),  // 2 in landscape, back to 6 in portrait
                _buildStep('2', AppStrings.of(context)?.qrStep2 ?? 'Enter URL or upload file on the webpage', isLandscape),
                SizedBox(height: isLandscape ? 2 : 6),  // 2 in landscape, back to 6 in portrait
                _buildStep('3', AppStrings.of(context)?.qrStep3 ?? 'Click import, TV receives automatically', isLandscape),
              ],
            ),
          ),

          SizedBox(height: isLandscape ? 5 : 10),  // 5 in landscape, back to 10 in portrait

          // Server URL
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 5 : 8,  // 5 in landscape, back to 8 in portrait
              vertical: isLandscape ? 2 : 6,  // 2 in landscape, back to 6 in portrait
            ),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context).withAlpha(128),
              borderRadius: BorderRadius.circular(isLandscape ? 4 : 4),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.wifi_rounded,
                  color: AppTheme.getTextMuted(context),
                  size: isLandscape ? 10 : 12,  // 10 in landscape, back to 12 in portrait
                ),
                SizedBox(width: isLandscape ? 4 : 6),  // 4 in landscape, back to 6 in portrait
                Expanded(
                  child: Text(
                    _serverService.importUrl,
                    style: TextStyle(
                      color: AppTheme.getTextMuted(context),
                      fontSize: isLandscape ? 8 : 10,  // 8 in landscape, back to 10 in portrait
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Status message
          if (_receivedMessage != null) ...[
            SizedBox(height: isLandscape ? 5 : 10),  // 5 in landscape, back to 10 in portrait
            Container(
              padding: EdgeInsets.all(isLandscape ? 3 : 6),  // 3 in landscape, back to 6 in portrait
              decoration: BoxDecoration(
                color: _receivedMessage!.contains('✓')
                    ? Colors.green.withAlpha(51)
                    : _receivedMessage!.contains('✗')
                        ? Colors.red.withAlpha(51)
                        : AppTheme.primaryColor.withAlpha(51),
                borderRadius: BorderRadius.circular(isLandscape ? 4 : 4),
              ),
              child: Row(
                children: [
                  if (_isImporting)
                    SizedBox(
                      width: isLandscape ? 10 : 12,  // 10 in landscape, back to 12 in portrait
                      height: isLandscape ? 10 : 12,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  if (_isImporting) SizedBox(width: isLandscape ? 4 : 6),  // 4 in landscape, back to 6 in portrait
                  Expanded(
                    child: Text(
                      _receivedMessage!,
                      style: TextStyle(
                        color: _receivedMessage!.contains('✓')
                            ? Colors.green
                            : _receivedMessage!.contains('✗')
                                ? Colors.red
                                : AppTheme.getTextPrimary(context),
                        fontWeight: FontWeight.w500,
                        fontSize: isLandscape ? 9 : 11,  // 9 in landscape, back to 11 in portrait
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    
    // TV/桌面端：横向布局
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: QR Code
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: _serverService.importUrl,
            version: QrVersions.auto,
            size: 160,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),

        const SizedBox(width: 20),

        // Right: Instructions and URL
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.getPrimaryColor(context).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    _buildStep('1', AppStrings.of(context)?.qrStep1 ?? 'Scan the QR code with your phone', false),
                    const SizedBox(height: 8),
                    _buildStep('2', AppStrings.of(context)?.qrStep2 ?? 'Enter URL or upload file on the webpage', false),
                    const SizedBox(height: 8),
                    _buildStep('3', AppStrings.of(context)?.qrStep3 ?? 'Click import, TV receives automatically', false),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Server URL
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context).withAlpha(128),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_rounded,
                      color: AppTheme.getTextMuted(context),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _serverService.importUrl,
                        style: TextStyle(
                          color: AppTheme.getTextMuted(context),
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Status message
              if (_receivedMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _receivedMessage!.contains('✓')
                        ? Colors.green.withAlpha(51)
                        : _receivedMessage!.contains('✗')
                            ? Colors.red.withAlpha(51)
                            : AppTheme.primaryColor.withAlpha(51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (_isImporting)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      if (_isImporting) const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _receivedMessage!,
                          style: TextStyle(
                            color: _receivedMessage!.contains('✓')
                                ? Colors.green
                                : _receivedMessage!.contains('✗')
                                    ? Colors.red
                                    : AppTheme.getTextPrimary(context),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text, bool isLandscape) {
    return Row(
      children: [
        Container(
          width: isLandscape ? 14 : 18,  // 14 in landscape, back to 18 in portrait
          height: isLandscape ? 14 : 18,
          decoration: BoxDecoration(
            gradient: AppTheme.getGradient(context),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontSize: isLandscape ? 7 : 10,  // 7 in landscape, back to 10 in portrait
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: isLandscape ? 4 : 6),  // 4 in landscape, back to 6 in portrait
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: isLandscape ? 8 : 11,  // 8 in landscape, back to 11 in portrait
            ),
          ),
        ),
      ],
    );
  }
}
