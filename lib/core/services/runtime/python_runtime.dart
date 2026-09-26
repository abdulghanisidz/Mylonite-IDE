import 'dart:async';

import '../../models/enums.dart';
import '../../models/execution_result.dart';
import '../logging_service.dart';
import '../../../platform/channels/process_channel.dart';
import 'python_diagnostics_parser.dart';
import 'python_installer.dart';

/// PythonRuntime — Manages Python code execution on Android.
///
/// This service wraps ProcessChannel and provides Python-specific functionality:
/// - Environment variable configuration (PYTHONHOME, PYTHONPATH, etc.)
/// - Health checks (python3 --version)
/// - Traceback parsing
/// - Virtual environment support (future)
///
/// Architecture: 04-RUNTIME-SYSTEM.md §3, 08-ROADMAP.md Phase 5
///
/// The Python binary is expected to be:
/// 1. Pre-installed on the device (e.g., Termux)
/// 2. Bundled in app assets and extracted on first run
/// 3. Downloaded from a CDN on first use
///
/// This implementation starts with option 1 (system Python) for rapid prototyping,
/// then moves to option 2 (bundled binary) for production.
class PythonRuntime {
  PythonRuntime._();
  static final PythonRuntime instance = PythonRuntime._();

  final _processChannel = ProcessChannel.instance;
  final _installer = PythonInstaller.instance;

  // Python configuration
  String _pythonExecutable = 'python3'; // Default, will be updated by detection

  // Runtime state
  bool _isInstalled = false;
  String? _version;
  String? _pythonPath;

  // Active executions
  final Map<String, StreamController<String>> _outputControllers = {};
  final Map<String, Completer<ExecutionResult>> _executionCompleters = {};
  final Map<String, StringBuffer> _stdoutBuffers = {};
  final Map<String, StringBuffer> _stderrBuffers = {};
  final Map<String, DateTime> _startTimes = {};
  final Map<String, String?> _filePaths = {};

  StreamSubscription<ProcessOutputEvent>? _outputSubscription;

  /// Initialize the Python runtime.
  ///
  /// Performs:
  /// 1. Health check (python3 --version)
  /// 2. Path detection
  /// 3. Environment validation
  Future<void> initialize() async {
    log.info(LogSubsystem.runtime, 'Initializing Python runtime...');

    // Start listening to process output
    _startOutputListener();

    // Perform health check
    await _healthCheck();
  }

  /// Check if Python is installed and accessible.
  Future<void> _healthCheck() async {
    try {
      log.debug(LogSubsystem.runtime, 'Running Python detection...');

      // Use the installer to detect Python
      final info = await _installer.detect();

      if (info.available && info.executable != null) {
        _isInstalled = true;
        _pythonExecutable = info.executable!;
        _pythonPath = info.executable;
        _version = info.version ?? 'Unknown';

        log.info(
          LogSubsystem.runtime,
          'Python detected: ${info.version} from ${info.source}',
        );
        log.info(LogSubsystem.runtime, 'Using executable: $_pythonExecutable');
      } else {
        _isInstalled = false;
        log.warn(
          LogSubsystem.runtime,
          'Python not found. User needs to install Termux or wait for bundled Python.',
        );
        log.info(
          LogSubsystem.runtime,
          'Installation instructions:\n${_installer.getInstallationInstructions()}',
        );
      }
    } catch (e) {
      _isInstalled = false;
      log.error(LogSubsystem.runtime, 'Python detection failed: $e');
    }
  }

  /// Execute Python code.
  ///
  /// Returns an [ExecutionResult] containing stdout, stderr, exit code,
  /// execution time, and parsed diagnostics.
  Future<ExecutionResult> executeCode({
    required String code,
    required String workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final startTime = DateTime.now();

    log.info(
      LogSubsystem.runtime,
      '[$sessionId] Executing Python code (${code.length} bytes)',
    );

    // Initialize buffers and controllers
    _outputControllers[sessionId] = StreamController<String>.broadcast();
    _executionCompleters[sessionId] = Completer<ExecutionResult>();
    _stdoutBuffers[sessionId] = StringBuffer();
    _stderrBuffers[sessionId] = StringBuffer();
    _startTimes[sessionId] = startTime;
    _filePaths[sessionId] = null;

    // Build environment
    final env = _buildEnvironment(environment);

    try {
      // Spawn Python process with code via -c flag
      final handle = await _processChannel.spawnProcess(
        argv: [_pythonExecutable, '-c', code],
        workingDirectory: workingDirectory,
        environment: env,
        timeoutSeconds: timeout.inSeconds,
      );

      log.debug(
        LogSubsystem.runtime,
        '[$sessionId] Process spawned: PID ${handle.pid}',
      );

      // Wait for completion (completer will be resolved by output listener)
      final result = await _executionCompleters[sessionId]!.future;

      final duration = DateTime.now().difference(startTime);
      log.info(
        LogSubsystem.runtime,
        '[$sessionId] Execution complete: exit=${result.exitCode}, duration=${duration.inMilliseconds}ms',
      );

      return result;
    } catch (e) {
      log.error(LogSubsystem.runtime, '[$sessionId] Execution failed: $e');

      // Clean up
      _cleanupSession(sessionId);

      return ExecutionResult(
        exitCode: -1,
        stdout: _stdoutBuffers[sessionId]?.toString() ?? '',
        stderr: 'Execution error: $e',
        executionTime: DateTime.now().difference(startTime),
        timedOut: false,
        oomKilled: false,
      );
    }
  }

  /// Execute a Python file.
  Future<ExecutionResult> executeFile({
    required String filePath,
    required String workingDirectory,
    List<String> arguments = const [],
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final startTime = DateTime.now();

    log.info(
      LogSubsystem.runtime,
      '[$sessionId] Executing Python file: $filePath',
    );

    // Initialize buffers and controllers
    _outputControllers[sessionId] = StreamController<String>.broadcast();
    _executionCompleters[sessionId] = Completer<ExecutionResult>();
    _stdoutBuffers[sessionId] = StringBuffer();
    _stderrBuffers[sessionId] = StringBuffer();
    _startTimes[sessionId] = startTime;
    _filePaths[sessionId] = filePath;

    // Build environment
    final env = _buildEnvironment(environment);

    try {
      // Spawn Python process
      final argv = [_pythonExecutable, filePath, ...arguments];
      final handle = await _processChannel.spawnProcess(
        argv: argv,
        workingDirectory: workingDirectory,
        environment: env,
        timeoutSeconds: timeout.inSeconds,
      );

      log.debug(
        LogSubsystem.runtime,
        '[$sessionId] Process spawned: PID ${handle.pid}',
      );

      // Wait for completion
      final result = await _executionCompleters[sessionId]!.future;

      final duration = DateTime.now().difference(startTime);
      log.info(
        LogSubsystem.runtime,
        '[$sessionId] File execution complete: exit=${result.exitCode}, duration=${duration.inMilliseconds}ms',
      );

      return result;
    } catch (e) {
      log.error(LogSubsystem.runtime, '[$sessionId] File execution failed: $e');

      // Clean up
      _cleanupSession(sessionId);

      return ExecutionResult(
        exitCode: -1,
        stdout: _stdoutBuffers[sessionId]?.toString() ?? '',
        stderr: 'File execution error: $e',
        executionTime: DateTime.now().difference(startTime),
        timedOut: false,
        oomKilled: false,
      );
    }
  }

  /// Build Python environment variables.
  Map<String, String> _buildEnvironment(Map<String, String>? userEnv) {
    final env = <String, String>{
      // Basic environment
      'LANG': 'en_US.UTF-8',
      'TERM': 'xterm-256color',

      // Python-specific (will be configured based on actual Python installation)
      // 'PYTHONHOME': '/path/to/python',
      // 'PYTHONPATH': '/path/to/stdlib',
      // 'TMPDIR': '/data/data/com.offlinemobileide.aioide/cache',
    };

    if (userEnv != null) {
      env.addAll(userEnv);
    }

    return env;
  }

  /// Start listening to process output.
  void _startOutputListener() {
    _outputSubscription = _processChannel.outputStream.listen(
      (event) {
        // Find matching execution
        final controller = _outputControllers[event.sessionId];
        final completer = _executionCompleters[event.sessionId];

        if (controller == null || completer == null) return;

        if (event.isOutput) {
          // Collect output
          final content = event.content ?? '';
          if (event.type == ProcessOutputType.stdout) {
            _stdoutBuffers[event.sessionId]?.write(content);
          } else if (event.type == ProcessOutputType.stderr) {
            _stderrBuffers[event.sessionId]?.write(content);
          }

          // Forward to stream
          controller.add(content);
        } else if (event.isExit) {
          // Get collected output
          final stdout = _stdoutBuffers[event.sessionId]?.toString() ?? '';
          final stderr = _stderrBuffers[event.sessionId]?.toString() ?? '';
          final startTime = _startTimes[event.sessionId] ?? DateTime.now();
          final filePath = _filePaths[event.sessionId];
          final duration = DateTime.now().difference(startTime);

          // Parse diagnostics from stderr
          final diagnostics = PythonDiagnosticsParser.parse(
            stderr,
            filePath: filePath,
          );

          // Build execution result
          final result = ExecutionResult(
            exitCode: event.exitCode ?? -1,
            stdout: stdout,
            stderr: stderr,
            executionTime: duration,
            timedOut: event.timedOut,
            oomKilled: event.oomKilled,
            diagnostics: diagnostics,
          );

          // Complete the execution
          if (!completer.isCompleted) {
            completer.complete(result);
          }

          // Clean up
          _cleanupSession(event.sessionId);
        }
      },
      onError: (error) {
        log.error(LogSubsystem.runtime, 'Output stream error: $error');
      },
    );
  }

  /// Clean up session resources.
  void _cleanupSession(String sessionId) {
    _outputControllers[sessionId]?.close();
    _outputControllers.remove(sessionId);
    _executionCompleters.remove(sessionId);
    _stdoutBuffers.remove(sessionId);
    _stderrBuffers.remove(sessionId);
    _startTimes.remove(sessionId);
    _filePaths.remove(sessionId);
  }

  /// Get runtime status.
  bool get isInstalled => _isInstalled;
  String? get version => _version;
  String? get pythonPath => _pythonPath;

  /// Dispose resources.
  void dispose() {
    _outputSubscription?.cancel();
    for (final controller in _outputControllers.values) {
      controller.close();
    }
    _outputControllers.clear();
    _executionCompleters.clear();
    _stdoutBuffers.clear();
    _stderrBuffers.clear();
    _startTimes.clear();
    _filePaths.clear();
  }
}
