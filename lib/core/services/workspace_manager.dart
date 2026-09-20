import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/app_error.dart';
import '../models/enums.dart';
import '../models/project_model.dart';
import 'logging_service.dart';

/// A lightweight description of one file-system entry inside the workspace.
class FileNode {
  const FileNode({
    required this.name,
    required this.relativePath,
    required this.absolutePath,
    required this.isDirectory,
    this.sizeBytes = 0,
    this.children = const [],
  });

  final String name;

  /// Path relative to the workspace root (forward-slash separated).
  final String relativePath;

  final String absolutePath;
  final bool isDirectory;
  final int sizeBytes;

  /// Non-empty only when [isDirectory] is true and the tree has been loaded.
  final List<FileNode> children;

  Language get language => Language.fromExtension(p.extension(name));

  @override
  String toString() => 'FileNode($relativePath, dir=$isDirectory)';
}

/// Manages all file operations for the **active** project workspace.
///
/// Rules enforced here (Architecture: 06-SECURITY.md §4):
///   1. Every path is resolved to absolute and checked to start with
///      [workspaceRoot]. Traversal attempts return [AppError.pathTraversal].
///   2. Symlinks whose resolved target falls outside the workspace are
///      rejected (symlink-escape protection).
///   3. No operation ever touches a path outside [workspaceRoot].
///
/// Architecture: 02-ARCHITECTURE.md §WorkspaceManager, FR-010–FR-019
class WorkspaceManager {
  WorkspaceManager._(this.project);

  /// The project this manager is scoped to.
  final ProjectModel project;

  /// Absolute path to the workspace root directory.
  String get workspaceRoot => project.workspacePath;

  // ── Path validation ───────────────────────────────────────────────────────

  /// Resolves [relativePath] against [workspaceRoot] and validates that
  /// the result stays inside the workspace.
  ///
  /// Returns `Ok(absolutePath)` or `Err(AppError.pathTraversal)`.
  Result<String> resolveSafe(String relativePath) {
    // Normalise to an absolute path without following symlinks yet.
    final joined = p.join(workspaceRoot, relativePath);
    final absolute = p.normalize(joined);

    // Must start with workspaceRoot + separator (prevents prefix-match tricks
    // e.g. /workspace_root_evil matching /workspace_root).
    final root = workspaceRoot.endsWith(p.separator)
        ? workspaceRoot
        : '$workspaceRoot${p.separator}';

    if (!absolute.startsWith(root) && absolute != workspaceRoot) {
      log.warn(
        LogSubsystem.security,
        'PATH_TRAVERSAL blocked',
        detail: 'relative="$relativePath" resolved="$absolute"',
      );
      return Result.err(AppError.pathTraversal(relativePath));
    }

    // Symlink-escape check: if the entry exists and is a link, its real
    // target must also be inside the workspace.
    final entity = FileSystemEntity.typeSync(absolute, followLinks: false);
    if (entity == FileSystemEntityType.link) {
      try {
        final target = Link(absolute).resolveSymbolicLinksSync();
        if (!target.startsWith(root)) {
          log.warn(
            LogSubsystem.security,
            'SYMLINK_ESCAPE blocked',
            detail: 'link="$absolute" target="$target"',
          );
          return Result.err(AppError.pathTraversal(relativePath));
        }
      } catch (_) {
        return Result.err(AppError.pathTraversal(relativePath));
      }
    }

    return Result.ok(absolute);
  }

  // ── File reads ────────────────────────────────────────────────────────────

  /// Reads a text file. Returns its content or an [AppError].
  Future<Result<String>> readFile(String relativePath) async {
    final check = resolveSafe(relativePath);
    if (check.isErr) return Result.err(check.errorOrNull!);
    final path = check.valueOrNull!;

    try {
      final file = File(path);
      if (!file.existsSync()) {
        return Result.err(AppError.fileNotFound(relativePath));
      }
      final stat = file.statSync();
      if (stat.size > 500 * 1024) {
        return Result.err(
          AppError(
            code: 'FILE_TOO_LARGE',
            message: 'File exceeds the 500 KB read limit.',
            subsystem: LogSubsystem.filesystem,
          ),
        );
      }
      final content = await file.readAsString();
      return Result.ok(content);
    } catch (e) {
      return Result.err(AppError.unknown(e, LogSubsystem.filesystem));
    }
  }

  // ── File writes ───────────────────────────────────────────────────────────

  /// Writes [content] to a file, creating parent directories as needed.
  /// Uses atomic write (temp → rename) to prevent partial writes.
  Future<Result<void>> writeFile(String relativePath, String content) async {
    final check = resolveSafe(relativePath);
    if (check.isErr) return Result.err(check.errorOrNull!);
    final path = check.valueOrNull!;

    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      // Atomic write: write to .tmp then rename
      final tmp = File('$path.tmp');
      await tmp.writeAsString(content, flush: true);
      await tmp.rename(path);
      log.debug(
        LogSubsystem.filesystem,
        'writeFile: $relativePath (${content.length} chars)',
      );
      return Result.ok(null);
    } catch (e) {
      return Result.err(AppError.unknown(e, LogSubsystem.filesystem));
    }
  }

  /// Creates a new file. Fails if it already exists.
  Future<Result<void>> createFile(String relativePath, String content) async {
    final check = resolveSafe(relativePath);
    if (check.isErr) return Result.err(check.errorOrNull!);
    final path = check.valueOrNull!;

    final file = File(path);
    if (file.existsSync()) {
      return Result.err(
        AppError(
          code: 'FILE_EXISTS',
          message: 'File already exists: $relativePath',
          subsystem: LogSubsystem.filesystem,
        ),
      );
    }
    return writeFile(relativePath, content);
  }

  /// Deletes a file.
  Future<Result<void>> deleteFile(String relativePath) async {
    final check = resolveSafe(relativePath);
    if (check.isErr) return Result.err(check.errorOrNull!);
    final path = check.valueOrNull!;

    try {
      final file = File(path);
      if (!file.existsSync()) {
        return Result.err(AppError.fileNotFound(relativePath));
      }
      await file.delete();
      log.debug(LogSubsystem.filesystem, 'deleteFile: $relativePath');
      return Result.ok(null);
    } catch (e) {
      return Result.err(AppError.unknown(e, LogSubsystem.filesystem));
    }
  }

  /// Renames or moves a file within the workspace.
  Future<Result<void>> renameFile(
    String fromRelative,
    String toRelative,
  ) async {
    final fromCheck = resolveSafe(fromRelative);
    final toCheck = resolveSafe(toRelative);
    if (fromCheck.isErr) return Result.err(fromCheck.errorOrNull!);
    if (toCheck.isErr) return Result.err(toCheck.errorOrNull!);

    try {
      final from = File(fromCheck.valueOrNull!);
      if (!from.existsSync()) {
        return Result.err(AppError.fileNotFound(fromRelative));
      }
      final dest = File(toCheck.valueOrNull!);
      if (dest.existsSync()) {
        return Result.err(
          AppError(
            code: 'DESTINATION_EXISTS',
            message: 'A file already exists at: $toRelative',
            subsystem: LogSubsystem.filesystem,
          ),
        );
      }
      await dest.parent.create(recursive: true);
      await from.rename(dest.path);
      log.debug(
        LogSubsystem.filesystem,
        'renameFile: $fromRelative → $toRelative',
      );
      return Result.ok(null);
    } catch (e) {
      return Result.err(AppError.unknown(e, LogSubsystem.filesystem));
    }
  }

  // ── Directory operations ─────────────────────────────────────────────────

  /// Creates a directory (and all parents) within the workspace.
  Future<Result<void>> createDirectory(String relativePath) async {
    final check = resolveSafe(relativePath);
    if (check.isErr) return Result.err(check.errorOrNull!);
    try {
      await Directory(check.valueOrNull!).create(recursive: true);
      return Result.ok(null);
    } catch (e) {
      return Result.err(AppError.unknown(e, LogSubsystem.filesystem));
    }
  }

  /// Deletes a directory and all its contents.
  Future<Result<void>> deleteDirectory(String relativePath) async {
    final check = resolveSafe(relativePath);
    if (check.isErr) return Result.err(check.errorOrNull!);
    final path = check.valueOrNull!;

    // Never allow deleting the workspace root itself
    if (p.normalize(path) == p.normalize(workspaceRoot)) {
      return Result.err(
        AppError(
          code: 'CANNOT_DELETE_ROOT',
          message: 'Cannot delete the project root directory.',
          subsystem: LogSubsystem.filesystem,
        ),
      );
    }

    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        return Result.err(AppError.fileNotFound(relativePath));
      }
      await dir.delete(recursive: true);
      log.debug(LogSubsystem.filesystem, 'deleteDirectory: $relativePath');
      return Result.ok(null);
    } catch (e) {
      return Result.err(AppError.unknown(e, LogSubsystem.filesystem));
    }
  }

  // ── Directory listing ─────────────────────────────────────────────────────

  /// Lists one level of the workspace root (non-recursive).
  Future<Result<List<FileNode>>> listRoot() => listDirectory('');

  /// Lists the contents of [relativePath] (one level, non-recursive).
  Future<Result<List<FileNode>>> listDirectory(String relativePath) async {
    final check = resolveSafe(relativePath.isEmpty ? '.' : relativePath);
    if (check.isErr) {
      // Empty relative path means root — just use workspaceRoot
      if (relativePath.isEmpty) {
        return _listAbsolute(workspaceRoot, '');
      }
      return Result.err(check.errorOrNull!);
    }
    return _listAbsolute(check.valueOrNull!, relativePath);
  }

  Future<Result<List<FileNode>>> _listAbsolute(
    String absoluteDir,
    String relativeDir,
  ) async {
    try {
      final dir = Directory(absoluteDir);
      if (!dir.existsSync()) {
        return Result.err(AppError.fileNotFound(relativeDir));
      }
      final entries = dir.listSync(followLinks: false)
        ..sort((a, b) {
          // Directories first, then alphabetical
          final aDir = a is Directory ? 0 : 1;
          final bDir = b is Directory ? 0 : 1;
          if (aDir != bDir) return aDir - bDir;
          return p.basename(a.path).compareTo(p.basename(b.path));
        });

      final nodes = <FileNode>[];
      for (final entity in entries) {
        // Skip hidden files/dirs (dot-prefixed)
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;

        final isDir = entity is Directory;
        final rel = relativeDir.isEmpty ? name : '$relativeDir/$name';
        final stat = entity.statSync();

        nodes.add(
          FileNode(
            name: name,
            relativePath: rel,
            absolutePath: entity.path,
            isDirectory: isDir,
            sizeBytes: isDir ? 0 : stat.size,
          ),
        );
      }
      return Result.ok(nodes);
    } catch (e) {
      return Result.err(AppError.unknown(e, LogSubsystem.filesystem));
    }
  }

  /// Recursively builds the full file tree up to [maxDepth].
  Future<List<FileNode>> buildTree({int maxDepth = 5}) async {
    return _buildTreeRecursive('', 0, maxDepth);
  }

  Future<List<FileNode>> _buildTreeRecursive(
    String relativeDir,
    int depth,
    int maxDepth,
  ) async {
    final result = await listDirectory(relativeDir);
    if (result.isErr) return [];

    final nodes = <FileNode>[];
    for (final node in result.valueOrNull!) {
      if (node.isDirectory && depth < maxDepth) {
        final children = await _buildTreeRecursive(
          node.relativePath,
          depth + 1,
          maxDepth,
        );
        nodes.add(
          FileNode(
            name: node.name,
            relativePath: node.relativePath,
            absolutePath: node.absolutePath,
            isDirectory: true,
            children: children,
          ),
        );
      } else {
        nodes.add(node);
      }
    }
    return nodes;
  }

  // ── File watcher ─────────────────────────────────────────────────────────
  //
  // Android does not expose a reliable inotify / FSEvents API to normal
  // apps for their internal storage. We poll instead.
  //
  // Architecture: 02-ARCHITECTURE.md §9.3 — polling every 30 s when
  // backgrounded; every 5 s when the Explorer is in the foreground.
  //
  // The stream fires `null` (void signal) whenever a change is detected.
  // Consumers (e.g. rootFilesProvider) invalidate their cache on each event.

  StreamController<void>? _watchController;
  Timer? _watchTimer;

  /// A broadcast stream that emits whenever the workspace contents change.
  ///
  /// Returns a new stream each time [startWatching] is called.
  Stream<void> get changes => _watchController?.stream ?? const Stream.empty();

  /// Tracks the last-known modification stamp of the workspace root.
  DateTime? _lastModified;

  /// Starts polling the workspace root for changes.
  ///
  /// [interval] controls how often we check (default: 5 seconds while the
  /// Explorer is visible; callers should pass 30 s when backgrounded).
  void startWatching({Duration interval = const Duration(seconds: 5)}) {
    stopWatching(); // cancel any existing watcher first

    _watchController = StreamController<void>.broadcast();
    _lastModified = _rootModifiedAt();

    _watchTimer = Timer.periodic(interval, (_) => _pollForChanges());
    log.debug(
      LogSubsystem.filesystem,
      'File watcher started (${interval.inSeconds}s interval): $workspaceRoot',
    );
  }

  /// Stops the polling timer and closes the change stream.
  void stopWatching() {
    _watchTimer?.cancel();
    _watchTimer = null;
    _watchController?.close();
    _watchController = null;
    log.debug(LogSubsystem.filesystem, 'File watcher stopped.');
  }

  /// Polls the workspace root modification time. Fires [changes] if it
  /// has changed since the last check.
  void _pollForChanges() {
    final current = _rootModifiedAt();
    if (current != null && current != _lastModified) {
      _lastModified = current;
      log.debug(
        LogSubsystem.filesystem,
        'Workspace change detected: $workspaceRoot',
      );
      _watchController?.add(null);
    }
  }

  /// Returns the most-recent modification time across all entries in the
  /// workspace root (one level only — deep recursion is too expensive for
  /// a polling loop on a mobile device).
  DateTime? _rootModifiedAt() {
    try {
      final dir = Directory(workspaceRoot);
      if (!dir.existsSync()) return null;

      DateTime? latest;
      for (final entity in dir.listSync(followLinks: false)) {
        final modified = entity.statSync().modified;
        if (latest == null || modified.isAfter(latest)) {
          latest = modified;
        }
      }
      // Also include the directory itself
      final dirModified = dir.statSync().modified;
      if (latest == null || dirModified.isAfter(latest)) {
        latest = dirModified;
      }
      return latest;
    } catch (_) {
      return null;
    }
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  /// Returns true if [relativePath] exists inside the workspace.
  bool exists(String relativePath) {
    final check = resolveSafe(relativePath);
    if (check.isErr) return false;
    return FileSystemEntity.typeSync(check.valueOrNull!) !=
        FileSystemEntityType.notFound;
  }

  /// Ensures the workspace root directory exists, creating it if necessary.
  Future<void> ensureRootExists() async {
    await Directory(workspaceRoot).create(recursive: true);
  }

  // ── Factory ───────────────────────────────────────────────────────────────

  static WorkspaceManager forProject(ProjectModel project) =>
      WorkspaceManager._(project);
}
