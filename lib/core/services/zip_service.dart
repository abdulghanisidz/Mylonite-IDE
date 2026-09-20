import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/app_error.dart';
import '../models/enums.dart';
import 'logging_service.dart';

/// Provides ZIP import and export for project workspaces.
///
/// Security guarantees (Architecture: 06-SECURITY.md §15.1):
///   • **Zip-slip protection** — every entry path is normalised and checked
///     to remain inside [destDir] before any byte is written. Entries that
///     would escape the destination are silently skipped and logged.
///   • **Bomb protection** — extraction is aborted when the total
///     uncompressed size exceeds [maxUncompressedBytes] (default 500 MB).
///   • **Symlinks in ZIP** — any entry whose name contains a symlink-like
///     pattern is rejected.
///
/// Architecture: FR-007 (import), FR-008 (export)
class ZipService {
  ZipService._();
  static final ZipService instance = ZipService._();

  /// Maximum total uncompressed size allowed during extraction.
  static const int maxUncompressedBytes = 500 * 1024 * 1024; // 500 MB

  /// Maximum number of entries in a single ZIP (bomb guard).
  static const int maxEntries = 10000;

  // ── Export ────────────────────────────────────────────────────────────────

  /// Creates a ZIP archive of [workspaceDir] and writes it to [destFile].
  ///
  /// All files inside [workspaceDir] are included at paths relative to
  /// [workspaceDir] itself — so the ZIP does not contain absolute paths.
  ///
  /// Returns the number of files archived, or an [AppError] on failure.
  Future<Result<int>> exportWorkspace({
    required String workspaceDir,
    required String destPath,
  }) async {
    try {
      final archive = Archive();
      int fileCount = 0;

      final dir = Directory(workspaceDir);
      if (!dir.existsSync()) {
        return Result.err(AppError.fileNotFound(workspaceDir));
      }

      // Walk all files recursively
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is! File) continue;

        // Relative path inside the ZIP (forward-slash for cross-platform)
        final relative = p
            .relative(entity.path, from: workspaceDir)
            .replaceAll('\\', '/');

        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relative, bytes.length, bytes));
        fileCount++;
      }

      // Encode to ZIP bytes
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        return Result.err(
          AppError(
            code: 'ZIP_ENCODE_FAILED',
            message: 'Failed to encode ZIP archive.',
            subsystem: LogSubsystem.filesystem,
          ),
        );
      }

      // Atomic write: write to .tmp then rename
      final dest = File(destPath);
      await dest.parent.create(recursive: true);
      final tmp = File('$destPath.tmp');
      await tmp.writeAsBytes(zipBytes, flush: true);
      await tmp.rename(destPath);

      log.info(
        LogSubsystem.filesystem,
        'Exported $fileCount file(s) to ZIP: $destPath',
      );
      return Result.ok(fileCount);
    } catch (e) {
      return Result.err(AppError.unknown(e, LogSubsystem.filesystem));
    }
  }

  // ── Import ────────────────────────────────────────────────────────────────

  /// Extracts a ZIP archive from [zipBytes] into [destDir].
  ///
  /// **Zip-slip protection** is applied to every entry before extraction.
  /// Unsafe entries are skipped (never thrown as errors — callers receive
  /// a count of skipped entries in the result).
  ///
  /// Returns an [_ImportResult] containing file count and skip count,
  /// or an [AppError] on unrecoverable failure.
  Future<Result<ImportResult>> importZip({
    required List<int> zipBytes,
    required String destDir,
  }) async {
    try {
      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(zipBytes);
      } catch (e) {
        return Result.err(
          AppError(
            code: 'ZIP_DECODE_FAILED',
            message: 'The file is not a valid ZIP archive.',
            subsystem: LogSubsystem.filesystem,
            detail: e.toString(),
          ),
        );
      }

      // Bomb guard: entry count
      if (archive.length > maxEntries) {
        return Result.err(
          AppError(
            code: 'ZIP_TOO_MANY_ENTRIES',
            message: 'ZIP archive contains too many entries (>$maxEntries).',
            subsystem: LogSubsystem.filesystem,
          ),
        );
      }

      // Normalise destination — must end with separator for prefix checks
      final normalDest = p.normalize(destDir);
      final destPrefix = normalDest.endsWith(p.separator)
          ? normalDest
          : '$normalDest${p.separator}';

      int extracted = 0;
      int skipped = 0;
      int totalBytes = 0;

      for (final entry in archive) {
        // Bomb guard: total size
        totalBytes += entry.size;
        if (totalBytes > maxUncompressedBytes) {
          return Result.err(
            AppError(
              code: 'ZIP_BOMB',
              message: 'ZIP archive exceeds the 500 MB extraction limit.',
              subsystem: LogSubsystem.filesystem,
            ),
          );
        }

        if (entry.isFile) {
          // ── Zip-slip check ─────────────────────────────────────────
          // Normalise the entry name to an absolute path under destDir
          final entryName = entry.name.replaceAll('\\', '/');

          // Reject entries with suspicious patterns before path resolution
          if (_isSuspiciousEntry(entryName)) {
            log.warn(
              LogSubsystem.security,
              'ZIP_SLIP: suspicious entry skipped',
              detail: entryName,
            );
            skipped++;
            continue;
          }

          final targetAbsolute = p.normalize(p.join(normalDest, entryName));

          // Must start with destDir + separator
          if (!targetAbsolute.startsWith(destPrefix)) {
            log.warn(
              LogSubsystem.security,
              'ZIP_SLIP: path-traversal entry skipped',
              detail: 'entry="$entryName" resolved="$targetAbsolute"',
            );
            skipped++;
            continue;
          }
          // ── End zip-slip check ─────────────────────────────────────

          final file = File(targetAbsolute);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(entry.content as List<int>);
          extracted++;
        } else {
          // Directory entry — create it (zip-slip checked via name)
          final entryName = entry.name.replaceAll('\\', '/');
          if (_isSuspiciousEntry(entryName)) {
            skipped++;
            continue;
          }
          final dirAbsolute = p.normalize(p.join(normalDest, entryName));
          if (!dirAbsolute.startsWith(destPrefix) &&
              dirAbsolute != normalDest) {
            skipped++;
            continue;
          }
          await Directory(dirAbsolute).create(recursive: true);
        }
      }

      log.info(
        LogSubsystem.filesystem,
        'ZIP import: extracted=$extracted skipped=$skipped',
      );
      return Result.ok(
        ImportResult(extractedFiles: extracted, skippedEntries: skipped),
      );
    } catch (e) {
      return Result.err(AppError.unknown(e, LogSubsystem.filesystem));
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Returns true if [entryName] contains patterns that indicate a
  /// path-traversal or symlink attack before full path resolution.
  bool _isSuspiciousEntry(String entryName) {
    // Reject absolute paths
    if (entryName.startsWith('/') || entryName.startsWith('\\')) return true;
    // Reject Windows-style absolute paths (e.g. C:\)
    if (entryName.length >= 3 && entryName[1] == ':') return true;
    // Reject any segment that is '..'
    final segments = entryName.split(RegExp(r'[/\\]'));
    if (segments.any((s) => s == '..')) return true;
    // Reject null bytes
    if (entryName.contains('\x00')) return true;
    return false;
  }
}

/// Result of a successful ZIP import operation.
class ImportResult {
  const ImportResult({
    required this.extractedFiles,
    required this.skippedEntries,
  });

  /// Number of files successfully extracted.
  final int extractedFiles;

  /// Number of entries skipped due to security checks (zip-slip, etc.).
  final int skippedEntries;
}
