import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/ai_model.dart';
import '../../core/services/ai/model_download_service.dart';
import '../../core/services/ai/inference_service.dart';
import '../../ui/theme/app_theme.dart';

/// Model Manager screen — download, view, and manage AI models.
///
/// Phase 1: Shell with static placeholder entries.
/// Phase 9: Wired to ModelDownloadService and InferenceService. ✅ DONE
///
/// Architecture: 05-OFFLINE-AI.md §8, FR-056–FR-068
class ModelManagerScreen extends ConsumerStatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  ConsumerState<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends ConsumerState<ModelManagerScreen> {
  final _downloadService = ModelDownloadService.instance;
  final _inferenceService = InferenceService.instance;

  // Track download states
  final Map<String, ModelDownloadState> _downloadStates = {};

  @override
  void initState() {
    super.initState();
    _checkInstalledModels();
  }

  /// Check which models are already downloaded.
  Future<void> _checkInstalledModels() async {
    for (final model in AvailableModels.all) {
      final isInstalled = await _downloadService.isModelDownloaded(model.id);
      if (isInstalled && mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Models'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                _checkInstalledModels();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<bool>>(
        future: Future.wait(
          AvailableModels.all.map(
            (m) => _downloadService.isModelDownloaded(m.id),
          ),
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final installedStates = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: AvailableModels.all.length,
            itemBuilder: (context, index) {
              final model = AvailableModels.all[index];
              final isInstalled = installedStates[index];
              final downloadState = _downloadStates[model.id];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ModelCard(
                  model: model,
                  isInstalled: isInstalled,
                  downloadState: downloadState,
                  onDownload: () => _downloadModel(model),
                  onCancel: () => _cancelDownload(model),
                  onDelete: () => _deleteModel(model),
                  onLoad: () => _loadModel(model),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Download a model.
  Future<void> _downloadModel(AIModel model) async {
    if (_downloadStates.containsKey(model.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${model.name} is already downloading')),
      );
      return;
    }

    // Confirm download
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Model'),
        content: Text(
          'Download ${model.name}?\n\n'
          'Size: ${model.fileSizeFormatted}\n'
          'RAM Required: ${model.minRamMB} MB',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Start download
    setState(() {
      _downloadStates[model.id] = ModelDownloadState(
        modelId: model.id,
        status: DownloadStatus.downloading,
        progress: 0.0,
        bytesDownloaded: 0,
        totalBytes: model.fileSizeBytes,
      );
    });

    final result = await _downloadService.downloadModel(
      modelId: model.id,
      downloadUrl: model.downloadUrl,
      onProgress: (progress, downloaded, total) {
        if (mounted) {
          setState(() {
            _downloadStates[model.id] = ModelDownloadState(
              modelId: model.id,
              status: DownloadStatus.downloading,
              progress: progress,
              bytesDownloaded: downloaded,
              totalBytes: total,
            );
          });
        }
      },
    );

    if (result != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${model.name} downloaded successfully'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        setState(() {
          _downloadStates.remove(model.id);
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download ${model.name}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        setState(() {
          _downloadStates.remove(model.id);
        });
      }
    }
  }

  /// Cancel a download.
  void _cancelDownload(AIModel model) {
    _downloadService.cancelDownload(model.id);
    setState(() {
      _downloadStates.remove(model.id);
    });
  }

  /// Delete a model.
  Future<void> _deleteModel(AIModel model) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text(
          'Delete ${model.name}?\n\n'
          'This will free ${model.fileSizeFormatted} of storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _downloadService.deleteModel(model.id);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${model.name} deleted')));
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete ${model.name}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// Load a model for inference.
  Future<void> _loadModel(AIModel model) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading ${model.name}...'),
          ],
        ),
      ),
    );

    final success = await _inferenceService.loadModel(model.id);

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${model.name} loaded and ready'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load ${model.name}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.isInstalled,
    required this.downloadState,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
    required this.onLoad,
  });

  final AIModel model;
  final bool isInstalled;
  final ModelDownloadState? downloadState;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    final isDownloading = downloadState?.status == DownloadStatus.downloading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.memory, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        model.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(context),
              ],
            ),

            const SizedBox(height: 12),

            // Model info
            _InfoRow('Size', model.fileSizeFormatted),
            _InfoRow('Quantization', model.quantization),
            _InfoRow(
              'Context',
              '${model.capabilities.maxContextLength} tokens',
            ),
            _InfoRow('Min RAM', '${model.minRamMB} MB'),

            // Download progress
            if (isDownloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: downloadState!.progress,
                backgroundColor: AppColors.darkSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                downloadState!.statusMessage,
                style: const TextStyle(fontSize: 11),
              ),
            ],

            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                if (!isInstalled && !isDownloading)
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download'),
                      onPressed: onDownload,
                    ),
                  ),
                if (isDownloading) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('Cancel'),
                      onPressed: onCancel,
                    ),
                  ),
                ],
                if (isInstalled) ...[
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Load Model'),
                      onPressed: onLoad,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    if (downloadState?.status == DownloadStatus.downloading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'DOWNLOADING',
          style: TextStyle(color: AppColors.primary, fontSize: 11),
        ),
      );
    }

    if (isInstalled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'INSTALLED',
          style: TextStyle(color: AppColors.secondary, fontSize: 11),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('NOT INSTALLED', style: TextStyle(fontSize: 11)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
