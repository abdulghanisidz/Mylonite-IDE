import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../ui/theme/app_theme.dart';

/// Runtime Manager screen — install, view, and remove language runtimes.
///
/// Phase 1: Shell with static placeholder runtime entries.
/// Phase 5: Wired to RuntimeManager for Python runtime.
/// Phase 6: Wired to RuntimeManager for JavaScript runtime.
///
/// Architecture: 04-RUNTIME-SYSTEM.md §12, FR-043–FR-055
class RuntimeManagerScreen extends StatelessWidget {
  const RuntimeManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Runtime Manager')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _RuntimeCard(
            language: 'Python',
            version: '3.12.4',
            architecture: 'arm64-v8a',
            storageLabel: '~75 MB',
            status: RuntimeStatus.notInstalled,
          ),
          SizedBox(height: 12),
          _RuntimeCard(
            language: 'JavaScript',
            version: 'QuickJS 2024.01',
            architecture: 'arm64-v8a',
            storageLabel: '~3 MB',
            status: RuntimeStatus.notInstalled,
          ),
        ],
      ),
    );
  }
}

class _RuntimeCard extends StatelessWidget {
  const _RuntimeCard({
    required this.language,
    required this.version,
    required this.architecture,
    required this.storageLabel,
    required this.status,
  });

  final String language;
  final String version;
  final String architecture;
  final String storageLabel;
  final RuntimeStatus status;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status) {
      RuntimeStatus.available => AppColors.secondary,
      RuntimeStatus.notInstalled => AppColors.editorForeground.withValues(
        alpha: 0.4,
      ),
      RuntimeStatus.installing => AppColors.primary,
      RuntimeStatus.running => AppColors.secondary,
      RuntimeStatus.healthCheckFailed || RuntimeStatus.error => AppColors.error,
    };

    final statusLabel = switch (status) {
      RuntimeStatus.available => 'Installed',
      RuntimeStatus.notInstalled => 'Not installed',
      RuntimeStatus.installing => 'Installing...',
      RuntimeStatus.running => 'Running',
      RuntimeStatus.healthCheckFailed => 'Health check failed',
      RuntimeStatus.error => 'Error',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  language == 'Python' ? Icons.code : Icons.javascript,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  language,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow('Version', version),
            _InfoRow('Architecture', architecture),
            _InfoRow('Storage', storageLabel),
            const SizedBox(height: 12),
            Row(
              children: [
                if (status == RuntimeStatus.notInstalled)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Install'),
                    onPressed: null,
                  ),
                if (status == RuntimeStatus.available) ...[
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.health_and_safety_outlined,
                      size: 16,
                    ),
                    label: const Text('Health Check'),
                    onPressed: null,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    onPressed: null,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
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
