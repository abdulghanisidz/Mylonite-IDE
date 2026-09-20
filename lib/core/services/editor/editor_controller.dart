import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/app_error.dart';
import '../../models/enums.dart';
import '../logging_service.dart';
import '../workspace_manager.dart';

// ── Diagnostic ────────────────────────────────────────────────────────────────

/// A single error or warning attached to a source file.
/// Architecture: 07-DATA-MODELS.md §17
class Diagnostic {
  const Diagnostic({
    required this.relativePath,
    required this.severity,
    required this.message,
    required this.source,
    this.line,
    this.column,
  });

  final String relativePath;
  final DiagnosticSeverity severity;
  final String message;
  final DiagnosticSource source;
  final int? line; // 1-indexed
  final int? column; // 1-indexed

  @override
  String toString() =>
      '[$severity] $relativePath${line != null ? ':$line' : ''} — $message';
}

// ── Search match ──────────────────────────────────────────────────────────────

/// A character-offset range for a search match inside a file buffer.
class SearchMatch {
  const SearchMatch({required this.start, required this.end});
  final int start;
  final int end;
}

// ── Undo/Redo entry ───────────────────────────────────────────────────────────

class _HistoryEntry {
  const _HistoryEntry({required this.content, required this.cursorOffset});
  final String content;
  final int cursorOffset;
}

// ── Editor tab ────────────────────────────────────────────────────────────────

/// Represents one open file tab with its in-memory buffer state.
class EditorTab {
  EditorTab({required this.relativePath, required String initialContent})
    : _buffer = initialContent,
      _savedContent = initialContent,
      _history = [_HistoryEntry(content: initialContent, cursorOffset: 0)],
      _historyIndex = 0;

  final String relativePath;

  String _buffer;
  String _savedContent;
  final List<_HistoryEntry> _history;
  int _historyIndex;

  String get content => _buffer;
  bool get isDirty => _buffer != _savedContent;
  String get name => relativePath.split('/').last;
  Language get language => Language.fromExtension(
    relativePath.contains('.') ? '.${relativePath.split('.').last}' : '',
  );

  // Buffer mutation
  void updateContent(String newContent, {int cursorOffset = 0}) {
    if (newContent == _buffer) return;
    _buffer = newContent;
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(
      _HistoryEntry(content: newContent, cursorOffset: cursorOffset),
    );
    if (_history.length > 200) _history.removeAt(0);
    _historyIndex = _history.length - 1;
  }

  // Undo / Redo
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  String? undo() {
    if (!canUndo) return null;
    _historyIndex--;
    _buffer = _history[_historyIndex].content;
    return _buffer;
  }

  String? redo() {
    if (!canRedo) return null;
    _historyIndex++;
    _buffer = _history[_historyIndex].content;
    return _buffer;
  }

  // Persistence
  void markSaved() => _savedContent = _buffer;

  void reload(String content) {
    _buffer = content;
    _savedContent = content;
    _history
      ..clear()
      ..add(_HistoryEntry(content: content, cursorOffset: 0));
    _historyIndex = 0;
  }
}

// ── EditorController ──────────────────────────────────────────────────────────

/// Central controller for the Mylonite IDE code editor.
///
/// Manages open tabs, buffer mutations, undo/redo, save/load via
/// [WorkspaceManager], diagnostics, AI diff proposals, and in-file search.
///
/// Architecture: 02-ARCHITECTURE.md §EditorController, FR-020–FR-033
class EditorController extends ChangeNotifier {
  EditorController({required WorkspaceManager workspace})
    : _workspace = workspace;

  final WorkspaceManager _workspace;

  // ── Tabs ──────────────────────────────────────────────────────────────────

  final List<EditorTab> _tabs = [];
  int _activeIndex = -1;

  List<EditorTab> get tabs => List.unmodifiable(_tabs);
  int get activeIndex => _activeIndex;

  EditorTab? get activeTab => _activeIndex >= 0 && _activeIndex < _tabs.length
      ? _tabs[_activeIndex]
      : null;

  // ── Diagnostics ───────────────────────────────────────────────────────────

  final Map<String, List<Diagnostic>> _diagnostics = {};

  List<Diagnostic> diagnosticsFor(String relativePath) =>
      List.unmodifiable(_diagnostics[relativePath] ?? []);

  List<Diagnostic> get allDiagnostics =>
      _diagnostics.values.expand((d) => d).toList();

  int get errorCount => allDiagnostics
      .where((d) => d.severity == DiagnosticSeverity.error)
      .length;

  int get warningCount => allDiagnostics
      .where((d) => d.severity == DiagnosticSeverity.warning)
      .length;

  // ── Pending AI diff ───────────────────────────────────────────────────────

  String? _pendingDiff;
  String? get pendingDiff => _pendingDiff;
  bool get hasPendingDiff => _pendingDiff != null;

  // ── Search ────────────────────────────────────────────────────────────────

  bool _searchVisible = false;
  String _searchQuery = '';
  bool _searchIsRegex = false;
  bool _searchCaseSensitive = false;

  bool get searchVisible => _searchVisible;
  String get searchQuery => _searchQuery;
  bool get searchIsRegex => _searchIsRegex;
  bool get searchCaseSensitive => _searchCaseSensitive;

  // ── Open / Close tabs ─────────────────────────────────────────────────────

  Future<Result<EditorTab>> openFile(String relativePath) async {
    final existing = _tabs.indexWhere((t) => t.relativePath == relativePath);
    if (existing >= 0) {
      await _switchTo(existing);
      return Result.ok(_tabs[existing]);
    }

    final readResult = await _workspace.readFile(relativePath);
    if (readResult.isErr) return Result.err(readResult.errorOrNull!);

    if (activeTab?.isDirty == true) await _saveActiveTab();

    final tab = EditorTab(
      relativePath: relativePath,
      initialContent: readResult.valueOrNull!,
    );
    _tabs.add(tab);
    _activeIndex = _tabs.length - 1;
    notifyListeners();
    log.debug(LogSubsystem.filesystem, 'Editor: opened $relativePath');
    return Result.ok(tab);
  }

  Future<void> switchTab(int index) async {
    if (index == _activeIndex || index < 0 || index >= _tabs.length) return;
    if (activeTab?.isDirty == true) await _saveActiveTab();
    await _switchTo(index);
  }

  Future<void> _switchTo(int index) async {
    _activeIndex = index;
    _pendingDiff = null;
    _searchVisible = false;
    notifyListeners();
  }

  Future<void> closeTab(int index) async {
    if (index < 0 || index >= _tabs.length) return;
    final tab = _tabs[index];
    if (tab.isDirty) {
      await _workspace.writeFile(tab.relativePath, tab.content);
      tab.markSaved();
    }
    _tabs.removeAt(index);
    if (_tabs.isEmpty) {
      _activeIndex = -1;
    } else if (_activeIndex >= _tabs.length) {
      _activeIndex = _tabs.length - 1;
    } else if (_activeIndex > index) {
      _activeIndex--;
    }
    _pendingDiff = null;
    notifyListeners();
    log.debug(LogSubsystem.filesystem, 'Editor: closed ${tab.relativePath}');
  }

  // ── Buffer mutations ──────────────────────────────────────────────────────

  void onContentChanged(String newContent, {int cursorOffset = 0}) {
    activeTab?.updateContent(newContent, cursorOffset: cursorOffset);
    notifyListeners();
  }

  // ── Undo / Redo ───────────────────────────────────────────────────────────

  String? undo() {
    final result = activeTab?.undo();
    if (result != null) notifyListeners();
    return result;
  }

  String? redo() {
    final result = activeTab?.redo();
    if (result != null) notifyListeners();
    return result;
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<Result<void>> saveActive() => _saveActiveTab();

  Future<void> saveAll() async {
    for (final tab in _tabs) {
      if (tab.isDirty) {
        final r = await _workspace.writeFile(tab.relativePath, tab.content);
        if (r.isOk) tab.markSaved();
      }
    }
    notifyListeners();
  }

  Future<Result<void>> _saveActiveTab() async {
    final tab = activeTab;
    if (tab == null || !tab.isDirty) return Result.ok(null);
    final result = await _workspace.writeFile(tab.relativePath, tab.content);
    if (result.isOk) {
      tab.markSaved();
      notifyListeners();
      log.debug(LogSubsystem.filesystem, 'Editor: saved ${tab.relativePath}');
    }
    return result;
  }

  // ── Diagnostics ───────────────────────────────────────────────────────────

  void applyDiagnostics(String relativePath, List<Diagnostic> diagnostics) {
    if (diagnostics.isEmpty) {
      _diagnostics.remove(relativePath);
    } else {
      _diagnostics[relativePath] = List.unmodifiable(diagnostics);
    }
    notifyListeners();
  }

  void clearDiagnostics(String relativePath) {
    _diagnostics.remove(relativePath);
    notifyListeners();
  }

  void clearAllDiagnostics() {
    _diagnostics.clear();
    notifyListeners();
  }

  // ── AI diff ───────────────────────────────────────────────────────────────

  void proposeDiff(String proposedContent) {
    if (activeTab == null) return;
    _pendingDiff = proposedContent;
    notifyListeners();
    log.debug(LogSubsystem.agent, 'Editor: diff proposed');
  }

  void acceptDiff() {
    final tab = activeTab;
    final diff = _pendingDiff;
    if (tab == null || diff == null) return;
    tab.updateContent(diff);
    _pendingDiff = null;
    notifyListeners();
    log.debug(LogSubsystem.agent, 'Editor: diff accepted');
  }

  void rejectDiff() {
    _pendingDiff = null;
    notifyListeners();
    log.debug(LogSubsystem.agent, 'Editor: diff rejected');
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void showSearch() {
    _searchVisible = true;
    notifyListeners();
  }

  void hideSearch() {
    _searchVisible = false;
    _searchQuery = '';
    notifyListeners();
  }

  void updateSearch({String? query, bool? isRegex, bool? caseSensitive}) {
    if (query != null) _searchQuery = query;
    if (isRegex != null) _searchIsRegex = isRegex;
    if (caseSensitive != null) _searchCaseSensitive = caseSensitive;
    notifyListeners();
  }

  /// Returns all match ranges for the current search query in [content].
  List<SearchMatch> findMatches(String content) {
    if (_searchQuery.isEmpty) return [];
    try {
      final pattern = _searchIsRegex
          ? RegExp(
              _searchQuery,
              caseSensitive: _searchCaseSensitive,
              multiLine: true,
            )
          : RegExp(
              RegExp.escape(_searchQuery),
              caseSensitive: _searchCaseSensitive,
            );
      return pattern
          .allMatches(content)
          .map((m) => SearchMatch(start: m.start, end: m.end))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> onAppBackground() => saveAll();

  @override
  void dispose() {
    for (final tab in _tabs) {
      if (tab.isDirty) {
        _workspace.writeFile(tab.relativePath, tab.content);
      }
    }
    super.dispose();
  }
}
