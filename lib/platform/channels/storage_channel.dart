import 'package:flutter/services.dart';

/// Dart side of the `ide/storage` Platform Channel.
///
/// Wraps Android SAF operations for project import/export.
/// All user-file access outside app-internal storage MUST go through this
/// channel — never via direct filesystem paths.
///
/// Architecture: 02-ARCHITECTURE.md §9.2, 06-SECURITY.md §20.2
///
/// TODO (Phase 2): Implement full SAF integration in StorageChannel.kt.
class StorageChannel {
  StorageChannel._();
  static final StorageChannel instance = StorageChannel._();

  static const _method = MethodChannel('ide/storage');

  /// Opens the system file picker filtered to [mimeType].
  /// Returns the selected file URI, or null if the user cancelled.
  Future<String?> openFilePicker({String mimeType = '*/*'}) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'openFilePicker',
      {'mimeType': mimeType},
    );
    return result?['uri'] as String?;
  }

  /// Opens the system directory picker.
  /// Returns the selected directory URI, or null if the user cancelled.
  Future<String?> openDirectoryPicker() async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'openDirectoryPicker',
    );
    return result?['uri'] as String?;
  }

  /// Reads the bytes at [uri] (a content:// URI from SAF).
  Future<List<int>?> readFromUri(String uri) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'readFromUri',
      {'uri': uri},
    );
    final bytes = result?['bytes'];
    if (bytes == null) return null;
    return List<int>.from(bytes as List);
  }

  /// Writes [bytes] to [uri].
  Future<bool> writeToUri(String uri, List<int> bytes) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'writeToUri',
      {'uri': uri, 'bytes': bytes},
    );
    return result?['success'] as bool? ?? false;
  }

  /// Takes a persistable URI permission so the URI survives app restarts.
  /// See OQ-010 in 02-ARCHITECTURE.md.
  Future<bool> takePersistablePermission(String uri) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'takePersistablePermission',
      {'uri': uri},
    );
    return result?['success'] as bool? ?? false;
  }
}
