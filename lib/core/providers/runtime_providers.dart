import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/runtime/python_runtime.dart';
import '../models/execution_result.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Python Runtime
// ─────────────────────────────────────────────────────────────────────────────

/// Python runtime singleton provider.
///
/// Provides access to the PythonRuntime service for executing Python code.
/// Architecture: 08-ROADMAP.md Phase 5
final pythonRuntimeProvider = Provider<PythonRuntime>((ref) {
  return PythonRuntime.instance;
});

/// Initialize Python runtime on app startup.
final pythonRuntimeInitProvider = FutureProvider<void>((ref) async {
  final runtime = ref.watch(pythonRuntimeProvider);
  await runtime.initialize();
});

/// Python runtime status provider.
///
/// Returns whether Python is installed and accessible.
final pythonRuntimeStatusProvider = Provider<bool>((ref) {
  final runtime = ref.watch(pythonRuntimeProvider);
  return runtime.isInstalled;
});

/// Python version provider.
final pythonVersionProvider = Provider<String?>((ref) {
  final runtime = ref.watch(pythonRuntimeProvider);
  return runtime.version;
});

// ─────────────────────────────────────────────────────────────────────────────
// Execution State
// ─────────────────────────────────────────────────────────────────────────────

/// Current execution result provider.
///
/// Used by the Terminal screen to display the most recent execution output.
final currentExecutionResultProvider = StateProvider<ExecutionResult?>((ref) {
  return null;
});

/// Whether code is currently executing.
final isExecutingProvider = StateProvider<bool>((ref) {
  return false;
});
