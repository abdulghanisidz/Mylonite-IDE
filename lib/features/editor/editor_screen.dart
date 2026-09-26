import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/python.dart';

import '../../core/models/enums.dart';
import '../../core/providers/project_providers.dart';
import '../../core/providers/runtime_providers.dart';
import '../../core/services/editor/editor_controller.dart';
import '../../ui/theme/app_theme.dart';
import '../../core/services/logging_service.dart';

/// Mylonite IDE — Code Editor screen.
///
/// Features (Phase 3):
///   • Syntax highlighting via flutter_code_editor (Python, JavaScript)
///   • Line numbers gutter with diagnostic markers
///   • File tabs — open multiple files, dirty indicator, close
///   • Undo / Redo
///   • In-file search (text + regex, case toggle)
///   • AI diff preview with Accept / Reject
///   • Code keyboard toolbar (indent, dedent, brackets)
///   • Auto-save on tab switch and when leaving the screen
///
/// Architecture: 02-ARCHITECTURE.md §EditorController, FR-020–FR-033
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with WidgetsBindingObserver {
  /// The flutter_code_editor CodeController for the active tab.
  CodeController? _codeController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeController?.dispose();
    super.dispose();
  }

  /// Auto-save when the app goes to the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(editorControllerProvider)?.onAppBackground();
    }
  }

  // ── Run Python code ───────────────────────────────────────────────────────

  /// Execute the currently active Python file.
  Future<void> _runPythonFile(EditorController ec) async {
    final tab = ec.activeTab;
    if (tab == null) return;

    // Only run Python files
    if (tab.language != Language.python) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Python files can be executed')),
      );
      return;
    }

    // Save file first if dirty
    if (tab.isDirty) {
      await ec.saveActive();
    }

    // Get Python runtime
    final pythonRuntime = ref.read(pythonRuntimeProvider);

    // Check if Python is installed
    if (!pythonRuntime.isInstalled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Python runtime not available. Install Python to run code.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Show executing status
    ref.read(isExecutingProvider.notifier).state = true;

    try {
      log.info(
        LogSubsystem.runtime,
        'Executing Python file: ${tab.relativePath}',
      );

      // Get workspace directory
      final workspace = ref.read(workspaceManagerProvider);
      if (workspace == null) return;

      // Build absolute path
      final absolutePath = '${workspace.workspaceRoot}/${tab.relativePath}';

      // Execute the file
      final result = await pythonRuntime.executeFile(
        filePath: absolutePath,
        workingDirectory: workspace.workspaceRoot,
        timeout: const Duration(seconds: 60),
      );

      // Store result for Terminal screen
      ref.read(currentExecutionResultProvider.notifier).state = result;

      // Show result notification
      if (mounted) {
        final message = result.isSuccess
            ? 'Execution completed successfully'
            : result.timedOut
            ? 'Execution timed out'
            : result.oomKilled
            ? 'Process killed (out of memory)'
            : 'Execution failed with exit code ${result.exitCode}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: result.isSuccess
                ? Colors.green.shade700
                : Colors.red.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      log.info(
        LogSubsystem.runtime,
        'Execution complete: ${result.statusMessage}, duration: ${result.executionTime.inMilliseconds}ms',
      );
    } catch (e) {
      log.error(LogSubsystem.runtime, 'Execution error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Execution error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      ref.read(isExecutingProvider.notifier).state = false;
    }
  }

  // ── CodeController sync ───────────────────────────────────────────────────

  /// Rebuilds the [CodeController] whenever the active tab changes.
  CodeController _syncCodeController(EditorController ec) {
    final tab = ec.activeTab;
    if (tab == null) {
      _codeController?.dispose();
      _codeController = CodeController(text: '');
      return _codeController!;
    }

    // Rebuild if tab changed or controller was disposed
    final existing = _codeController;
    final modeChanged = existing == null;
    if (modeChanged) {
      existing?.dispose();
      _codeController = CodeController(
        text: tab.content,
        language: _languageMode(tab.language),
      );
      _codeController!.addListener(() {
        final newText = _codeController!.text;
        if (newText != ec.activeTab?.content) {
          ec.onContentChanged(
            newText,
            cursorOffset: _codeController!.selection.baseOffset,
          );
        }
      });
    } else if (existing.text != tab.content) {
      // External change (e.g. diff accepted, undo from controller)
      existing.value = TextEditingValue(
        text: tab.content,
        selection: existing.selection,
      );
    }
    return _codeController!;
  }

  static dynamic _languageMode(Language lang) => switch (lang) {
    Language.python => python,
    Language.javascript => javascript,
    _ => null,
  };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ec = ref.watch(editorControllerProvider);

    if (ec == null) {
      return const _NoProjectOpen();
    }

    final codeCtrl = _syncCodeController(ec);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _TabBar(ec: ec),
        actions: [
          // Undo
          IconButton(
            icon: const Icon(Icons.undo, size: 20),
            tooltip: 'Undo',
            onPressed: ec.activeTab?.canUndo == true
                ? () {
                    final restored = ec.undo();
                    if (restored != null) {
                      codeCtrl.value = TextEditingValue(
                        text: restored,
                        selection: TextSelection.collapsed(
                          offset: restored.length,
                        ),
                      );
                    }
                  }
                : null,
          ),
          // Redo
          IconButton(
            icon: const Icon(Icons.redo, size: 20),
            tooltip: 'Redo',
            onPressed: ec.activeTab?.canRedo == true
                ? () {
                    final restored = ec.redo();
                    if (restored != null) {
                      codeCtrl.value = TextEditingValue(
                        text: restored,
                        selection: TextSelection.collapsed(
                          offset: restored.length,
                        ),
                      );
                    }
                  }
                : null,
          ),
          // Search
          IconButton(
            icon: Icon(
              Icons.search,
              size: 20,
              color: ec.searchVisible ? AppColors.primary : null,
            ),
            tooltip: 'Find',
            onPressed: ec.activeTab != null
                ? () {
                    if (ec.searchVisible) {
                      ec.hideSearch();
                    } else {
                      ec.showSearch();
                    }
                  }
                : null,
          ),
          // Save
          IconButton(
            icon: Icon(
              Icons.save_outlined,
              size: 20,
              color: ec.activeTab?.isDirty == true ? AppColors.warning : null,
            ),
            tooltip: 'Save',
            onPressed: ec.activeTab?.isDirty == true
                ? () => ec.saveActive()
                : null,
          ),
          // Run (Phase 5)
          IconButton(
            icon: const Icon(Icons.play_arrow_outlined, size: 20),
            tooltip: 'Run Python file',
            color: AppColors.secondary,
            onPressed:
                ec.activeTab?.language == Language.python &&
                    !ref.watch(isExecutingProvider)
                ? () => _runPythonFile(ec)
                : null,
          ),
        ],
      ),
      body: ec.activeTab == null
          ? const _NoFileOpen()
          : Column(
              children: [
                // AI diff banner
                if (ec.hasPendingDiff) _DiffBanner(ec: ec, codeCtrl: codeCtrl),

                // Search bar
                if (ec.searchVisible) _SearchBar(ec: ec, codeCtrl: codeCtrl),

                // Editor
                Expanded(
                  child: _CodeEditorArea(ec: ec, codeCtrl: codeCtrl),
                ),

                // Status bar
                _StatusBar(ec: ec),
              ],
            ),
    );
  }
}

// ── No project / no file ──────────────────────────────────────────────────────

class _NoProjectOpen extends StatelessWidget {
  const _NoProjectOpen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.code_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No project open',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoFileOpen extends StatelessWidget {
  const _NoFileOpen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Open a file from the Explorer',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.ec});
  final EditorController ec;

  @override
  Widget build(BuildContext context) {
    if (ec.tabs.isEmpty) {
      return const SizedBox(
        height: kToolbarHeight,
        child: Center(
          child: Text(
            'Mylonite IDE',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: kToolbarHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: ec.tabs.length,
        itemBuilder: (context, i) => _FileTab(
          tab: ec.tabs[i],
          isActive: i == ec.activeIndex,
          onTap: () => ec.switchTab(i),
          onClose: () => ec.closeTab(i),
        ),
      ),
    );
  }
}

class _FileTab extends StatelessWidget {
  const _FileTab({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  final EditorTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).scaffoldBackgroundColor
              : Theme.of(context).cardColor,
          border: Border(
            top: isActive
                ? const BorderSide(color: AppColors.primary, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tab.isDirty)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              tab.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isActive
                    ? AppColors.editorForeground
                    : AppColors.editorForeground.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClose,
              child: Icon(
                Icons.close,
                size: 13,
                color: AppColors.editorForeground.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Code editor area ──────────────────────────────────────────────────────────

class _CodeEditorArea extends StatelessWidget {
  const _CodeEditorArea({required this.ec, required this.codeCtrl});

  final EditorController ec;
  final CodeController codeCtrl;

  @override
  Widget build(BuildContext context) {
    const fontSize = 13.0;

    return CodeTheme(
      data: CodeThemeData(styles: vs2015Theme),
      child: SingleChildScrollView(
        child: CodeField(
          controller: codeCtrl,
          textStyle: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: fontSize,
            height: 1.6,
          ),
          background: AppColors.darkBackground,
          gutterStyle: GutterStyle(
            width: 52,
            textStyle: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              color: AppColors.darkBorder,
            ),
            showErrors: false,
            showLineNumbers: true,
          ),
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.ec, required this.codeCtrl});
  final EditorController ec;
  final CodeController codeCtrl;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _ctrl = TextEditingController();
  int _matchIndex = 0;
  List<SearchMatch> _matches = [];

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.ec.searchQuery;
    _updateMatches();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _updateMatches() {
    final content = widget.codeCtrl.text;
    setState(() {
      _matches = widget.ec.findMatches(content);
      if (_matchIndex >= _matches.length) _matchIndex = 0;
    });
  }

  void _navigate(int delta) {
    if (_matches.isEmpty) return;
    setState(() {
      _matchIndex = (_matchIndex + delta) % _matches.length;
    });
    // Jump to the match in the CodeController
    final m = _matches[_matchIndex];
    widget.codeCtrl.selection = TextSelection(
      baseOffset: m.start,
      extentOffset: m.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _matches.length;
    final label = count == 0 ? 'No results' : '${_matchIndex + 1} / $count';

    return Container(
      height: 44,
      color: AppColors.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Search input
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                color: AppColors.editorForeground,
              ),
              decoration: InputDecoration(
                hintText: 'Find…',
                hintStyle: const TextStyle(
                  color: AppColors.darkBorder,
                  fontSize: 13,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (v) {
                widget.ec.updateSearch(query: v);
                _updateMatches();
              },
            ),
          ),
          const SizedBox(width: 6),

          // Match count
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.editorForeground,
            ),
          ),
          const SizedBox(width: 4),

          // Regex toggle
          _ToggleBtn(
            icon: Icons.data_object,
            tooltip: 'Regex',
            active: widget.ec.searchIsRegex,
            onTap: () {
              widget.ec.updateSearch(isRegex: !widget.ec.searchIsRegex);
              _updateMatches();
            },
          ),

          // Case toggle
          _ToggleBtn(
            icon: Icons.text_fields,
            tooltip: 'Case sensitive',
            active: widget.ec.searchCaseSensitive,
            onTap: () {
              widget.ec.updateSearch(
                caseSensitive: !widget.ec.searchCaseSensitive,
              );
              _updateMatches();
            },
          ),

          // Previous match
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 18),
            tooltip: 'Previous',
            onPressed: _matches.isNotEmpty ? () => _navigate(-1) : null,
            visualDensity: VisualDensity.compact,
          ),

          // Next match
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            tooltip: 'Next',
            onPressed: _matches.isNotEmpty ? () => _navigate(1) : null,
            visualDensity: VisualDensity.compact,
          ),

          // Close
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Close',
            onPressed: widget.ec.hideSearch,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Icon(
            icon,
            size: 16,
            color: active ? AppColors.primary : AppColors.darkBorder,
          ),
        ),
      ),
    );
  }
}

// ── AI Diff banner ────────────────────────────────────────────────────────────

/// Shows a banner when the AI agent has proposed a file change.
///
/// The user can Accept (replaces buffer with proposed content) or
/// Reject (discards the proposal).
///
/// Architecture: 03-AI-AGENT.md §16, FR-030–FR-031
class _DiffBanner extends StatelessWidget {
  const _DiffBanner({required this.ec, required this.codeCtrl});

  final EditorController ec;
  final CodeController codeCtrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primary.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(
            Icons.smart_toy_outlined,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI proposed a change to this file.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.editorForeground,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: ec.rejectDiff,
            child: const Text('Reject', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
            ),
            onPressed: () {
              ec.acceptDiff();
              // Sync CodeController to new content
              final newContent = ec.activeTab?.content ?? '';
              codeCtrl.value = TextEditingValue(
                text: newContent,
                selection: TextSelection.collapsed(offset: newContent.length),
              );
            },
            child: const Text('Accept', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Status bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.ec});
  final EditorController ec;

  @override
  Widget build(BuildContext context) {
    final tab = ec.activeTab;
    final errors = ec.errorCount;
    final warnings = ec.warningCount;

    return Container(
      height: 24,
      color: AppColors.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Diagnostic summary
          if (errors > 0) ...[
            const Icon(Icons.error_outline, size: 13, color: AppColors.error),
            const SizedBox(width: 4),
            Text(
              '$errors',
              style: const TextStyle(fontSize: 11, color: AppColors.error),
            ),
            const SizedBox(width: 8),
          ],
          if (warnings > 0) ...[
            const Icon(
              Icons.warning_amber_outlined,
              size: 13,
              color: AppColors.warning,
            ),
            const SizedBox(width: 4),
            Text(
              '$warnings',
              style: const TextStyle(fontSize: 11, color: AppColors.warning),
            ),
            const SizedBox(width: 8),
          ],
          if (errors == 0 && warnings == 0)
            const Icon(
              Icons.check_circle_outline,
              size: 13,
              color: AppColors.secondary,
            ),

          const Spacer(),

          // Language + encoding
          if (tab != null)
            Text(
              '${tab.language.displayName} · UTF-8',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.editorForeground.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }
}
