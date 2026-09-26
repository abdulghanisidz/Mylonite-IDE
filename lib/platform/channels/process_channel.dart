import 'package:flutter/services.dart';

/// Dart side of the `ide/process` Platform Channel.
///
/// Wraps the MethodChannel and EventChannel that communicate with
/// [ProcessChannel.kt] in the Android layer.
///
/// Architecture: 02-ARCHITECTURE.md §11.1, 04-RUNTIME-SYSTEM.md §5
class ProcessChannel {
  ProcessChannel._();
  static final ProcessChannel instance = ProcessChannel._();

  static const _method = MethodChannel('ide/process');
  static const _event = EventChannel('ide/process/output');

  /// Spawn a child process.
  ///
  /// Returns a [ProcessHandle] containing sessionId and pid.
  /// Throws [PlatformException] on failure.
  Future<ProcessHandle> spawnProcess({
    required List<String> argv,
    required String workingDirectory,
    Map<String, String> environment = const {},
    String? stdinInput,
    int timeoutSeconds = 30,
  }) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'spawnProcess',
      {
        'argv': argv,
        'workingDirectory': workingDirectory,
        'environment': environment,
        if (stdinInput != null) 'stdinInput': stdinInput,
        'timeoutSeconds': timeoutSeconds,
      },
    );

    if (result == null) {
      throw PlatformException(
        code: 'SPAWN_FAILED',
        message: 'Process spawn returned null',
      );
    }

    return ProcessHandle(
      sessionId: result['sessionId'] as String,
      pid: result['pid'] as int,
    );
  }

  /// Terminate a running process by session ID.
  ///
  /// Sends SIGTERM, then SIGKILL if needed.
  /// Returns true if process was found and terminated.
  Future<bool> terminateProcess(String sessionId) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'terminateProcess',
      {'sessionId': sessionId},
    );
    return result?['success'] as bool? ?? false;
  }

  /// Write data to a running process's stdin.
  ///
  /// Returns true if data was written successfully.
  Future<bool> writeStdin(String sessionId, String data) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'writeStdin',
      {'sessionId': sessionId, 'data': data},
    );
    return result?['success'] as bool? ?? false;
  }

  /// Stream of output events from all active processes.
  ///
  /// Events are [ProcessOutputEvent] objects containing:
  /// - stdout/stderr: output chunks with content
  /// - exit: process termination with exit code, timeout, and OOM flags
  Stream<ProcessOutputEvent> get outputStream {
    return _event.receiveBroadcastStream().map((dynamic event) {
      final map = event as Map<dynamic, dynamic>;
      return ProcessOutputEvent.fromMap(map);
    });
  }
}

/// Handle returned when spawning a process.
class ProcessHandle {
  final String sessionId;
  final int pid;

  const ProcessHandle({required this.sessionId, required this.pid});

  @override
  String toString() => 'ProcessHandle(sessionId: $sessionId, pid: $pid)';
}

/// Event emitted by the process output stream.
class ProcessOutputEvent {
  final String sessionId;
  final ProcessOutputType type;
  final String? content;
  final int? exitCode;
  final bool timedOut;
  final bool oomKilled;

  const ProcessOutputEvent({
    required this.sessionId,
    required this.type,
    this.content,
    this.exitCode,
    this.timedOut = false,
    this.oomKilled = false,
  });

  factory ProcessOutputEvent.fromMap(Map<dynamic, dynamic> map) {
    final typeString = map['type'] as String;
    final type = ProcessOutputType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => ProcessOutputType.stdout,
    );

    return ProcessOutputEvent(
      sessionId: map['sessionId'] as String,
      type: type,
      content: map['content'] as String?,
      exitCode: map['exitCode'] as int?,
      timedOut: map['timedOut'] as bool? ?? false,
      oomKilled: map['oomKilled'] as bool? ?? false,
    );
  }

  bool get isOutput =>
      type == ProcessOutputType.stdout || type == ProcessOutputType.stderr;
  bool get isExit => type == ProcessOutputType.exit;

  @override
  String toString() {
    if (isExit) {
      return 'ProcessOutputEvent(sessionId: $sessionId, type: $type, '
          'exitCode: $exitCode, timedOut: $timedOut, oomKilled: $oomKilled)';
    }
    return 'ProcessOutputEvent(sessionId: $sessionId, type: $type, '
        'content: ${content?.substring(0, content!.length.clamp(0, 50))}...)';
  }
}

/// Type of process output event.
enum ProcessOutputType { stdout, stderr, exit }
