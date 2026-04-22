import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/channel.dart';
import './service_locator.dart';

/// Channel test result
class ChannelTestResult {
  final Channel channel;
  final bool isAvailable;
  final int? responseTime; // Response time (ms)
  final String? error;
  final int availableSources; // Available sources count
  final int totalSources; // Total sources count
  final List<SourceTestResult> sourceResults; // Test result for each source

  ChannelTestResult({
    required this.channel,
    required this.isAvailable,
    this.responseTime,
    this.error,
    this.availableSources = 1,
    this.totalSources = 1,
    this.sourceResults = const [],
  });
}

/// Test result for single source
class SourceTestResult {
  final String url;
  final bool isAvailable;
  final int? responseTime;
  final String? error;

  SourceTestResult({
    required this.url,
    required this.isAvailable,
    this.responseTime,
    this.error,
  });
}

/// Channel test service
class ChannelTestService {
  static const int _timeout = 3; // Timeout (seconds)
  static const int _maxConcurrent = 5; // Max concurrent tests

  /// Test single channel (test all sources)
  Future<ChannelTestResult> testChannel(Channel channel) async {
    final sources = channel.sources;
    
    // If only one source, use simple test
    if (sources.length <= 1) {
      return _testSingleUrl(channel, channel.url);
    }
    
    // Test all sources
    final sourceResults = <SourceTestResult>[];
    int availableCount = 0;
    int? bestResponseTime;
    
    for (final sourceUrl in sources) {
      final result = await _testUrl(sourceUrl);
      sourceResults.add(result);
      
      if (result.isAvailable) {
        availableCount++;
        if (bestResponseTime == null || (result.responseTime ?? 0) < bestResponseTime) {
          bestResponseTime = result.responseTime;
        }
      }
    }
    
    // Channel available = at least one source is available
    final isAvailable = availableCount > 0;
    
    return ChannelTestResult(
      channel: channel,
      isAvailable: isAvailable,
      responseTime: bestResponseTime,
      error: isAvailable ? null : 'All ${sources.length} sources are unavailable',
      availableSources: availableCount,
      totalSources: sources.length,
      sourceResults: sourceResults,
    );
  }

  /// Test single URL
  Future<SourceTestResult> _testUrl(String url) async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = Uri.parse(url);

      // Select test method based on protocol
      if (uri.scheme == 'rtmp' || uri.scheme == 'rtsp') {
        return await _testSocketUrl(url, uri, stopwatch);
      }

      return await _testHttpUrl(url, uri, stopwatch);
    } on TimeoutException {
      stopwatch.stop();
      return SourceTestResult(
        url: url,
        isAvailable: false,
        responseTime: stopwatch.elapsedMilliseconds,
        error: 'Connection timeout',
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return SourceTestResult(
        url: url,
        isAvailable: false,
        responseTime: stopwatch.elapsedMilliseconds,
        error: 'Network error: ${e.message}',
      );
    } catch (e) {
      stopwatch.stop();
      return SourceTestResult(
        url: url,
        isAvailable: false,
        responseTime: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  /// Test single channel (single source, legacy compatibility)
  Future<ChannelTestResult> _testSingleUrl(Channel channel, String url) async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = Uri.parse(url);

      // Select test method based on protocol
      if (uri.scheme == 'rtmp' || uri.scheme == 'rtsp') {
        return await _testSocketConnection(channel, uri, stopwatch);
      }

      return await _testHttpStream(channel, uri, stopwatch);
    } on TimeoutException {
      stopwatch.stop();
      return ChannelTestResult(
        channel: channel,
        isAvailable: false,
        responseTime: stopwatch.elapsedMilliseconds,
        error: 'Connection timeout',
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return ChannelTestResult(
        channel: channel,
        isAvailable: false,
        responseTime: stopwatch.elapsedMilliseconds,
        error: 'Network error: ${e.message}',
      );
    } catch (e) {
      stopwatch.stop();
      return ChannelTestResult(
        channel: channel,
        isAvailable: false,
        responseTime: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  /// Test HTTP/HTTPS stream
  Future<ChannelTestResult> _testHttpStream(
    Channel channel,
    Uri uri,
    Stopwatch stopwatch,
  ) async {
    HttpClient? client;
    HttpClientRequest? request;
    HttpClientResponse? response;

    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: _timeout);

      // Use GET request
      request = await client.getUrl(uri).timeout(
            const Duration(seconds: _timeout),
          );

      // Set common streaming request headers
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      request.headers.set('Accept', '*/*');
      request.headers.set('Connection', 'keep-alive');

      response = await request.close().timeout(
            const Duration(seconds: _timeout),
          );

      stopwatch.stop();

      // Check response status
      final statusCode = response.statusCode;
      final isAvailable = statusCode >= 200 && statusCode < 400;

      final contentType = response.headers.contentType?.toString() ?? '';
      ServiceLocator.log.d('Testing channel ${channel.name}: HTTP $statusCode, Content-Type: $contentType');

      return ChannelTestResult(
        channel: channel,
        isAvailable: isAvailable,
        responseTime: stopwatch.elapsedMilliseconds,
        error: isAvailable ? null : 'HTTP $statusCode',
      );
    } finally {
      try {
        response?.detachSocket().then((socket) => socket.destroy());
      } catch (_) {}
      client?.close(force: true);
    }
  }

  /// Test HTTP/HTTPS URL (returns SourceTestResult)
  Future<SourceTestResult> _testHttpUrl(
    String url,
    Uri uri,
    Stopwatch stopwatch,
  ) async {
    HttpClient? client;
    HttpClientRequest? request;
    HttpClientResponse? response;

    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: _timeout);

      request = await client.getUrl(uri).timeout(
            const Duration(seconds: _timeout),
          );

      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      request.headers.set('Accept', '*/*');
      request.headers.set('Connection', 'keep-alive');

      response = await request.close().timeout(
            const Duration(seconds: _timeout),
          );

      stopwatch.stop();

      final statusCode = response.statusCode;
      final isAvailable = statusCode >= 200 && statusCode < 400;

      return SourceTestResult(
        url: url,
        isAvailable: isAvailable,
        responseTime: stopwatch.elapsedMilliseconds,
        error: isAvailable ? null : 'HTTP $statusCode',
      );
    } finally {
      try {
        response?.detachSocket().then((socket) => socket.destroy());
      } catch (_) {}
      client?.close(force: true);
    }
  }

  /// Test Socket connection (for RTMP/RTSP)
  Future<ChannelTestResult> _testSocketConnection(
    Channel channel,
    Uri uri,
    Stopwatch stopwatch,
  ) async {
    Socket? socket;

    try {
      final host = uri.host;
      final port = uri.port != 0 ? uri.port : (uri.scheme == 'rtmp' ? 1935 : 554);

      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: _timeout),
      );

      stopwatch.stop();

      return ChannelTestResult(
        channel: channel,
        isAvailable: true,
        responseTime: stopwatch.elapsedMilliseconds,
      );
    } finally {
      socket?.destroy();
    }
  }

  /// Test Socket URL (returns SourceTestResult)
  Future<SourceTestResult> _testSocketUrl(
    String url,
    Uri uri,
    Stopwatch stopwatch,
  ) async {
    Socket? socket;

    try {
      final host = uri.host;
      final port = uri.port != 0 ? uri.port : (uri.scheme == 'rtmp' ? 1935 : 554);

      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: _timeout),
      );

      stopwatch.stop();

      return SourceTestResult(
        url: url,
        isAvailable: true,
        responseTime: stopwatch.elapsedMilliseconds,
      );
    } finally {
      socket?.destroy();
    }
  }

  /// Batch test channels
  Stream<ChannelTestProgress> testChannels(List<Channel> channels) async* {
    if (channels.isEmpty) return;

    final total = channels.length;
    var completed = 0;
    var available = 0;
    var unavailable = 0;
    final results = <ChannelTestResult>[];

    // Process in batches
    for (var i = 0; i < channels.length; i += _maxConcurrent) {
      final batch = channels.skip(i).take(_maxConcurrent).toList();

      final futures = batch.map((channel) => testChannel(channel));
      final batchResults = await Future.wait(futures);

      for (final result in batchResults) {
        completed++;
        results.add(result);

        if (result.isAvailable) {
          available++;
        } else {
          unavailable++;
        }

        yield ChannelTestProgress(
          total: total,
          completed: completed,
          available: available,
          unavailable: unavailable,
          currentChannel: result.channel,
          currentResult: result,
          results: List.unmodifiable(results),
        );
      }
    }
  }
}

/// Channel test progress
class ChannelTestProgress {
  final int total;
  final int completed;
  final int available;
  final int unavailable;
  final Channel currentChannel;
  final ChannelTestResult currentResult;
  final List<ChannelTestResult> results;

  ChannelTestProgress({
    required this.total,
    required this.completed,
    required this.available,
    required this.unavailable,
    required this.currentChannel,
    required this.currentResult,
    required this.results,
  });

  double get progress => total > 0 ? completed / total : 0;
  bool get isComplete => completed >= total;
}
