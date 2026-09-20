import 'enums.dart';

/// Typed error returned by all subsystem operations.
///
/// No subsystem throws unhandled exceptions to the UI layer.
/// Every fallible operation returns `Result<T>` where failure carries AppError.
///
/// Architecture: 02-ARCHITECTURE.md §13.2
class AppError {
  const AppError({
    required this.code,
    required this.message,
    required this.subsystem,
    this.detail,
    this.originalException,
  });

  /// Machine-readable error code (e.g. 'PATH_TRAVERSAL', 'FILE_NOT_FOUND').
  final String code;

  /// User-visible, human-readable description.
  final String message;

  /// Which subsystem produced this error.
  final LogSubsystem subsystem;

  /// Technical detail for logging — never shown to the user in production.
  final String? detail;

  /// The original exception if one was caught.
  final Object? originalException;

  // ── Named constructors for common errors ────────────────────────────────

  factory AppError.fileNotFound(String path) => AppError(
    code: 'FILE_NOT_FOUND',
    message: 'File not found: $path',
    subsystem: LogSubsystem.filesystem,
  );

  factory AppError.pathTraversal(String path) => AppError(
    code: 'PATH_TRAVERSAL',
    message: 'Access denied: path is outside the project workspace.',
    subsystem: LogSubsystem.security,
    detail: 'Attempted path: $path',
  );

  factory AppError.permissionDenied(String detail) => AppError(
    code: 'PERMISSION_DENIED',
    message: 'Permission denied.',
    subsystem: LogSubsystem.filesystem,
    detail: detail,
  );

  factory AppError.runtimeNotInstalled(String runtimeId) => AppError(
    code: 'RUNTIME_NOT_INSTALLED',
    message:
        'Runtime "$runtimeId" is not installed. Open Runtime Manager to install it.',
    subsystem: LogSubsystem.runtime,
  );

  factory AppError.runtimeBusy(String runtimeId) => AppError(
    code: 'RUNTIME_BUSY',
    message: 'A process is already running. Stop it before starting a new one.',
    subsystem: LogSubsystem.runtime,
  );

  factory AppError.modelNotLoaded() => AppError(
    code: 'MODEL_NOT_LOADED',
    message: 'No AI model is loaded. Open Model Manager to activate a model.',
    subsystem: LogSubsystem.ai,
  );

  factory AppError.insufficientMemory({
    required int requiredMb,
    required int availableMb,
  }) => AppError(
    code: 'INSUFFICIENT_MEMORY',
    message:
        'Not enough RAM to load this model. '
        'Required: ~${requiredMb}MB, available: ~${availableMb}MB. '
        'Close other apps or choose a smaller model.',
    subsystem: LogSubsystem.ai,
  );

  factory AppError.toolNotFound(String toolName) => AppError(
    code: 'TOOL_NOT_FOUND',
    message: 'Unknown tool: "$toolName".',
    subsystem: LogSubsystem.agent,
  );

  factory AppError.toolNotPermitted(String toolName) => AppError(
    code: 'TOOL_NOT_PERMITTED',
    message: 'Tool "$toolName" is not available in the current configuration.',
    subsystem: LogSubsystem.agent,
  );

  factory AppError.storageFull() => AppError(
    code: 'STORAGE_FULL',
    message: 'Not enough storage space to complete this operation.',
    subsystem: LogSubsystem.filesystem,
  );

  factory AppError.unknown(Object e, LogSubsystem subsystem) => AppError(
    code: 'UNKNOWN',
    message: 'An unexpected error occurred.',
    subsystem: subsystem,
    detail: e.toString(),
    originalException: e,
  );

  @override
  String toString() =>
      'AppError[$subsystem/$code]: $message'
      '${detail != null ? ' — $detail' : ''}';
}

/// A Result type that carries either a success value or an [AppError].
///
/// Usage:
///   final result = await workspaceManager.readFile('main.py');
///   result.when(
///     ok:  (content) => doSomething(content),
///     err: (error)   => showError(error.message),
///   );
sealed class Result<T> {
  const Result();

  static Result<T> ok<T>(T value) => Ok(value);
  static Result<T> err<T>(AppError error) => Err(error);

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get valueOrNull => isOk ? (this as Ok<T>).value : null;
  AppError? get errorOrNull => isErr ? (this as Err<T>).error : null;

  R when<R>({
    required R Function(T value) ok,
    required R Function(AppError error) err,
  }) => switch (this) {
    Ok<T> v => ok(v.value),
    Err<T> e => err(e.error),
  };
}

/// Successful result carrying a value.
final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

/// Failed result carrying an [AppError].
final class Err<T> extends Result<T> {
  const Err(this.error);
  final AppError error;
}
