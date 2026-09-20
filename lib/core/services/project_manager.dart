import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../models/app_error.dart';
import '../models/enums.dart';
import '../models/project_model.dart';
import 'logging_service.dart';
import 'workspace_manager.dart';
import 'zip_service.dart';

/// Manages the collection of user projects stored in app-internal storage.
///
/// Storage layout (Architecture: 07-DATA-MODELS.md §21):
/// ```
///   <appFilesDir>/
///   └── projects/
///       └── <project-id>/
///           ├── project.json    ← ProjectModel metadata
///           └── workspace/      ← User source files
/// ```
///
/// Architecture: 02-ARCHITECTURE.md §ProjectManager, FR-001–FR-009
class ProjectManager {
  ProjectManager._();

  static final ProjectManager instance = ProjectManager._();

  /// The currently active project. Null when no project is open.
  ProjectModel? _activeProject;
  ProjectModel? get activeProject => _activeProject;

  /// In-memory list of all known projects (active + archived).
  final List<ProjectModel> _projects = [];
  List<ProjectModel> get projects => List.unmodifiable(_projects);

  /// Returns all active (non-archived) projects, most-recently-opened first.
  List<ProjectModel> get activeProjects {
    final active =
        _projects.where((p) => p.status == ProjectStatus.active).toList()
          ..sort((a, b) {
            final aDate = a.lastOpenedAt ?? a.createdAt;
            final bDate = b.lastOpenedAt ?? b.createdAt;
            return bDate.compareTo(aDate); // newest first
          });
    return active;
  }

  WorkspaceManager? _activeWorkspace;

  /// The [WorkspaceManager] for [activeProject]. Null if no project is open.
  WorkspaceManager? get activeWorkspace => _activeWorkspace;

  bool _loaded = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Loads all project metadata from disk. Call once at startup.
  Future<void> loadAll() async {
    if (_loaded) return;

    final projectsDir = await _projectsDirectory();
    if (!projectsDir.existsSync()) {
      _loaded = true;
      log.info(LogSubsystem.core, 'ProjectManager: no projects directory yet.');
      return;
    }

    final subdirs = projectsDir.listSync().whereType<Directory>().toList();

    for (final dir in subdirs) {
      final metaFile = File(p.join(dir.path, kProjectMetaFileName));
      if (!metaFile.existsSync()) continue;
      try {
        final json =
            jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
        final project = ProjectModel.fromJson(json);
        _projects.add(project);
        log.debug(
          LogSubsystem.core,
          'Loaded project: ${project.name} (${project.id})',
        );
      } catch (e) {
        log.warn(
          LogSubsystem.core,
          'Failed to parse project.json at ${dir.path}',
          detail: e.toString(),
        );
      }
    }

    _loaded = true;
    log.info(
      LogSubsystem.core,
      'ProjectManager: loaded ${_projects.length} project(s).',
    );
  }

  // ── Create ────────────────────────────────────────────────────────────────

  /// Creates a new project with [name] and [language].
  ///
  /// Produces the directory structure:
  /// ```
  ///   projects/<id>/
  ///     project.json
  ///     workspace/
  /// ```
  /// and writes the default entry-point file.
  Future<Result<ProjectModel>> createProject({
    required String name,
    required Language language,
    String? description,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return Result.err(
        AppError(
          code: 'INVALID_NAME',
          message: 'Project name cannot be empty.',
          subsystem: LogSubsystem.core,
        ),
      );
    }

    final id = const Uuid().v4();
    final projectsDir = await _projectsDirectory();
    final projectDir = Directory(p.join(projectsDir.path, id));
    final workspaceDir = Directory(p.join(projectDir.path, 'workspace'));

    try {
      await workspaceDir.create(recursive: true);
    } catch (e) {
      return Result.err(AppError.unknown(e, LogSubsystem.filesystem));
    }

    final entryPoint = _defaultEntryPoint(language);
    final now = DateTime.now();

    final project = ProjectModel(
      id: id,
      name: trimmed,
      description: description,
      primaryLanguage: language,
      workspacePath: workspaceDir.path,
      createdAt: now,
      lastModifiedAt: now,
      entryPoint: entryPoint,
    );

    // Persist metadata
    final saveResult = await _saveMetadata(project);
    if (saveResult.isErr) return Result.err(saveResult.errorOrNull!);

    // Create the default entry-point file
    final ws = WorkspaceManager.forProject(project);
    if (entryPoint != null) {
      await ws.createFile(entryPoint, _defaultFileContent(language));
    }

    _projects.add(project);
    log.info(
      LogSubsystem.core,
      'Created project "${project.name}" (${project.id})',
    );

    return Result.ok(project);
  }

  // ── Open / Close ──────────────────────────────────────────────────────────

  /// Sets [project] as the active project and stamps [lastOpenedAt].
  Future<Result<WorkspaceManager>> openProject(ProjectModel project) async {
    final updated = project.copyWith(lastOpenedAt: DateTime.now());
    await _saveMetadata(updated);
    _updateInList(updated);

    _activeProject = updated;
    _activeWorkspace = WorkspaceManager.forProject(updated);
    await _activeWorkspace!.ensureRootExists();

    log.info(LogSubsystem.core, 'Opened project: ${updated.name}');
    return Result.ok(_activeWorkspace!);
  }

  /// Closes the active project. The project data is preserved on disk.
  void closeProject() {
    if (_activeProject != null) {
      log.info(LogSubsystem.core, 'Closed project: ${_activeProject!.name}');
    }
    _activeProject = null;
    _activeWorkspace = null;
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Permanently deletes [project] and all its files from disk.
  ///
  /// The caller is responsible for showing a confirmation dialog first
  /// (Architecture: 06-SECURITY.md §10, SEC-004).
  Future<Result<void>> deleteProject(ProjectModel project) async {
    if (_activeProject?.id == project.id) {
      closeProject();
    }

    final projectsDir = await _projectsDirectory();
    final projectDir = Directory(p.join(projectsDir.path, project.id));

    try {
      if (projectDir.existsSync()) {
        await projectDir.delete(recursive: true);
      }
      _projects.removeWhere((p) => p.id == project.id);
      log.info(
        LogSubsystem.core,
        'Deleted project: ${project.name} (${project.id})',
      );
      return Result.ok(null);
    } catch (e) {
      return Result.err(AppError.unknown(e, LogSubsystem.filesystem));
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────

  /// Persists an updated [project] (e.g. after rename).
  Future<Result<void>> updateProject(ProjectModel project) async {
    final result = await _saveMetadata(project);
    if (result.isOk) {
      _updateInList(project);
      if (_activeProject?.id == project.id) {
        _activeProject = project;
      }
    }
    return result;
  }

  // ── Import / Export ───────────────────────────────────────────────────────

  /// Imports a project from a ZIP archive whose bytes are in [zipBytes].
  ///
  /// Creates a new project with [name] and [language], then extracts the
  /// ZIP contents into the new workspace.  The caller must already have
  /// read [zipBytes] from a SAF URI via [StorageChannel].
  Future<Result<ProjectModel>> importProject({
    required String name,
    required Language language,
    required List<int> zipBytes,
  }) async {
    // Create an empty project first (generates the directory layout)
    final createResult = await createProject(name: name, language: language);
    if (createResult.isErr) return Result.err(createResult.errorOrNull!);

    final project = createResult.valueOrNull!;

    // Extract the ZIP into the workspace, overwriting the default entry-point
    final importResult = await ZipService.instance.importZip(
      zipBytes: zipBytes,
      destDir: project.workspacePath,
    );

    if (importResult.isErr) {
      // Roll back the newly created project on failure
      await deleteProject(project);
      return Result.err(importResult.errorOrNull!);
    }

    log.info(
      LogSubsystem.core,
      'Imported project "${project.name}" '
      '(${importResult.valueOrNull!.extractedFiles} files, '
      '${importResult.valueOrNull!.skippedEntries} skipped)',
    );
    return Result.ok(project);
  }

  /// Exports [project]'s workspace to a ZIP and returns the bytes.
  ///
  /// The caller is responsible for writing the bytes to the user's chosen
  /// location via [StorageChannel.writeToUri].
  Future<Result<List<int>>> exportProject(ProjectModel project) async {
    // Write to a temp file then read back — ZipService works with file paths
    final base = await getApplicationSupportDirectory();
    final tmpPath = p.join(base.path, kTmpDir, '${project.id}_export.zip');

    final exportResult = await ZipService.instance.exportWorkspace(
      workspaceDir: project.workspacePath,
      destPath: tmpPath,
    );

    if (exportResult.isErr) return Result.err(exportResult.errorOrNull!);

    try {
      final bytes = await File(tmpPath).readAsBytes();
      // Clean up temp file
      await File(tmpPath).delete().catchError((_) => File(tmpPath));
      log.info(
        LogSubsystem.core,
        'Exported project "${project.name}" (${bytes.length} bytes)',
      );
      return Result.ok(bytes);
    } catch (e) {
      return Result.err(AppError.unknown(e, LogSubsystem.filesystem));
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<Result<void>> _saveMetadata(ProjectModel project) async {
    try {
      final projectsDir = await _projectsDirectory();
      final projectDir = Directory(p.join(projectsDir.path, project.id));
      await projectDir.create(recursive: true);

      final file = File(p.join(projectDir.path, kProjectMetaFileName));
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(project.toJson()),
        flush: true,
      );
      await tmp.rename(file.path);
      return Result.ok(null);
    } catch (e) {
      return Result.err(AppError.unknown(e, LogSubsystem.core));
    }
  }

  void _updateInList(ProjectModel updated) {
    final idx = _projects.indexWhere((p) => p.id == updated.id);
    if (idx >= 0) {
      _projects[idx] = updated;
    }
  }

  Future<Directory> _projectsDirectory() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, kProjectsDir));
  }

  String? _defaultEntryPoint(Language lang) => switch (lang) {
    Language.python => 'main.py',
    Language.javascript => 'index.js',
    Language.typescript => 'index.ts',
    Language.dart => 'main.dart',
    _ => null,
  };

  String _defaultFileContent(Language lang) => switch (lang) {
    Language.python =>
      '# Welcome to your new Python project\n\nprint("Hello, World!")\n',
    Language.javascript => '// Welcome to your new JavaScript project\n\nconsole.log("Hello, World!");\n',
    Language.typescript => '// Welcome to your new TypeScript project\n\nconsole.log("Hello, World!");\n',
    Language.dart => '// Welcome to your new Dart project\n\nvoid main() {\n  print("Hello, World!");\n}\n',
    _ => '',
  };
}
