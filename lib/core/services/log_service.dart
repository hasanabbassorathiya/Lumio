import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service_locator.dart';

/// Log level
enum LogLevel {
  debug,    // Debug mode: record all logs
  release,  // Release mode: only record warnings and errors
  off,      // Turn off logs
}

/// Log Service - Unified management of application logs
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  Logger? _logger;
  LogLevel _currentLevel = LogLevel.release;
  String? _logFilePath;
  bool _initialized = false;
  
  // Batch write buffer
  final List<String> _logBuffer = [];
  static const int _bufferSize = 10; // Buffer size (reduced to 10 for faster writing)
  DateTime? _lastFlushTime; // Last flush time
  static const Duration _autoFlushInterval = Duration(seconds: 2); // Auto-flush interval (reduced to 2 seconds)

  /// Initialize log service
  Future<void> init({SharedPreferences? prefs}) async {
    if (_initialized) return;

    try {
      // Read Log level from settings
      final preferences = prefs ?? ServiceLocator.prefs;

      String levelString = preferences.getString('log_level') ?? 'off';
      debugPrint('LogService: Reading Log level from SharedPreferences: $levelString');

      _currentLevel = _parseLogLevel(levelString);
      debugPrint('LogService: Parsed Log level: ${_currentLevel.name}');

      if (_currentLevel == LogLevel.off) {
        debugPrint('LogService: Logs are disabled');
        _initialized = true;
        return;
      }

      // Get log file path
      _logFilePath = await _getLogFilePath();
      
      if (_logFilePath != null) {
        // Create log file reference
        _file = File(_logFilePath!);
        
        // Create log directory
        final logDir = Directory(path.dirname(_logFilePath!));
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }

        // Clean up old logs (keep recent 7 days)
        await _cleanOldLogs(logDir);

        // Create Logger instance (using batch output)
        // Note: Logger level set to all, controlled by our Filter
        _logger = Logger(
          filter: _LogFilter(_currentLevel),
          printer: _LogPrinter(),
          output: _BatchFileOutput(this),
          level: Level.all, // Allow all levels, controlled by Filter
        );

        debugPrint('LogService: Initialization successful, log file: $_logFilePath');
        debugPrint('LogService: Log level: ${_currentLevel.name}');
        
        // Write startup log
        _logger?.i('========================================');
        _logger?.i('App started - ${DateTime.now()}');
        _logger?.i('Log level: ${_currentLevel.name}');
        _logger?.i('========================================');
        
        // Immediately flush startup logs
        await flush();
      }

      _initialized = true;
    } catch (e) {
      debugPrint('LogService: Initialization failed - $e');
    }
  }

  /// Get log file path
  Future<String?> _getLogFilePath() async {
    try {
      Directory? logDir;

      if (Platform.isWindows) {
        // Windows: use logs folder in app installation directory
        final exePath = Platform.resolvedExecutable;
        final exeDir = path.dirname(exePath);
        logDir = Directory(path.join(exeDir, 'logs'));
      } else if (Platform.isAndroid) {
        // Android: use app external storage directory
        final appDir = await getExternalStorageDirectory();
        if (appDir != null) {
          logDir = Directory(path.join(appDir.path, 'logs'));
        }
      } else {
        // Other platforms: use app documents directory
        final appDir = await getApplicationDocumentsDirectory();
        logDir = Directory(path.join(appDir.path, 'logs'));
      }

      if (logDir == null) return null;

      // Create log directory
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // Log file name: lotus_iptv_YYYYMMDD.log
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      return path.join(logDir.path, 'lotus_iptv_$dateStr.log');
    } catch (e) {
      debugPrint('LogService: Failed to get log path - $e');
      return null;
    }
  }

  /// Clean up old logs (keep recent 7 days)
  Future<void> _cleanOldLogs(Directory logDir) async {
    try {
      final now = DateTime.now();
      final files = await logDir.list().toList();

      for (final file in files) {
        if (file is File && file.path.endsWith('.log')) {
          final stat = await file.stat();
          final age = now.difference(stat.modified).inDays;

          if (age > 7) {
            await file.delete();
            debugPrint('LogService: Deleting old log - ${path.basename(file.path)}');
          }
        }
      }
    } catch (e) {
      debugPrint('LogService: Failed to clean old logs - $e');
    }
  }

  /// Parse Log level
  LogLevel _parseLogLevel(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return LogLevel.debug;
      case 'release':
        return LogLevel.release;
      case 'off':
        return LogLevel.off;
      default:
        return LogLevel.release;
    }
  }

  /// Set Log level
  Future<void> setLogLevel(LogLevel level) async {
    debugPrint('LogService: Setting Log level to ${level.name}');

    // Flush current buffer first
    await flush();

    _currentLevel = level;

    // Save to settings
    try {
      final prefs = ServiceLocator.prefs;
      await prefs.setString('log_level', level.name);
      debugPrint('LogService: Log level saved to SharedPreferences');
    } catch (e) {
      debugPrint('LogService: Failed to save Log level - $e');
    }

    // Re-initializing
    _initialized = false;
    _logger = null;
    _file = null;
    debugPrint('LogService: Starting Re-initializing...');
    await init();
    debugPrint('LogService: Re-initializing complete, _logger = $_logger, _file = $_file');
  }

  /// Get current Log level
  LogLevel get currentLevel => _currentLevel;

  /// Get log file path
  String? get logFilePath => _logFilePath;

  /// Debug log
  void d(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    if (_currentLevel == LogLevel.off) return; // Only skip if set to off
    if (_currentLevel != LogLevel.debug) return; // Only log debug messages at debug level
    
    if (_logger == null) {
      debugPrint('LogService: Logger not initialized, cannot write log');
      return;
    }
    
    final msg = tag != null ? '[$tag] $message' : message;
    _logger?.d(msg, error: error, stackTrace: stackTrace);
    // In debug mode, only output to console when not batch importing
    // if (kDebugMode) debugPrint('DEBUG: $msg');
  }

  /// Info log
  void i(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    if (_currentLevel == LogLevel.off) return;
    
    if (_logger == null) {
      debugPrint('LogService: Logger not initialized (Info)');
      return;
    }
    
    final msg = tag != null ? '[$tag] $message' : message;
    _logger?.i(msg, error: error, stackTrace: stackTrace);
    if (kDebugMode) debugPrint('INFO: $msg');
  }

  /// Warning log
  void w(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    if (_currentLevel == LogLevel.off) return;
    final msg = tag != null ? '[$tag] $message' : message;
    _logger?.w(msg, error: error, stackTrace: stackTrace);
    if (kDebugMode) debugPrint('WARN: $msg');
  }

  /// Error log
  void e(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    if (_currentLevel == LogLevel.off) return;
    final msg = tag != null ? '[$tag] $message' : message;
    _logger?.e(msg, error: error, stackTrace: stackTrace);
    if (kDebugMode) debugPrint('ERROR: $msg');
  }
  
  /// Flush log buffer (force write all cached logs)
  Future<void> flush() async {
    if (_logBuffer.isEmpty) return;
    
    try {
      if (_file != null) {
        await _file!.writeAsString(
          _logBuffer.join('\n') + '\n',
          mode: FileMode.append,
          flush: true,
        );
        _logBuffer.clear();
        _lastFlushTime = DateTime.now();
      }
    } catch (e) {
      debugPrint('LogService: Failed to flush log buffer - $e');
    }
  }
  
  /// Check if auto-flush is needed
  void _checkAutoFlush() {
    if (_lastFlushTime == null) {
      _lastFlushTime = DateTime.now();
      return;
    }
    
    final now = DateTime.now();
    if (now.difference(_lastFlushTime!) >= _autoFlushInterval) {
      flush();
    }
  }
  
  File? _file;

  /// Get log directory
  Future<Directory?> getLogDirectory() async {
    if (_logFilePath == null) return null;
    return Directory(path.dirname(_logFilePath!));
  }

  /// Get all log files
  Future<List<File>> getLogFiles() async {
    final logDir = await getLogDirectory();
    if (logDir == null || !await logDir.exists()) return [];

    final files = await logDir.list().toList();
    return files
        .whereType<File>()
        .where((f) => f.path.endsWith('.log'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // Reverse chronological order
  }

  /// Export log file (for developer sharing)
  Future<String?> exportLogs() async {
    try {
      final logFiles = await getLogFiles();
      if (logFiles.isEmpty) return null;

      // Merge all log files
      final buffer = StringBuffer();
      buffer.writeln('========================================');
      buffer.writeln('Lotus IPTV Log Export');
      buffer.writeln('Export time: ${DateTime.now()}');
      buffer.writeln('========================================\n');

      for (final file in logFiles) {
        buffer.writeln('\n========== ${path.basename(file.path)} ==========\n');
        final content = await file.readAsString();
        buffer.writeln(content);
      }

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final exportFile = File(path.join(
        tempDir.path,
        'lotus_iptv_logs_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.txt',
      ));
      await exportFile.writeAsString(buffer.toString());

      return exportFile.path;
    } catch (e) {
      debugPrint('LogService: Failed to export logs - $e');
      return null;
    }
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    try {
      final logDir = await getLogDirectory();
      if (logDir == null || !await logDir.exists()) return;

      final files = await logDir.list().toList();
      for (final file in files) {
        if (file is File && file.path.endsWith('.log')) {
          await file.delete();
        }
      }

      debugPrint('LogService: All logs cleared');

      // Re-initializing to create new log file
      _initialized = false;
      await init();
    } catch (e) {
      debugPrint('LogService: Failed to clear logs - $e');
    }
  }
}

/// Custom log filter
class _LogFilter extends LogFilter {
  final LogLevel logLevel;

  _LogFilter(this.logLevel);

  @override
  bool shouldLog(LogEvent event) {
    if (logLevel == LogLevel.off) return false;
    if (logLevel == LogLevel.debug) return true; // Record all in debug mode
    // Record info, warning, and error in release mode
    return event.level.index >= Level.info.index;
  }
}

/// Custom log printer
class _LogPrinter extends LogPrinter {
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  @override
  List<String> log(LogEvent event) {
    final time = _dateFormat.format(event.time);
    final level = event.level.name.toUpperCase().padRight(7);
    final message = event.message;
    
    final buffer = StringBuffer();
    buffer.write('$time [$level] $message');

    if (event.error != null) {
      buffer.write('\nError: ${event.error}');
    }

    if (event.stackTrace != null) {
      buffer.write('\nStackTrace:\n${event.stackTrace}');
    }

    return [buffer.toString()];
  }
}

/// Batch file output (performance optimized)
class _BatchFileOutput extends LogOutput {
  final LogService logService;

  _BatchFileOutput(this.logService);

  @override
  void output(OutputEvent event) {
    if (logService._file == null) return;

    try {
      for (final line in event.lines) {
        logService._logBuffer.add(line);
      }

      // Check if auto-flush is needed (based on time)
      logService._checkAutoFlush();

      // Batch write when buffer reaches limit
      if (logService._logBuffer.length >= LogService._bufferSize) {
        logService._file!.writeAsStringSync(
          logService._logBuffer.join('\n') + '\n',
          mode: FileMode.append,
          flush: false, // Do not flush immediately to improve performance
        );
        logService._logBuffer.clear();
        logService._lastFlushTime = DateTime.now();
      }
    } catch (e) {
      debugPrint('LogService: Failed to write log - $e');
    }
  }
}
