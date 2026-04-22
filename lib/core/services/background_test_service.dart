import 'dart:async';
import '../models/channel.dart';
import 'channel_test_service.dart';
import './service_locator.dart';

/// Background test status
enum BackgroundTestStatus {
  idle,
  running,
  completed,
  cancelled,
}

/// Background test progress callback
typedef BackgroundTestCallback = void Function(BackgroundTestProgress progress);

/// Background test progress
class BackgroundTestProgress {
  final int total;
  final int completed;
  final int available;
  final int unavailable;
  final String? currentChannelName;
  final BackgroundTestStatus status;
  final List<ChannelTestResult> results;

  BackgroundTestProgress({
    required this.total,
    required this.completed,
    required this.available,
    required this.unavailable,
    this.currentChannelName,
    required this.status,
    required this.results,
  });

  double get progress => total > 0 ? completed / total : 0;
  bool get isComplete => status == BackgroundTestStatus.completed;
  bool get isRunning => status == BackgroundTestStatus.running;
}

/// Background channel test service (Singleton)
class BackgroundTestService {
  static final BackgroundTestService _instance = BackgroundTestService._internal();
  factory BackgroundTestService() => _instance;
  BackgroundTestService._internal();

  final ChannelTestService _testService = ChannelTestService();
  StreamSubscription<ChannelTestProgress>? _subscription;

  BackgroundTestStatus _status = BackgroundTestStatus.idle;
  int _total = 0;
  int _completed = 0;
  int _available = 0;
  int _unavailable = 0;
  String? _currentChannelName;
  List<ChannelTestResult> _results = [];

  final List<BackgroundTestCallback> _listeners = [];

  // Getters
  BackgroundTestStatus get status => _status;
  bool get isRunning => _status == BackgroundTestStatus.running;
  bool get hasResults => _results.isNotEmpty;

  BackgroundTestProgress get currentProgress => BackgroundTestProgress(
        total: _total,
        completed: _completed,
        available: _available,
        unavailable: _unavailable,
        currentChannelName: _currentChannelName,
        status: _status,
        results: List.unmodifiable(_results),
      );

  /// Add listener
  void addListener(BackgroundTestCallback callback) {
    _listeners.add(callback);
  }

  /// Remove listener
  void removeListener(BackgroundTestCallback callback) {
    _listeners.remove(callback);
  }

  /// Notify all listeners
  void _notifyListeners() {
    final progress = currentProgress;
    for (final listener in _listeners) {
      listener(progress);
    }
  }

  /// Start background test
  void startTest(List<Channel> channels) {
    if (_status == BackgroundTestStatus.running) {
      ServiceLocator.log.d('Background test is already running');
      return;
    }

    _status = BackgroundTestStatus.running;
    _total = channels.length;
    _completed = 0;
    _available = 0;
    _unavailable = 0;
    _currentChannelName = null;
    _results = [];
    _notifyListeners();

    _subscription = _testService.testChannels(channels).listen(
      (progress) {
        _completed = progress.completed;
        _available = progress.available;
        _unavailable = progress.unavailable;
        _currentChannelName = progress.currentChannel.name;
        _results = progress.results;

        if (progress.isComplete) {
          _status = BackgroundTestStatus.completed;
        }

        _notifyListeners();
      },
      onError: (e) {
        ServiceLocator.log.d('Background test error: $e');
        _status = BackgroundTestStatus.completed;
        _notifyListeners();
      },
      onDone: () {
        _status = BackgroundTestStatus.completed;
        _notifyListeners();
      },
    );

    ServiceLocator.log.d('Background test started, total ${channels.length} channels');
  }

  /// Stop background test
  void stopTest() {
    _subscription?.cancel();
    _subscription = null;
    _status = BackgroundTestStatus.cancelled;
    _notifyListeners();
    ServiceLocator.log.d('Background test stopped');
  }

  /// Clear results
  void clearResults() {
    _status = BackgroundTestStatus.idle;
    _total = 0;
    _completed = 0;
    _available = 0;
    _unavailable = 0;
    _currentChannelName = null;
    _results = [];
    _notifyListeners();
  }

  /// Get invalid channel ID list
  List<int> getUnavailableChannelIds() {
    return _results.where((r) => !r.isAvailable).map((r) => r.channel.id).whereType<int>().toList();
  }
}
