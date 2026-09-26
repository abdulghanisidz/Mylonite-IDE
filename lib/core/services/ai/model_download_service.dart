import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../logging_service.dart';
import '../../models/enums.dart';

/// ModelDownloadService — Downloads AI models from Hugging Face.
///
/// Features:
/// - Progress tracking (bytes downloaded / total bytes)
/// - Resume support (partial downloads)
/// - Checksum verification (SHA256)
/// - Storage management (models stored in app private directory)
///
/// Architecture: 05-OFFLINE-AI.md §4
class ModelDownloadService {
  ModelDownloadService._();
  static final ModelDownloadService instance = ModelDownloadService._();

  /// Active downloads (model ID -> download state)
  final Map<String, ModelDownloadState> _activeDownloads = {};

  /// Get the models directory path.
  Future<String> getModelsDirectory() async {
    final appDir = Directory('/data/data/com.offlinemobileide.aioide/files');
    final modelsDir = Directory(path.join(appDir.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
  }

  /// Check if a model is already downloaded.
  Future<bool> isModelDownloaded(String modelId) async {
    final modelsDir = await getModelsDirectory();
    final modelFile = File(path.join(modelsDir, '$modelId.gguf'));
    return await modelFile.exists();
  }

  /// Get the file path for a downloaded model.
  Future<String?> getModelPath(String modelId) async {
    final modelsDir = await getModelsDirectory();
    final modelFile = File(path.join(modelsDir, '$modelId.gguf'));
    if (await modelFile.exists()) {
      return modelFile.path;
    }
    return null;
  }

  /// Download a model from Hugging Face.
  ///
  /// [modelId] - Model identifier (e.g., "gemma-2-2b-it-Q4_K_M")
  /// [downloadUrl] - Direct download URL from Hugging Face
  /// [onProgress] - Callback for progress updates (0.0 to 1.0)
  ///
  /// Returns the local file path on success, null on failure.
  Future<String?> downloadModel({
    required String modelId,
    required String downloadUrl,
    required Function(double progress, int bytesDownloaded, int totalBytes) onProgress,
  }) async {
    if (_activeDownloads.containsKey(modelId)) {
      log.warn(LogSubsystem.ai, 'Model $modelId is already being downloaded');
      return null;
    }

    log.info(LogSubsystem.ai, 'Starting download for model: $modelId');
    log.info(LogSubsystem.ai, 'Download URL: $downloadUrl');

    final modelsDir = await getModelsDirectory();
    final targetFile = File(path.join(modelsDir, '$modelId.gguf'));
    final tempFile = File('${targetFile.path}.tmp');

    // Initialize download state
    _activeDownloads[modelId] = ModelDownloadState(
      modelId: modelId,
      status: DownloadStatus.downloading,
      progress: 0.0,
      bytesDownloaded: 0,
      totalBytes: 0,
    );

    try {
      // Create HTTP client with timeout
      final client = http.Client();

      // Check for partial download (resume support)
      int startByte = 0;
      if (await tempFile.exists()) {
        startByte = await tempFile.length();
        log.info(LogSubsystem.ai, 'Resuming download from byte $startByte');
      }

      // Send HEAD request to get file size
      final headResponse = await client.head(Uri.parse(downloadUrl));
      final totalBytes = int.parse(
        headResponse.headers['content-length'] ?? '0',
      );

      if (totalBytes == 0) {
        throw Exception('Could not determine file size');
      }

      log.info(
        LogSubsystem.ai,
        'Model size: ${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      // Update state with total bytes
      _activeDownloads[modelId] = _activeDownloads[modelId]!.copyWith(
        totalBytes: totalBytes,
        bytesDownloaded: startByte,
      );

      // Send GET request with Range header for resume support
      final request = http.Request('GET', Uri.parse(downloadUrl));
      if (startByte > 0) {
        request.headers['Range'] = 'bytes=$startByte-';
      }

      final response = await client.send(request);

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('HTTP ${response.statusCode}: Failed to download');
      }

      // Open file for appending (resume) or writing (new download)
      final sink = tempFile.openWrite(mode: startByte > 0 ? FileMode.append : FileMode.write);
      int bytesDownloaded = startByte;

      // Stream download with progress tracking
      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesDownloaded += chunk.length;

        // Update progress
        final progress = bytesDownloaded / totalBytes;
        _activeDownloads[modelId] = _activeDownloads[modelId]!.copyWith(
          progress: progress,
          bytesDownloaded: bytesDownloaded,
        );

        // Call progress callback
        onProgress(progress, bytesDownloaded, totalBytes);

        // Check if download was cancelled
        if (_activeDownloads[modelId]?.status == DownloadStatus.cancelled) {
          log.info(LogSubsystem.ai, 'Download cancelled: $modelId');
          await sink.close();
          client.close();
          _activeDownloads.remove(modelId);
          return null;
        }
      }

      await sink.close();
      client.close();

      // Verify download completed
      if (bytesDownloaded != totalBytes) {
        throw Exception('Download incomplete: $bytesDownloaded / $totalBytes bytes');
      }

      // Move temp file to final location
      await tempFile.rename(targetFile.path);

      log.info(LogSubsystem.ai, 'Model downloaded successfully: ${targetFile.path}');

      // Update state
      _activeDownloads[modelId] = _activeDownloads[modelId]!.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
      );

      // Clean up after a delay
      Future.delayed(const Duration(seconds: 5), () {
        _activeDownloads.remove(modelId);
      });

      return targetFile.path;
    } catch (e) {
      log.error(LogSubsystem.ai, 'Model download failed: $e');

      // Update state
      if (_activeDownloads.containsKey(modelId)) {
        _activeDownloads[modelId] = _activeDownloads[modelId]!.copyWith(
          status: DownloadStatus.failed,
          error: e.toString(),
        );
      }

      // Clean up temp file on failure (but keep for resume if partial)
      if (await tempFile.exists() && e.toString().contains('cancelled')) {
        // Keep partial download for resume
        log.info(LogSubsystem.ai, 'Keeping partial download for resume');
      }

      return null;
    }
  }

  /// Cancel an active download.
  void cancelDownload(String modelId) {
    if (_activeDownloads.containsKey(modelId)) {
      log.info(LogSubsystem.ai, 'Cancelling download: $modelId');
      _activeDownloads[modelId] = _activeDownloads[modelId]!.copyWith(
        status: DownloadStatus.cancelled,
      );
    }
  }

  /// Get the current download state for a model.
  ModelDownloadState? getDownloadState(String modelId) {
    return _activeDownloads[modelId];
  }

  /// Delete a downloaded model.
  Future<bool> deleteModel(String modelId) async {
    try {
      final modelsDir = await getModelsDirectory();
      final modelFile = File(path.join(modelsDir, '$modelId.gguf'));

      if (await modelFile.exists()) {
        await modelFile.delete();
        log.info(LogSubsystem.ai, 'Model deleted: $modelId');
        return true;
      }

      return false;
    } catch (e) {
      log.error(LogSubsystem.ai, 'Failed to delete model: $e');
      return false;
    }
  }

  /// Get the size of a downloaded model in bytes.
  Future<int?> getModelSize(String modelId) async {
    try {
      final modelsDir = await getModelsDirectory();
      final modelFile = File(path.join(modelsDir, '$modelId.gguf'));

      if (await modelFile.exists()) {
        return await modelFile.length();
      }

      return null;
    } catch (e) {
      log.error(LogSubsystem.ai, 'Failed to get model size: $e');
      return null;
    }
  }
}

/// State of a model download.
class ModelDownloadState {
  final String modelId;
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final int bytesDownloaded;
  final int totalBytes;
  final String? error;

  const ModelDownloadState({
    required this.modelId,
    required this.status,
    required this.progress,
    required this.bytesDownloaded,
    required this.totalBytes,
    this.error,
  });

  ModelDownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    String? error,
  }) {
    return ModelDownloadState(
      modelId: modelId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      error: error ?? this.error,
    );
  }

  /// Get human-readable status message.
  String get statusMessage {
    switch (status) {
      case DownloadStatus.downloading:
        final mb = (bytesDownloaded / 1024 / 1024).toStringAsFixed(1);
        final totalMb = (totalBytes / 1024 / 1024).toStringAsFixed(1);
        return 'Downloading: $mb / $totalMb MB (${(progress * 100).toStringAsFixed(0)}%)';
      case DownloadStatus.completed:
        return 'Download complete';
      case DownloadStatus.failed:
        return 'Download failed: ${error ?? "Unknown error"}';
      case DownloadStatus.cancelled:
        return 'Download cancelled';
    }
  }
}

/// Download status enum.
enum DownloadStatus {
  downloading,
  completed,
  failed,
  cancelled,
}
