import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../core/models/settings_model.dart';
import '../../core/services/settings_service.dart';
import '../../ui/theme/app_theme.dart';

/// Settings screen.
///
/// Phase 1: Displays live settings from SettingsService and persists changes.
/// Phase 8+: Adds AI provider configuration and API key entry.
///
/// Architecture: 07-DATA-MODELS.md §18, FR-088–FR-090
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsModel _settings;

  @override
  void initState() {
    super.initState();
    _settings = SettingsService.instance.current;
  }

  Future<void> _update(SettingsModel Function(SettingsModel s) updater) async {
    final updated = updater(_settings);
    setState(() => _settings = updated);
    await SettingsService.instance.save(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Editor ──────────────────────────────────────────────────
          const _SectionHeader('Editor'),
          _SettingTile(
            title: 'Font Size',
            subtitle: '${_settings.fontSize} sp',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: _settings.fontSize > 10
                      ? () =>
                            _update((s) => s.copyWith(fontSize: s.fontSize - 1))
                      : null,
                ),
                Text(
                  '${_settings.fontSize}',
                  style: const TextStyle(fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: _settings.fontSize < 24
                      ? () =>
                            _update((s) => s.copyWith(fontSize: s.fontSize + 1))
                      : null,
                ),
              ],
            ),
          ),
          _SwitchTile(
            title: 'Show Line Numbers',
            value: _settings.showLineNumbers,
            onChanged: (v) => _update((s) => s.copyWith(showLineNumbers: v)),
          ),
          _SwitchTile(
            title: 'Auto-Save',
            subtitle: 'Save files when navigating away',
            value: _settings.autoSave,
            onChanged: (v) => _update((s) => s.copyWith(autoSave: v)),
          ),
          _SwitchTile(
            title: 'Word Wrap',
            value: _settings.wordWrap,
            onChanged: (v) => _update((s) => s.copyWith(wordWrap: v)),
          ),
          _SwitchTile(
            title: 'Use Soft Tabs',
            subtitle: 'Insert spaces instead of tab characters',
            value: _settings.useSoftTabs,
            onChanged: (v) => _update((s) => s.copyWith(useSoftTabs: v)),
          ),

          // ── Appearance ──────────────────────────────────────────────
          const _SectionHeader('Appearance'),
          _DropdownTile<AppThemeMode>(
            title: 'Theme',
            value: _settings.themeMode,
            items: AppThemeMode.values
                .map(
                  (m) => DropdownMenuItem(value: m, child: Text(m.displayName)),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) _update((s) => s.copyWith(themeMode: v));
            },
          ),

          // ── AI ──────────────────────────────────────────────────────
          const _SectionHeader('AI'),
          _DropdownTile<NetworkMode>(
            title: 'Network Mode',
            subtitle: 'Controls which AI providers are available',
            value: _settings.networkMode,
            items: NetworkMode.values
                .map(
                  (m) => DropdownMenuItem(value: m, child: Text(m.displayName)),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) _update((s) => s.copyWith(networkMode: v));
            },
          ),
          const _SettingTile(
            title: 'Active AI Provider',
            subtitle: 'local',
            trailing: Icon(Icons.chevron_right),
          ),
          _SettingTile(
            title: 'Active Model',
            subtitle: 'None selected',
            trailing: const Icon(Icons.chevron_right),
          ),
          _SwitchTile(
            title: 'Streaming Output',
            subtitle: 'Show AI response tokens as they arrive',
            value: _settings.streamingEnabled,
            onChanged: (v) => _update((s) => s.copyWith(streamingEnabled: v)),
          ),

          // ── Agent ────────────────────────────────────────────────────
          const _SectionHeader('Agent'),
          _SettingTile(
            title: 'Max Iterations',
            subtitle: '${_settings.agentMaxIterations} iterations per session',
            trailing: const Icon(Icons.chevron_right),
          ),
          _SettingTile(
            title: 'Confirmation Timeout',
            subtitle: '${_settings.confirmationTimeoutSeconds}s',
            trailing: const Icon(Icons.chevron_right),
          ),

          // ── Runtime ──────────────────────────────────────────────────
          const _SectionHeader('Runtime'),
          _SettingTile(
            title: 'Execution Timeout',
            subtitle: '${_settings.executionTimeoutSeconds}s (user-initiated)',
            trailing: const Icon(Icons.chevron_right),
          ),

          // ── Privacy ──────────────────────────────────────────────────
          const _SectionHeader('Privacy'),
          const _SettingTile(
            title: 'Analytics',
            subtitle: 'Disabled — no data is collected',
            trailing: Icon(Icons.lock_outline, size: 18),
          ),

          // ── About ────────────────────────────────────────────────────
          const _SectionHeader('About'),
          const _SettingTile(
            title: 'Version',
            subtitle: '0.1.0 · Mylonite IDE · Phase 3',
          ),
          const _SettingTile(
            title: 'Architecture Docs',
            subtitle: 'docs/ directory in project root',
            trailing: Icon(Icons.open_in_new, size: 16),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Reusable tile widgets ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.5),
              ),
            )
          : null,
      trailing: trailing,
      dense: true,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.5),
              ),
            )
          : null,
      value: value,
      onChanged: onChanged,
      // activeThumbColor replaces deprecated activeColor (Flutter 3.31+)
      activeThumbColor: AppColors.primary,
      dense: true,
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.5),
              ),
            )
          : null,
      trailing: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        underline: const SizedBox(),
        style: const TextStyle(fontSize: 13, color: AppColors.primary),
        dropdownColor: AppColors.darkSurfaceVariant,
      ),
      dense: true,
    );
  }
}
