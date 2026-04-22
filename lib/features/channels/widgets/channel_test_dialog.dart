import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/channel.dart';
import '../../../core/services/channel_test_service.dart';
import '../../../core/services/background_test_service.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../providers/channel_provider.dart';

/// Channel test dialog result
class ChannelTestDialogResult {
  final List<ChannelTestResult> results;
  final bool movedToUnavailable; // Whether moved to unavailable category
  final bool runInBackground; // Whether to run in background
  final int remainingCount; // Remaining un-tested count

  ChannelTestDialogResult({
    required this.results,
    this.movedToUnavailable = false,
    this.runInBackground = false,
    this.remainingCount = 0,
  });
}

/// Channel test dialog
class ChannelTestDialog extends StatefulWidget {
  final List<Channel> channels;

  const ChannelTestDialog({
    super.key,
    required this.channels,
  });

  @override
  State<ChannelTestDialog> createState() => _ChannelTestDialogState();
}

class _ChannelTestDialogState extends State<ChannelTestDialog> {
  final ChannelTestService _testService = ChannelTestService();
  StreamSubscription<ChannelTestProgress>? _subscription;

  bool _isTesting = false;
  bool _isComplete = false;
  int _total = 0;
  int _completed = 0;
  int _available = 0;
  int _unavailable = 0;
  String _currentChannelName = '';
  List<ChannelTestResult> _results = [];
  bool _showOnlyFailed = false;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startTest() {
    setState(() {
      _isTesting = true;
      _isComplete = false;
      _total = widget.channels.length;
      _completed = 0;
      _available = 0;
      _unavailable = 0;
      _results = [];
    });

    _subscription = _testService.testChannels(widget.channels).listen(
      (progress) {
        if (mounted) {
          setState(() {
            _completed = progress.completed;
            _available = progress.available;
            _unavailable = progress.unavailable;
            _currentChannelName = progress.currentChannel.name;
            _results = progress.results;
            _isComplete = progress.isComplete;
            if (_isComplete) {
              _isTesting = false;
            }
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _isTesting = false;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isTesting = false;
            _isComplete = true;
          });
        }
      },
    );
  }

  void _stopTest() {
    _subscription?.cancel();
    setState(() {
      _isTesting = false;
    });
  }

  List<ChannelTestResult> get _filteredResults {
    if (_showOnlyFailed) {
      return _results.where((r) => !r.isAvailable).toList();
    }
    return _results;
  }

  Future<void> _moveToUnavailableGroup(BuildContext context) async {
    final unavailableChannelIds = _results.where((r) => !r.isAvailable).map((r) => r.channel.id).whereType<int>().toList();

    if (unavailableChannelIds.isEmpty) return;

    // Move to unavailable category
    await context.read<ChannelProvider>().markChannelsAsUnavailable(unavailableChannelIds);

    // Return result, mark as moved
    if (mounted) {
      Navigator.of(context).pop(ChannelTestDialogResult(
        results: _results,
        movedToUnavailable: true,
      ));
    }
  }

  void _runInBackground(BuildContext context) {
    // Stop current test
    _subscription?.cancel();

    // Get remaining un-tested channels
    final testedIds = _results.map((r) => r.channel.id).toSet();
    final remainingChannels = widget.channels.where((c) => !testedIds.contains(c.id)).toList();

    // Start background test
    final backgroundService = BackgroundTestService();
    backgroundService.startTest(remainingChannels);

    // Close dialog, return special flag indicating background execution
    Navigator.of(context).pop(ChannelTestDialogResult(
      results: _results,
      movedToUnavailable: false,
      runInBackground: true,
      remainingCount: remainingChannels.length,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // Mobile landscape: width 600-900, height less than width
    final isLandscape = screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;

    return Dialog(
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isLandscape ? 12 : 16)),
      child: Container(
        width: isLandscape ? 250 : 500,  // smaller width in landscape
        constraints: BoxConstraints(maxHeight: isLandscape ? 350 : 600),  // smaller height in landscape
        padding: EdgeInsets.all(isLandscape ? 12 : 24),  // smaller padding in landscape
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isLandscape ? 6 : 10),  // smaller padding in landscape
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
                  ),
                  child: Icon(
                    Icons.speed_rounded,
                    color: AppTheme.primaryColor,
                    size: isLandscape ? 18 : 24,  // smaller icon in landscape
                  ),
                ),
                SizedBox(width: isLandscape ? 10 : 16),  // smaller spacing in landscape
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Channel Test',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: isLandscape ? 14 : 20,  // smaller font in landscape
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Total ${widget.channels.length} channels',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: isLandscape ? 11 : 14,  // smaller font in landscape
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: isLandscape ? 18 : 24),  // smaller icon in landscape
                  color: AppTheme.textSecondary,
                  padding: isLandscape ? const EdgeInsets.all(4) : null,  // smaller padding in landscape
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            SizedBox(height: isLandscape ? 12 : 24),  // smaller spacing in landscape

            // Progress Area
            if (_isTesting || _isComplete) ...[
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(isLandscape ? 6 : 8),
                child: LinearProgressIndicator(
                  value: _total > 0 ? _completed / _total : 0,
                  backgroundColor: AppTheme.cardColor,
                  color: AppTheme.primaryColor,
                  minHeight: isLandscape ? 6 : 8,  // thinner bar in landscape
                ),
              ),
              SizedBox(height: isLandscape ? 8 : 12),  // smaller spacing in landscape

              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Tested', '$_completed/$_total', AppTheme.textPrimary, isLandscape),
                  _buildStatItem('Available', '$_available', Colors.green, isLandscape),
                  _buildStatItem('Unavailable', '$_unavailable', AppTheme.errorColor, isLandscape),
                ],
              ),

              SizedBox(height: isLandscape ? 8 : 12),  // smaller spacing in landscape

              // Current Testing Channel
              if (_isTesting)
                Container(
                  padding: EdgeInsets.all(isLandscape ? 8 : 12),  // smaller padding in landscape
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(isLandscape ? 6 : 8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: isLandscape ? 12 : 16,  // smaller progress indicator in landscape
                        height: isLandscape ? 12 : 16,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(width: isLandscape ? 8 : 12),  // smaller spacing in landscape
                      Expanded(
                        child: Text(
                          'Testing: $_currentChannelName',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: isLandscape ? 11 : 13,  // smaller font in landscape
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: isLandscape ? 10 : 16),  // smaller spacing in landscape

              // Filter Options
              if (_results.isNotEmpty)
                Row(
                  children: [
                    Text(
                      'Test Results',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: isLandscape ? 13 : 16,  // smaller font in landscape
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    FilterChip(
                      label: Text('Only Failures ($_unavailable)'),
                      selected: _showOnlyFailed,
                      onSelected: (v) => setState(() => _showOnlyFailed = v),
                      selectedColor: AppTheme.errorColor.withOpacity(0.2),
                      checkmarkColor: AppTheme.errorColor,
                      labelStyle: TextStyle(
                        color: _showOnlyFailed ? AppTheme.errorColor : AppTheme.textSecondary,
                        fontSize: isLandscape ? 10 : 12,  // smaller font in landscape
                      ),
                      padding: isLandscape ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : null,  // smaller padding in landscape
                    ),
                  ],
                ),

              SizedBox(height: isLandscape ? 6 : 8),  // smaller spacing in landscape

              // Results List
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
                  ),
                  child: _filteredResults.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(isLandscape ? 16 : 24),  // smaller padding in landscape
                            child: Text(
                              'No results',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: isLandscape ? 12 : 14,  // smaller font in landscape
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.all(isLandscape ? 6 : 8),  // smaller padding in landscape
                          itemCount: _filteredResults.length,
                          separatorBuilder: (_, __) => const Divider(
                            color: AppTheme.surfaceColor,
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final result = _filteredResults[index];
                            return _buildResultItem(result, isLandscape);
                          },
                        ),
                ),
              ),
            ] else ...[
              // Tip when not started
              Container(
                padding: EdgeInsets.all(isLandscape ? 16 : 24),  // smaller padding in landscape
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: isLandscape ? 32 : 48,  // smaller icon in landscape
                      color: AppTheme.textMuted.withOpacity(0.5),
                    ),
                    SizedBox(height: isLandscape ? 10 : 16),  // smaller spacing in landscape
                    Text(
                      'Click Start Test to check channel availability',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: isLandscape ? 12 : 14,  // smaller font in landscape
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isLandscape ? 6 : 8),  // smaller spacing in landscape
                    Text(
                      'Testing will check the connection status of each channel',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: isLandscape ? 10 : 12,  // smaller font in landscape
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: isLandscape ? 12 : 24),  // smaller spacing in landscape

            // Action Buttons
            Column(
              children: [
                Row(
                  children: [
                    if (_isComplete && _unavailable > 0) ...[
                      Expanded(
                        child: TVFocusable(
                          onSelect: () => _moveToUnavailableGroup(context),
                          child: OutlinedButton.icon(
                            onPressed: () => _moveToUnavailableGroup(context),
                            icon: Icon(Icons.folder_special_rounded, size: isLandscape ? 14 : 18),  // smaller icon in landscape
                            label: Text(
                              'Move to Unavailable',
                              style: TextStyle(fontSize: isLandscape ? 11 : 14),  // smaller font in landscape
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              padding: EdgeInsets.symmetric(vertical: isLandscape ? 8 : 14),  // smaller padding in landscape
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(isLandscape ? 6 : 10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isLandscape ? 8 : 12),  // smaller spacing in landscape
                    ],
                    Expanded(
                      child: TVFocusable(
                        autofocus: !_isTesting && !_isComplete,
                        onSelect: _isTesting ? _stopTest : (_isComplete ? () => Navigator.of(context).pop() : _startTest),
                        child: ElevatedButton.icon(
                          onPressed: _isTesting ? _stopTest : (_isComplete ? () => Navigator.of(context).pop() : _startTest),
                          icon: Icon(
                            _isTesting ? Icons.stop_rounded : (_isComplete ? Icons.check_rounded : Icons.play_arrow_rounded),
                            size: isLandscape ? 16 : 20,  // smaller icon in landscape
                          ),
                          label: Text(
                            _isTesting ? 'Stop Test' : (_isComplete ? 'Complete' : 'Start Test'),
                            style: TextStyle(fontSize: isLandscape ? 11 : 14),  // smaller font in landscape
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isTesting ? AppTheme.errorColor : AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: isLandscape ? 8 : 14),  // smaller padding in landscape
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(isLandscape ? 6 : 10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Run in Background button
                if (_isTesting) ...[
                  SizedBox(height: isLandscape ? 8 : 12),  // smaller spacing in landscape
                  SizedBox(
                    width: double.infinity,
                    child: TVFocusable(
                      onSelect: () => _runInBackground(context),
                      child: OutlinedButton.icon(
                        onPressed: () => _runInBackground(context),
                        icon: Icon(Icons.open_in_new_rounded, size: isLandscape ? 14 : 18),  // smaller icon in landscape
                        label: Text(
                          'Run in Background',
                          style: TextStyle(fontSize: isLandscape ? 11 : 14),  // smaller font in landscape
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.cardColor),
                          padding: EdgeInsets.symmetric(vertical: isLandscape ? 8 : 12),  // smaller padding in landscape
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(isLandscape ? 6 : 10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, bool isLandscape) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isLandscape ? 14 : 20,  // smaller font in landscape
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isLandscape ? 2 : 4),  // smaller spacing in landscape
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: isLandscape ? 10 : 12,  // smaller font in landscape
          ),
        ),
      ],
    );
  }

  Widget _buildResultItem(ChannelTestResult result, bool isLandscape) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 6 : 8,  // smaller padding in landscape
        vertical: isLandscape ? 4 : 6,
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            width: isLandscape ? 20 : 28,  // smaller icon in landscape
            height: isLandscape ? 20 : 28,
            decoration: BoxDecoration(
              color: result.isAvailable ? Colors.green.withOpacity(0.2) : AppTheme.errorColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(isLandscape ? 6 : 8),
            ),
            child: Icon(
              result.isAvailable ? Icons.check_rounded : Icons.close_rounded,
              color: result.isAvailable ? Colors.green : AppTheme.errorColor,
              size: isLandscape ? 12 : 16,  // smaller icon in landscape
            ),
          ),
          SizedBox(width: isLandscape ? 8 : 12),  // smaller spacing in landscape
          // Channel Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.channel.name,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: isLandscape ? 11 : 13,  // smaller font in landscape
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (result.error != null)
                  Text(
                    result.error!,
                    style: TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: isLandscape ? 9 : 11,  // smaller font in landscape
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Response Time
          if (result.responseTime != null)
            Text(
              '${result.responseTime}ms',
              style: TextStyle(
                color: result.isAvailable ? AppTheme.textMuted : AppTheme.errorColor,
                fontSize: isLandscape ? 9 : 11,  // smaller font in landscape
              ),
            ),
        ],
      ),
    );
  }
}

/// Background test progress dialog
class BackgroundTestProgressDialog extends StatefulWidget {
  const BackgroundTestProgressDialog({super.key});

  @override
  State<BackgroundTestProgressDialog> createState() => _BackgroundTestProgressDialogState();
}

class _BackgroundTestProgressDialogState extends State<BackgroundTestProgressDialog> {
  final BackgroundTestService _backgroundService = BackgroundTestService();
  late BackgroundTestProgress _progress;

  @override
  void initState() {
    super.initState();
    _progress = _backgroundService.currentProgress;
    _backgroundService.addListener(_onProgressUpdate);
  }

  @override
  void dispose() {
    _backgroundService.removeListener(_onProgressUpdate);
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
    return Dialog(
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _progress.isRunning ? Icons.sync_rounded : Icons.check_circle_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Background Test',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _progress.isRunning ? 'Test in progress...' : 'Test complete',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppTheme.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress.progress,
                backgroundColor: AppTheme.cardColor,
                color: AppTheme.primaryColor,
                minHeight: 8,
              ),
            ),

            const SizedBox(height: 16),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Tested', '${_progress.completed}/${_progress.total}', AppTheme.textPrimary),
                _buildStatItem('Available', '${_progress.available}', Colors.green),
                _buildStatItem('Unavailable', '${_progress.unavailable}', AppTheme.errorColor),
              ],
            ),

            // Current Testing Channel
            if (_progress.isRunning && _progress.currentChannelName != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Testing: ${_progress.currentChannelName}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                if (_progress.isComplete && _progress.unavailable > 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _moveToUnavailableGroup(context),
                      icon: const Icon(Icons.folder_special_rounded, size: 18),
                      label: const Text('Move to Unavailable'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _progress.isRunning
                        ? () {
                            _backgroundService.stopTest();
                          }
                        : () {
                            _backgroundService.clearResults();
                            Navigator.of(context).pop();
                          },
                    icon: Icon(
                      _progress.isRunning ? Icons.stop_rounded : Icons.check_rounded,
                      size: 20,
                    ),
                    label: Text(_progress.isRunning ? 'Stop Test' : 'Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _progress.isRunning ? AppTheme.errorColor : AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Future<void> _moveToUnavailableGroup(BuildContext context) async {
    final unavailableChannelIds = _backgroundService.getUnavailableChannelIds();

    if (unavailableChannelIds.isEmpty) return;

    // Move to unavailable category
    await context.read<ChannelProvider>().markChannelsAsUnavailable(unavailableChannelIds);

    // Clear results
    _backgroundService.clearResults();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved ${unavailableChannelIds.length} unavailable channels to unavailable category'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
