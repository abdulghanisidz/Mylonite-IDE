import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/runtime_providers.dart';
import '../../core/models/execution_result.dart';
import '../../ui/theme/app_theme.dart';

/// Terminal screen — interactive process I/O interface.
///
/// Phase 1: Shell with static placeholder output.
/// Phase 5: Wired to RuntimeManager / ProcessManager output streams. ✅ DONE
/// Phase 7: Full interactive stdin, ANSI colour, scrollback.
///
/// Architecture: 04-RUNTIME-SYSTEM.md §9, FR-034–FR-042
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final _stdinController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _stdinController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final executionResult = ref.watch(currentExecutionResultProvider);
    final isExecuting = ref.watch(isExecutingProvider);
    final pythonVersion = ref.watch(pythonVersionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal'),
        actions: [
          // Python version chip
          if (pythonVersion != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.code, size: 14),
                label: Text(pythonVersion.split('\n').first.split(' ').first),
                labelStyle: const TextStyle(fontSize: 11),
                backgroundColor: AppColors.darkSurfaceVariant,
                side: const BorderSide(color: AppColors.darkBorder),
              ),
            ),
          // Process status chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(isExecuting ? 'RUNNING' : 'IDLE'),
              labelStyle: const TextStyle(fontSize: 11),
              backgroundColor: isExecuting
                  ? Colors.green.shade900
                  : AppColors.darkSurfaceVariant,
              side: BorderSide(
                color: isExecuting ? Colors.green : AppColors.darkBorder,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            tooltip: 'Stop process',
            color: AppColors.error,
            onPressed: isExecuting
                ? () {
                    // Phase 7: implement process termination
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Process termination not yet implemented',
                        ),
                      ),
                    );
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear output',
            onPressed: executionResult != null
                ? () {
                    ref.read(currentExecutionResultProvider.notifier).state =
                        null;
                  }
                : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Output area
          Expanded(
            child: Container(
              color: AppColors.darkBackground,
              child: executionResult == null && !isExecuting
                  ? _buildWelcomeScreen(pythonVersion)
                  : _buildOutputScreen(executionResult, isExecuting),
            ),
          ),

          // stdin input row (Phase 7)
          const Divider(height: 1),
          _StdinInputBar(controller: _stdinController),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen(String? pythonVersion) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.terminal, size: 64, color: AppColors.darkBorder),
          const SizedBox(height: 16),
          Text(
            'Mylonite Terminal',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.editorForeground,
            ),
          ),
          const SizedBox(height: 8),
          if (pythonVersion != null) ...[
            Text(
              'Python ${pythonVersion.split('\n').first}',
              style: TextStyle(fontSize: 14, color: AppColors.secondary),
            ),
            const SizedBox(height: 16),
            Text(
              'Open a Python file and press Run to execute',
              style: TextStyle(fontSize: 14, color: AppColors.darkBorder),
            ),
          ] else ...[
            Text(
              'Python runtime not available',
              style: TextStyle(fontSize: 14, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.help_outline, size: 18),
              label: const Text('How to Install Python'),
              onPressed: () {
                _showInstallationInstructions(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOutputScreen(ExecutionResult? result, bool isExecuting) {
    if (isExecuting && result == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.secondary),
            const SizedBox(height: 16),
            Text(
              'Executing...',
              style: TextStyle(color: AppColors.editorForeground, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (result == null) {
      return _buildWelcomeScreen(ref.watch(pythonVersionProvider));
    }

    final lines = <_OutputLine>[];

    // Show execution header
    final duration = result.executionTime.inMilliseconds;
    lines.add(
      _OutputLine(
        '─────────────────────────────────────────────────',
        color: AppColors.darkBorder,
      ),
    );
    lines.add(
      _OutputLine(
        'Execution completed in ${duration}ms',
        color: AppColors.secondary,
      ),
    );
    lines.add(
      _OutputLine(
        '─────────────────────────────────────────────────',
        color: AppColors.darkBorder,
      ),
    );
    lines.add(_OutputLine(''));

    // Show stdout
    if (result.stdout.isNotEmpty) {
      lines.add(_OutputLine('STDOUT:', color: AppColors.primary));
      for (final line in result.stdout.split('\n')) {
        lines.add(_OutputLine(line));
      }
      lines.add(_OutputLine(''));
    }

    // Show stderr
    if (result.stderr.isNotEmpty) {
      lines.add(_OutputLine('STDERR:', color: AppColors.error));
      for (final line in result.stderr.split('\n')) {
        lines.add(_OutputLine(line, color: AppColors.error));
      }
      lines.add(_OutputLine(''));
    }

    // Show diagnostics
    if (result.diagnostics.isNotEmpty) {
      lines.add(_OutputLine('DIAGNOSTICS:', color: AppColors.warning));
      for (final diag in result.diagnostics) {
        final location = diag.file != null && diag.line != null
            ? '${diag.file}:${diag.line}'
            : diag.file ?? 'unknown';
        lines.add(
          _OutputLine('  [$location] ${diag.message}', color: AppColors.error),
        );
      }
      lines.add(_OutputLine(''));
    }

    // Show exit status
    lines.add(
      _OutputLine(
        '─────────────────────────────────────────────────',
        color: AppColors.darkBorder,
      ),
    );

    if (result.timedOut) {
      lines.add(_OutputLine('Process timed out', color: AppColors.warning));
    } else if (result.oomKilled) {
      lines.add(
        _OutputLine('Process killed (out of memory)', color: AppColors.error),
      );
    } else if (result.exitCode == 0) {
      lines.add(
        _OutputLine(
          'Process exited with code 0 (success)',
          color: Colors.green,
        ),
      );
    } else {
      lines.add(
        _OutputLine(
          'Process exited with code ${result.exitCode} (error)',
          color: AppColors.error,
        ),
      );
    }

    lines.add(
      _OutputLine(
        '─────────────────────────────────────────────────',
        color: AppColors.darkBorder,
      ),
    );

    // Scroll to bottom after render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: lines.length,
      itemBuilder: (context, i) {
        final line = lines[i];
        return Text(
          line.text,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 13,
            color: line.color,
            height: 1.6,
          ),
        );
      },
    );
  }
}

class _OutputLine {
  const _OutputLine(this.text, {this.color = AppColors.editorForeground});
  final String text;
  final Color color;
}

class _StdinInputBar extends StatelessWidget {
  const _StdinInputBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text(
            '>',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              color: AppColors.primary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: false, // Phase 7: enable when stdin support added
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                color: AppColors.editorForeground,
              ),
              decoration: const InputDecoration(
                hintText: 'stdin support coming in Phase 7...',
                hintStyle: TextStyle(color: Color(0xFF555555), fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: null, // Phase 7: write to process stdin
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, size: 18),
            color: AppColors.primary,
            onPressed: null, // Phase 7
          ),
        ],
      ),
    );
  }
}

/// Show Python installation instructions dialog.
void _showInstallationInstructions(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Install Python for Android'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Option 1: Install Termux (Recommended)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Install Termux from F-Droid:\n'
              '   https://f-droid.org/packages/com.termux/\n\n'
              '2. Open Termux and run:\n'
              '   pkg update && pkg install python\n\n'
              '3. Restart Mylonite IDE',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade700),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Important: Use F-Droid version, not Google Play (outdated)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade100,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Option 2: Bundled Python (Coming Soon)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'re working on bundling Python with the app. '
              'This will be available in a future update.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Open F-Droid'),
          onPressed: () {
            // TODO: Open F-Droid URL
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please visit f-droid.org in your browser'),
              ),
            );
          },
        ),
      ],
    ),
  );
}
