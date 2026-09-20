import 'dart:collection';

import '../constants/app_constants.dart';
import '../models/enums.dart';

/// A structured log entry.
///
/// Architecture: 02-ARCHITECTURE.md §LoggingService, NFR-009, NFR-010
class LogEntry {
  const LogEntry({
    required this.level,
    required this.subsystem,
    required this.message,
    required this.timestamp,
    this.detail,
  });

  final LogLevel level;
  final LogSubsystem subsystem;

  /// User/operator-visible message. Must NEVER contain source code,
  /// conversation content, or credentials at INFO level and above.
  final String message;

  final DateTime timestamp;

  /// Technical detail — only included in DEBUG/VERBOSE builds.
  final String? detail;

  @override
  String toString() {
    final ts = timestamp.toIso8601String();
    final sub = subsystem.name.toUpperCase().padRight(10);
    final lvl = level.name.toUpperCase().padRight(7);
    final base = '[$ts] $lvl $sub $message';
    return detail != null ? '$base\n  → $detail' : base;
  }
}

/// Centralised structured logging service.
///
/// - Keeps an in-memory ring buffer of the last [kLogRingBufferSize] entries.
/// - Optionally writes to a file in DEBUG mode (controlled by [persistToFile]).
/// - Filters output by [minimumLevel] — entries below this level are discarded.
/// - NEVER logs source code content, conversation payloads, or secrets.
///
/// Architecture: 02-ARCHITECTURE.md §LoggingService, 06-SECURITY.md §18
class LoggingService {
  LoggingService._();

  static final LoggingService instance = LoggingService._();

  /// Minimum level for entries to be recorded. Defaults to INFO.
  LogLevel minimumLevel = LogLevel.info;

  /// Whether to write entries to a file (debug builds only).
  bool persistToFile = false;

  final Queue<LogEntry> _buffer = Queue();

  /// Read-only view of the in-memory log buffer.
  List<LogEntry> get entries => List.unmodifiable(_buffer);

  // ── Logging methods ──────────────────────────────────────────────────────

  void verbose(LogSubsystem sub, String msg, {String? detail}) =>
      _log(LogLevel.verbose, sub, msg, detail: detail);

  void debug(LogSubsystem sub, String msg, {String? detail}) =>
      _log(LogLevel.debug, sub, msg, detail: detail);

  void info(LogSubsystem sub, String msg) =>
      _log(LogLevel.info, sub, msg);

  void warn(LogSubsystem sub, String msg, {String? detail}) =>
      _log(LogLevel.warn, sub, msg, detail: detail);

  void error(LogSubsystem sub, String msg, {String? detail, Object? exception}) =>
      _log(LogLevel.error, sub, msg, detail: detail ?? exception?.toString());

  // ── Internal ─────────────────────────────────────────────────────────────

  void _log(LogLevel level, LogSubsystem sub, String msg, {String? detail}) {
    if (level.index < minimumLevel.index) return;

    final entry = LogEntry(
      level: level,
      subsystem: sub,
      message: msg,
      timestamp: DateTime.now(),
      // Only include detail at DEBUG level and below
      detail: level >= LogLevel.info ? null : detail,
    );

    _buffer.addLast(entry);
    while (_buffer.length > kLogRingBufferSize) {
      _buffer.removeFirst();
    }

    // Print to console in debug builds
    assert(() {
      // ignore: avoid_print
      print(entry.toString());
      return true;
    }());

    // TODO (Phase 1): Write to file when persistToFile is true
  }

  /// Clears the in-memory buffer. Used in tests.
  void clearBuffer() => _buffer.clear();
}

/// Convenience shorthand for the global logger instance.
final log = LoggingService.instance;
