/// Autonomous agent service that orchestrates the self-correcting loop.
///
/// The agent follows the SENSE→DECIDE→ACT→CHECK→RECOVER cycle:
/// 1. SENSE: Parse and understand user request
/// 2. DECIDE: Plan the approach and determine what to generate
/// 3. ACT: Generate code using AI model
/// 4. CHECK: Execute code and validate results
/// 5. RECOVER: If errors, analyze and regenerate (with retry limit)
library;

import 'dart:async';
import 'dart:io';

import '../../models/agent_task.dart';
import '../../models/execution_result.dart';
import '../../models/enums.dart';
import '../ai/inference_service.dart';
import '../runtime/python_runtime.dart';
import '../logging_service.dart';

import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

/// Service for autonomous agent task execution.
class AgentService {
  final InferenceService _inferenceService;
  final PythonRuntime _pythonRuntime;

  /// Active tasks being processed.
  final Map<String, AgentTask> _activeTasks = {};

  /// Stream controller for task updates.
  final _taskUpdatesController = StreamController<AgentTask>.broadcast();

  /// UUID generator.
  final _uuid = const Uuid();

  AgentService({
    required InferenceService inferenceService,
    required PythonRuntime pythonRuntime,
  }) : _inferenceService = inferenceService,
       _pythonRuntime = pythonRuntime;

  /// Stream of task updates.
  Stream<AgentTask> get taskUpdates => _taskUpdatesController.stream;

  /// Get active task by ID.
  AgentTask? getTask(String taskId) => _activeTasks[taskId];

  /// Get all active tasks.
  List<AgentTask> get activeTasks => _activeTasks.values.toList();

  /// Create and execute a new agent task.
  ///
  /// Returns task ID immediately, execution happens asynchronously.
  /// Listen to [taskUpdates] stream for progress updates.
  Future<String> executeTask({
    required String userRequest,
    String? projectId,
    String? filename,
    int maxRetries = 3,
  }) async {
    final taskId = _uuid.v4();
    final task = AgentTask(
      id: taskId,
      userRequest: userRequest,
      projectId: projectId,
      filename: filename,
      maxRetries: maxRetries,
    );

    _activeTasks[taskId] = task;
    _notifyTaskUpdate(task);

    log.info(LogSubsystem.agent, 'Created task $taskId: "$userRequest"');

    // Execute autonomously in background
    _executeTaskLoop(task);

    return taskId;
  }

  /// Execute the autonomous agent loop.
  Future<void> _executeTaskLoop(AgentTask task) async {
    try {
      log.info(LogSubsystem.agent, 'Starting agent loop for task ${task.id}');

      // SENSE: Understand the request
      await _sensePhase(task);

      // DECIDE: Plan approach
      await _decidePhase(task);

      // Main loop: ACT → CHECK → (RECOVER if needed)
      while (!task.isTerminal && !task.hasReachedMaxRetries) {
        // ACT: Generate code
        await _actPhase(task);

        // CHECK: Execute and validate
        final executionSuccess = await _checkPhase(task);

        if (executionSuccess) {
          // Success! Task complete
          task.updateStatus(AgentTaskStatus.completed);
          task.resultMessage = 'Code executed successfully!';
          task.addLoopMessage('✓ Task completed successfully');
          _notifyTaskUpdate(task);
          break;
        } else {
          // RECOVER: Analyze error and retry
          if (task.hasReachedMaxRetries) {
            task.updateStatus(AgentTaskStatus.failed);
            task.resultMessage =
                'Failed after ${task.maxRetries} attempts. Last error: ${task.latestVersion?.executionResult?.stderr}';
            task.addLoopMessage('✗ Max retries reached, task failed');
            _notifyTaskUpdate(task);
            break;
          }

          await _recoverPhase(task);
          task.retryCount++;
        }
      }

      log.info(
        LogSubsystem.agent,
        'Task ${task.id} finished with status: ${task.status}',
      );
    } catch (e, stackTrace) {
      log.error(
        LogSubsystem.agent,
        'Task ${task.id} failed with exception: $e',
        exception: e,
      );
      task.updateStatus(AgentTaskStatus.failed);
      task.resultMessage = 'Internal error: $e';
      task.addLoopMessage('✗ Exception: $e');
      _notifyTaskUpdate(task);
    }
  }

  /// SENSE Phase: Parse and understand user request.
  Future<void> _sensePhase(AgentTask task) async {
    task.updateStatus(AgentTaskStatus.sensing);
    task.addLoopMessage('SENSE: Analyzing request...');
    _notifyTaskUpdate(task);

    log.debug(
      LogSubsystem.agent,
      'SENSE: Understanding request: "${task.userRequest}"',
    );

    // Simple intent analysis (can be enhanced with AI later)
    final lowercaseRequest = task.userRequest.toLowerCase();

    if (lowercaseRequest.contains('fibonacci')) {
      task.addLoopMessage('→ Detected: Fibonacci sequence generation');
    } else if (lowercaseRequest.contains('calculator') ||
        lowercaseRequest.contains('calculate')) {
      task.addLoopMessage('→ Detected: Calculator functionality');
    } else if (lowercaseRequest.contains('sort')) {
      task.addLoopMessage('→ Detected: Sorting algorithm');
    } else if (lowercaseRequest.contains('file') ||
        lowercaseRequest.contains('read') ||
        lowercaseRequest.contains('write')) {
      task.addLoopMessage('→ Detected: File operations');
    } else {
      task.addLoopMessage('→ Detected: General Python task');
    }

    _notifyTaskUpdate(task);

    // Small delay to show phase transition in UI
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// DECIDE Phase: Plan the approach.
  Future<void> _decidePhase(AgentTask task) async {
    task.updateStatus(AgentTaskStatus.deciding);
    task.addLoopMessage('DECIDE: Planning approach...');
    _notifyTaskUpdate(task);

    log.debug(LogSubsystem.agent, 'DECIDE: Planning code generation strategy');

    task.addLoopMessage('→ Will generate Python code');
    task.addLoopMessage('→ Will execute and validate output');
    task.addLoopMessage('→ Will auto-correct if errors detected');

    _notifyTaskUpdate(task);

    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// ACT Phase: Generate code using AI.
  Future<void> _actPhase(AgentTask task) async {
    task.updateStatus(AgentTaskStatus.generating);

    final attemptNum = task.retryCount + 1;
    task.addLoopMessage(
      'ACT: Generating code (attempt $attemptNum/${task.maxRetries})...',
    );
    _notifyTaskUpdate(task);

    log.debug(LogSubsystem.agent, 'ACT: Generating code with AI');

    // Build prompt based on context
    final prompt = _buildGenerationPrompt(task);

    // Generate code using AI
    final generatedCode = StringBuffer();
    await for (final token in _inferenceService.generateCode(
      taskDescription: prompt,
      language: 'Python',
    )) {
      generatedCode.write(token);
    }

    final code = generatedCode.toString().trim();

    log.debug(LogSubsystem.agent, 'Generated ${code.length} chars of code');

    // Create code version
    final version = CodeVersion(
      code: code,
      version: task.codeVersions.length + 1,
      timestamp: DateTime.now(),
      reasoning: task.retryCount == 0
          ? 'Initial generation'
          : 'Retry after error in version ${task.codeVersions.length}',
    );

    task.addCodeVersion(version);
    task.addLoopMessage('→ Generated ${code.split('\n').length} lines of code');

    _notifyTaskUpdate(task);
  }

  /// CHECK Phase: Execute code and validate results.
  Future<bool> _checkPhase(AgentTask task) async {
    task.updateStatus(AgentTaskStatus.executing);
    task.addLoopMessage('CHECK: Executing code...');
    _notifyTaskUpdate(task);

    final version = task.latestVersion;
    if (version == null) {
      log.error(LogSubsystem.agent, 'No code version to execute');
      return false;
    }

    log.debug(
      LogSubsystem.agent,
      'CHECK: Executing code version ${version.version}',
    );

    // Save code to temporary file
    final tempDir = Directory.systemTemp.createTempSync('aioide_agent_');
    final tempFile = File(path.join(tempDir.path, 'generated.py'));
    await tempFile.writeAsString(version.code);

    try {
      // Execute with timeout
      final result = await _pythonRuntime
          .executeFile(
            filePath: tempFile.path,
            workingDirectory: tempDir.path,
            arguments: [],
            timeout: const Duration(seconds: 30),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => ExecutionResult(
              exitCode: 124,
              stdout: '',
              stderr: 'Execution timeout (30s)',
              executionTime: const Duration(seconds: 30),
            ),
          );

      // Update version with execution result
      final updatedVersion = CodeVersion(
        code: version.code,
        version: version.version,
        timestamp: version.timestamp,
        executionResult: result,
        reasoning: version.reasoning,
      );

      // Replace the version with updated one
      task.codeVersions[task.codeVersions.length - 1] = updatedVersion;

      log.debug(
        LogSubsystem.agent,
        'Execution completed: exitCode=${result.exitCode}',
      );

      task.addLoopMessage(
        '→ Exit code: ${result.exitCode} (${result.executionTime.inMilliseconds}ms)',
      );

      if (result.stdout.isNotEmpty) {
        task.addLoopMessage(
          '→ Output: ${result.stdout.substring(0, result.stdout.length > 100 ? 100 : result.stdout.length)}${result.stdout.length > 100 ? '...' : ''}',
        );
      }

      if (result.stderr.isNotEmpty) {
        task.addLoopMessage(
          '→ Error: ${result.stderr.substring(0, result.stderr.length > 100 ? 100 : result.stderr.length)}${result.stderr.length > 100 ? '...' : ''}',
        );
      }

      _notifyTaskUpdate(task);

      // Validate phase
      task.updateStatus(AgentTaskStatus.validating);
      task.addLoopMessage('CHECK: Validating results...');
      _notifyTaskUpdate(task);

      await Future.delayed(const Duration(milliseconds: 300));

      final isSuccess = result.exitCode == 0 && result.stderr.isEmpty;

      if (isSuccess) {
        task.addLoopMessage('✓ Validation passed');
      } else {
        task.addLoopMessage('✗ Validation failed');
      }

      _notifyTaskUpdate(task);

      return isSuccess;
    } finally {
      // Cleanup temp file
      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        log.debug(LogSubsystem.agent, 'Failed to cleanup temp dir: $e');
      }
    }
  }

  /// RECOVER Phase: Analyze error and prepare for retry.
  Future<void> _recoverPhase(AgentTask task) async {
    task.updateStatus(AgentTaskStatus.analyzing);
    task.addLoopMessage('RECOVER: Analyzing error...');
    _notifyTaskUpdate(task);

    final version = task.latestVersion;
    if (version?.executionResult == null) {
      return;
    }

    log.debug(LogSubsystem.agent, 'RECOVER: Analyzing execution error');

    final result = version!.executionResult!;

    // Parse error type
    String errorType = 'Unknown error';
    if (result.stderr.contains('SyntaxError')) {
      errorType = 'Syntax error';
    } else if (result.stderr.contains('NameError')) {
      errorType = 'Name error (undefined variable)';
    } else if (result.stderr.contains('TypeError')) {
      errorType = 'Type error';
    } else if (result.stderr.contains('ValueError')) {
      errorType = 'Value error';
    } else if (result.stderr.contains('IndentationError')) {
      errorType = 'Indentation error';
    } else if (result.stderr.contains('ImportError') ||
        result.stderr.contains('ModuleNotFoundError')) {
      errorType = 'Import error';
    } else if (result.exitCode == 124) {
      errorType = 'Timeout';
    }

    final errorAnalysis =
        '$errorType detected. Will regenerate with corrections.';

    // Update version with error analysis
    final updatedVersion = CodeVersion(
      code: version.code,
      version: version.version,
      timestamp: version.timestamp,
      executionResult: version.executionResult,
      reasoning: version.reasoning,
      errorAnalysis: errorAnalysis,
    );

    task.codeVersions[task.codeVersions.length - 1] = updatedVersion;

    task.addLoopMessage('→ Error type: $errorType');
    task.addLoopMessage('→ Will retry with corrections');

    _notifyTaskUpdate(task);

    await Future.delayed(const Duration(milliseconds: 500));

    task.updateStatus(AgentTaskStatus.fixing);
    task.addLoopMessage(
      'RECOVER: Preparing retry ${task.retryCount + 1}/${task.maxRetries}...',
    );
    _notifyTaskUpdate(task);

    await Future.delayed(const Duration(milliseconds: 300));
  }

  /// Build generation prompt based on task context.
  String _buildGenerationPrompt(AgentTask task) {
    if (task.retryCount == 0) {
      // Initial generation
      return task.userRequest;
    } else {
      // Retry with error context
      final previousVersion = task.latestVersion;
      if (previousVersion == null) return task.userRequest;

      final errorInfo = previousVersion.executionResult;
      if (errorInfo == null) return task.userRequest;

      return '''
The previous code had an error. Please fix it.

Original request: ${task.userRequest}

Previous code:
```python
${previousVersion.code}
```

Error (exit code ${errorInfo.exitCode}):
${errorInfo.stderr}

Please generate corrected Python code that fixes this error.
''';
    }
  }

  /// Notify listeners of task update.
  void _notifyTaskUpdate(AgentTask task) {
    _taskUpdatesController.add(task);
  }

  /// Cancel a running task.
  Future<void> cancelTask(String taskId) async {
    final task = _activeTasks[taskId];
    if (task == null) return;

    if (!task.isTerminal) {
      task.updateStatus(AgentTaskStatus.cancelled);
      task.resultMessage = 'Cancelled by user';
      task.addLoopMessage('Task cancelled by user');
      _notifyTaskUpdate(task);

      log.info(LogSubsystem.agent, 'Task $taskId cancelled');
    }
  }

  /// Remove task from active tasks (for cleanup).
  void removeTask(String taskId) {
    _activeTasks.remove(taskId);
  }

  /// Dispose resources.
  void dispose() {
    _taskUpdatesController.close();
  }
}
