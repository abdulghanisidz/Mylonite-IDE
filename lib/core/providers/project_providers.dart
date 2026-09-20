import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/project_model.dart';
import '../services/editor/editor_controller.dart';
import '../services/project_manager.dart';
import '../services/workspace_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Initialisation
// ─────────────────────────────────────────────────────────────────────────────

/// Loads all projects from disk exactly once.
/// Consumed by [projectListProvider] via [ref.watch].
final projectManagerInitProvider = FutureProvider<void>((ref) async {
  await ProjectManager.instance.loadAll();
});

// ─────────────────────────────────────────────────────────────────────────────
// Project list
// ─────────────────────────────────────────────────────────────────────────────

/// Reactive list of all active projects, sorted most-recently-opened first.
///
/// UI rebuilds automatically whenever a project is created, opened, or deleted.
final projectListProvider =
    StateNotifierProvider<_ProjectListNotifier, List<ProjectModel>>((ref) {
      // Wait for the initial load to complete before surfacing data.
      ref.watch(projectManagerInitProvider);
      return _ProjectListNotifier();
    });

class _ProjectListNotifier extends StateNotifier<List<ProjectModel>> {
  _ProjectListNotifier() : super(ProjectManager.instance.activeProjects);

  // ── CRUD helpers called by the UI layer ───────────────────────────────────

  Future<ProjectModel?> createProject({
    required String name,
    required Language language,
    String? description,
  }) async {
    final result = await ProjectManager.instance.createProject(
      name: name,
      language: language,
      description: description,
    );
    _refresh();
    return result.valueOrNull;
  }

  Future<bool> openProject(ProjectModel project) async {
    final result = await ProjectManager.instance.openProject(project);
    _refresh();
    return result.isOk;
  }

  Future<bool> deleteProject(ProjectModel project) async {
    final result = await ProjectManager.instance.deleteProject(project);
    _refresh();
    return result.isOk;
  }

  /// Imports a project from [zipBytes]. Returns the new project or null on failure.
  Future<ProjectModel?> importProject({
    required String name,
    required Language language,
    required List<int> zipBytes,
  }) async {
    final result = await ProjectManager.instance.importProject(
      name: name,
      language: language,
      zipBytes: zipBytes,
    );
    _refresh();
    return result.valueOrNull;
  }

  /// Exports [project] to ZIP bytes. Returns null on failure.
  Future<List<int>?> exportProject(ProjectModel project) async {
    final result = await ProjectManager.instance.exportProject(project);
    return result.valueOrNull;
  }

  void _refresh() {
    state = List.of(ProjectManager.instance.activeProjects);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active project
// ─────────────────────────────────────────────────────────────────────────────

/// The currently open project. Null when no project is open.
final activeProjectProvider = StateProvider<ProjectModel?>((ref) {
  return ProjectManager.instance.activeProject;
});

// ─────────────────────────────────────────────────────────────────────────────
// Workspace file tree
// ─────────────────────────────────────────────────────────────────────────────

/// The [WorkspaceManager] for the active project. Null if no project is open.
final workspaceManagerProvider = Provider<WorkspaceManager?>((ref) {
  // Rebuild whenever the active project changes.
  final project = ref.watch(activeProjectProvider);
  if (project == null) return null;
  return WorkspaceManager.forProject(project);
});

/// The full recursive file tree for the active workspace.
///
/// Returns an empty list while no project is open or while loading.
final fileTreeProvider = FutureProvider.autoDispose<List<FileNode>>((
  ref,
) async {
  final ws = ref.watch(workspaceManagerProvider);
  if (ws == null) return [];
  return ws.buildTree();
});

/// Flat list of [FileNode]s at the workspace root (one level only).
/// Used by the Explorer screen for the immediate children view.
final rootFilesProvider = FutureProvider.autoDispose<List<FileNode>>((
  ref,
) async {
  final ws = ref.watch(workspaceManagerProvider);
  if (ws == null) return [];
  final result = await ws.listRoot();
  return result.valueOrNull ?? [];
});

// ─────────────────────────────────────────────────────────────────────────────
// File watcher
// ─────────────────────────────────────────────────────────────────────────────

/// Starts the file watcher for the active workspace and re-invalidates
/// [rootFilesProvider] on every detected change.
///
/// Lifecycle: the provider is autoDispose — the watcher stops automatically
/// when no widget is listening (e.g. when the Explorer is not on screen).
///
/// Architecture: 02-ARCHITECTURE.md §9.3
final workspaceWatcherProvider = StreamProvider.autoDispose<void>((ref) {
  final ws = ref.watch(workspaceManagerProvider);
  if (ws == null) return const Stream.empty();

  ws.startWatching();

  // Each change event invalidates the file list so the Explorer rebuilds.
  // We subscribe here rather than using ref.listen(workspaceWatcherProvider)
  // to avoid the self-referential cycle that causes a compile-time error.
  final subscription = ws.changes.listen((_) {
    ref.invalidate(rootFilesProvider);
  });

  ref.onDispose(() {
    subscription.cancel();
    ws.stopWatching();
  });

  return ws.changes;
});

// ─────────────────────────────────────────────────────────────────────────────
// Editor
// ─────────────────────────────────────────────────────────────────────────────

/// The [EditorController] for the active workspace.
///
/// autoDispose: controller is discarded when no widget is watching it
/// (e.g. when the user navigates away from the editor entirely).
/// It saves dirty tabs before disposal via its [dispose] override.
final editorControllerProvider =
    ChangeNotifierProvider.autoDispose<EditorController?>((ref) {
      final ws = ref.watch(workspaceManagerProvider);
      if (ws == null) return null;
      return EditorController(workspace: ws);
    });
