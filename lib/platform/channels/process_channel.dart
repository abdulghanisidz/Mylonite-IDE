import 'package:flutter/services.dart';

/// Dart side of the `ide/process` Platform Channel.
///
/// Wraps the MethodChannel and EventChannel that communicate with
/// [ProcessChannel.kt] in the Android layer.
///
/// Architecture: 02-ARCHITECTURE.md §11.1, 04-RUNTIME-SYSTEM.md §5
///
/// All methods return [NotImplementedError] until Phase 4 implements
/// the Kotlin side. The Dart API shape is defined here so that dependent
/// code (RuntimeManager, agent tools) can be written against it now.
class ProcessChannel {
  ProcessChannel._();
  static final ProcessChannel instance = ProcessChannel._();

  static const _method = MethodChannel('ide/process');
  static const _event = EventChannel('ide/process/output');

  /// Spawn a child process.
  ///
  /// Returns a map containing `{ pid, sessionId }`.
  /// Throws [PlatformException] on failure.
  ///
  /// TODO (Phase 4): implement in Kotlin.
  Future<Map<String, dynamic>> spawnProcess({
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
    return result ?? {};
  }

  /// Kill a running process by session ID.
  Future<bool> terminateProcess(String sessionId) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'terminateProcess',
      {'sessionId': sessionId},
    );
    return result?['success'] as bool? ?? false;
  }

  /// Write data to a running process's stdin.
  Future<bool> writeStdin(String sessionId, String data) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'writeStdin',
      {'sessionId': sessionId, 'data': data},
    );
    return result?['success'] as bool? ?? false;
  }

  /// Stream of output chunks from all active processes.
  ///
  /// Each event is a map: `{ sessionId, type, content, exitCode? }`
  /// where [type] is `"stdout"`, `"stderr"`, or `"exit"`.
  Stream<Map<dynamic, dynamic>> get outputStream {
    return _event.receiveBroadcastStream().cast<Map<dynamic, dynamic>>();
  }
}
