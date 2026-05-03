import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/local_server_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/i18n/app_strings.dart';

/// Dialog for scanning QR code to search channels on TV
class QrSearchDialog extends StatefulWidget {
  final Function(String query) onSearchReceived;
  
  const QrSearchDialog({
    super.key,
    required this.onSearchReceived,
  });

  @override
  State<QrSearchDialog> createState() => _QrSearchDialogState();
}

class _QrSearchDialogState extends State<QrSearchDialog> {
  final LocalServerService _serverService = LocalServerService();
  bool _isLoading = true;
  bool _isServerRunning = false;
  String? _error;

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
    ServiceLocator.log.d('开始启动搜索服务器...');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Set up callback
    _serverService.onSearchReceived = _handleSearchReceived;

    final success = await _serverService.start();
    ServiceLocator.log.d('搜索服务器启动结果: ${success ? "成功" : "失败"}');
    if (success) {
      ServiceLocator.log.d('搜索服务器URL: ${_serverService.serverUrl}');
    }

    setState(() {
      _isLoading = false;
      _isServerRunning = success;
      if (!success) {
        _error = _serverService.lastError ?? 
                (AppStrings.of(context)?.serverStartFailed ?? 'Failed to start local server. Please check network connection.');
      }
    });
  }

  void _handleSearchReceived(String query) {
    ServiceLocator.log.d('收到搜索请求: $query');
    
    if (mounted) {
      // 关闭对话框并执行搜索
      Navigator.of(context).pop();
      widget.onSearchReceived(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Dialog(
      backgroundColor: AppTheme.getSurfaceColor(context),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: isMobile ? null : 520,
        constraints: isMobile ? const BoxConstraints(maxWidth: 400) : null,
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.5),
        ),
        padding: EdgeInsets.all(isMobile ? 20 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.getPrimaryColor(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppTheme.getPrimaryColor(context),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    AppStrings.of(context)?.scanToSearch.toUpperCase() ?? 'SCAN TO SEARCH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Content
            if (_isLoading) _buildLoadingState() else if (_error != null) _buildErrorState() else if (_isServerRunning) _buildQrCodeState(isMobile),

            const SizedBox(height: 24),

            // Close button
            TVFocusable(
              autofocus: true,
              showFocusBorder: false,
              onSelect: () => Navigator.of(context).pop(),
              builder: (context, isFocused, child) {
                return AnimatedContainer(
                  duration: AppTheme.animationFast,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isFocused ? Colors.white : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: child,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Builder(builder: (context) {
                  final isFocused = Focus.of(context).hasFocus;
                  return Text(
                    AppStrings.of(context)?.close.toUpperCase() ?? 'CLOSE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isFocused ? Colors.black : Colors.white60,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppStrings.of(context)?.startingServer ?? 'Starting server...',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppTheme.errorColor,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          _error!,
          style: const TextStyle(color: AppTheme.errorColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TVFocusable(
          onSelect: _startServer,
          child: ElevatedButton(
            onPressed: _startServer,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.of(context)?.retry ?? 'Retry'),
          ),
        ),
      ],
    );
  }

  Widget _buildQrCodeState(bool isMobile) {
    if (isMobile) {
      // 手机端：纵向布局
      return Column(
        children: [
          // QR Code
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: _serverService.searchUrl,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),

          const SizedBox(height: 16),

          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildStep('1', AppStrings.of(context)?.qrSearchStep1 ?? 'Scan the QR code with your phone'),
                const SizedBox(height: 8),
                _buildStep('2', AppStrings.of(context)?.qrSearchStep2 ?? 'Enter search query on the webpage'),
                const SizedBox(height: 8),
                _buildStep('3', AppStrings.of(context)?.qrSearchStep3 ?? 'Results will appear on TV automatically'),
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
                    _serverService.searchUrl,
                    style: TextStyle(
                      color: AppTheme.getTextMuted(context),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
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
            data: _serverService.searchUrl,
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
                ),
                child: Column(
                  children: [
                    _buildStep('1', AppStrings.of(context)?.qrSearchStep1 ?? 'Scan the QR code with your phone'),
                    const SizedBox(height: 8),
                    _buildStep('2', AppStrings.of(context)?.qrSearchStep2 ?? 'Enter search query on the webpage'),
                    const SizedBox(height: 8),
                    _buildStep('3', AppStrings.of(context)?.qrSearchStep3 ?? 'Results will appear on TV automatically'),
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
                        _serverService.searchUrl,
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withAlpha(51),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
