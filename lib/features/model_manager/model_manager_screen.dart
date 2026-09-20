import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../ui/theme/app_theme.dart';

/// Model Manager screen — download, import, activate, and delete AI models.
///
/// Phase 1: Shell with static placeholder model entries.
/// Phase 9: Wired to ModelManager and LocalAIProvider.
///
/// Architecture: 05-OFFLINE-AI.md §14, FR-076–FR-082
class ModelManagerScreen extends StatelessWidget {
  const ModelManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open_outlined),
            tooltip: 'Import model from storage',
            onPressed: null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _StorageSummaryCard(),
          const SizedBox(height: 16),
          Text(
            'RECOMMENDED MODELS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          const _ModelCard(
            name: 'Qwen2.5-Coder 1.5B',
            family: 'Qwen2.5',
            quantization: ModelQuantization.q4_k_m,
            profile: ModelProfile.tiny,
            fileSizeMb: 940,
            estimatedRamMb: 1100,
            contextLength: 4096,
            isActive: false,
            isInstalled: false,
          ),
          const SizedBox(height: 12),
          const _ModelCard(
            name: 'Qwen2.5-Coder 3B',
            family: 'Qwen2.5',
            quantization: ModelQuantization.q4_k_m,
            profile: ModelProfile.balanced,
            fileSizeMb: 1900,
            estimatedRamMb: 2200,
            contextLength: 8192,
            isActive: false,
            isInstalled: false,
          ),
          const SizedBox(height: 12),
          const _ModelCard(
            name: 'Phi-3 Mini 4K',
            family: 'Phi-3',
            quantization: ModelQuantization.q4_k_m,
            profile: ModelProfile.balanced,
            fileSizeMb: 2200,
            estimatedRamMb: 2600,
            contextLength: 4096,
            isActive: false,
            isInstalled: false,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StorageSummaryCard extends StatelessWidget {
  const _StorageSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.storage_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Model Storage',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '0 models installed · 0 MB used',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.name,
    required this.family,
    required this.quantization,
    required this.profile,
    required this.fileSizeMb,
    required this.estimatedRamMb,
    required this.contextLength,
    required this.isActive,
    required this.isInstalled,
  });

  final String name;
  final String family;
  final ModelQuantization quantization;
  final ModelProfile profile;
  final int fileSizeMb;
  final int estimatedRamMb;
  final int contextLength;
  final bool isActive;
  final bool isInstalled;

  @override
  Widget build(BuildContext context) {
    final profileColor = switch (profile) {
      ModelProfile.tiny => AppColors.secondary,
      ModelProfile.balanced => AppColors.primary,
      ModelProfile.power => AppColors.warning,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$family · ${quantization.label}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: profileColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    profile.displayName,
                    style: TextStyle(color: profileColor, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _StatChip(Icons.save_outlined, '$fileSizeMb MB'),
                _StatChip(Icons.memory_outlined, '~$estimatedRamMb MB RAM'),
                _StatChip(Icons.wrap_text, '${contextLength ~/ 1024}K context'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!isInstalled)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: Text('Download · $fileSizeMb MB'),
                    onPressed: null,
                  ),
                if (isInstalled && !isActive) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_circle_outline, size: 16),
                    label: const Text('Activate'),
                    onPressed: null,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    onPressed: null,
                  ),
                ],
                if (isActive)
                  Chip(
                    avatar: const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                    label: const Text('Active'),
                    backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
                    side: const BorderSide(color: AppColors.secondary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
