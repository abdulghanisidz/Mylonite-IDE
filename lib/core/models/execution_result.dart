import 'diagnostic.dart';

/// ExecutionResult — Contains the result of a code execution.
///
/// Captures:
/// - Exit code
/// - stdout/stderr output
/// - Execution timing
/// - Timeout/OOM status
/// - Parsed diagnostics (errors, warnings)
///
/// Used by PythonRuntime and future JavaScript runtime.
/// Architecture: 04-RUNTIME-SYSTEM.md §4
class ExecutionResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration executionTime;
  final bool timedOut;
  final bool oomKilled;
  final List<Diagnostic> diagnostics;

  const ExecutionResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.executionTime,
    this.timedOut = false,
    this.oomKilled = false,
    this.diagnostics = const [],
  });

  /// Whether the execution succeeded (exit code 0).
  bool get isSuccess => exitCode == 0 && !timedOut && !oomKilled;

  /// Whether the execution failed.
  bool get isFailure => !isSuccess;

  /// Whether there are any errors.
  bool get hasErrors =>
      diagnostics.any((d) => d.severity == DiagnosticSeverity.error);

  /// Whether there are any warnings.
  bool get hasWarnings =>
      diagnostics.any((d) => d.severity == DiagnosticSeverity.warning);

  /// Get all errors.
  List<Diagnostic> get errors =>
      diagnostics.where((d) => d.severity == DiagnosticSeverity.error).toList();

  /// Get all warnings.
  List<Diagnostic> get warnings => diagnostics
      .where((d) => d.severity == DiagnosticSeverity.warning)
      .toList();

  /// Get a human-readable status message.
  String get statusMessage {
    if (timedOut) return 'Execution timed out';
    if (oomKilled) return 'Process killed (out of memory)';
    if (exitCode == 0) return 'Success';
    return 'Failed with exit code $exitCode';
  }

  /// Create a copy with updated diagnostics.
  ExecutionResult withDiagnostics(List<Diagnostic> diagnostics) {
    return ExecutionResult(
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
      executionTime: executionTime,
      timedOut: timedOut,
      oomKilled: oomKilled,
      diagnostics: diagnostics,
    );
  }

  Map<String, dynamic> toJson() => {
    'exitCode': exitCode,
    'stdout': stdout,
    'stderr': stderr,
    'executionTime': executionTime.inMilliseconds,
    'timedOut': timedOut,
    'oomKilled': oomKilled,
    'diagnostics': diagnostics.map((d) => d.toJson()).toList(),
  };

  factory ExecutionResult.fromJson(Map<String, dynamic> json) =>
      ExecutionResult(
        exitCode: json['exitCode'] as int,
        stdout: json['stdout'] as String,
        stderr: json['stderr'] as String,
        executionTime: Duration(milliseconds: json['executionTime'] as int),
        timedOut: json['timedOut'] as bool? ?? false,
        oomKilled: json['oomKilled'] as bool? ?? false,
        diagnostics:
            (json['diagnostics'] as List<dynamic>?)
                ?.map((d) => Diagnostic.fromJson(d as Map<String, dynamic>))
                .toList() ??
            [],
      );

  @override
  String toString() {
    return 'ExecutionResult(exitCode: $exitCode, executionTime: ${executionTime.inMilliseconds}ms, '
        'timedOut: $timedOut, oomKilled: $oomKilled, diagnostics: ${diagnostics.length})';
  }
}
