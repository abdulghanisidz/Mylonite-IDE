import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../models/enums.dart';
import '../models/settings_model.dart';
import 'logging_service.dart';

/// Manages loading and persisting [SettingsModel] to/from
/// `settings/settings.json` in app-internal storage.
///
/// - Settings are loaded once at startup and cached in memory.
/// - Writes are atomic: write to `.tmp` then rename.
/// - The LoggingService is configured from loaded settings.
///
/// Architecture: 07-DATA-MODELS.md §18, 02-ARCHITECTURE.md §SettingsService
class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  SettingsModel _settings = const SettingsModel();
  bool _loaded = false;

  /// The current settings. Returns defaults until [load] has been called.
  SettingsModel get current => _settings;

  bool get isLoaded => _loaded;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Loads settings from disk. Must be called once at app startup.
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> load() async {
    if (_loaded) return;

    final file = await _settingsFile();
    if (!file.existsSync()) {
      log.info(LogSubsystem.settings, 'No settings file found — using defaults.');
      _loaded = true;
      _applyToLogger(_settings);
      return;
    }

    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      _settings = SettingsModel.fromJson(json);
      _loaded = true;
      log.info(LogSubsystem.settings, 'Settings loaded (schema v${_settings.schemaVersion}).');
      _applyToLogger(_settings);
    } catch (e) {
      log.error(
        LogSubsystem.settings,
        'Failed to load settings — using defaults.',
        exception: e,
      );
      _settings = const SettingsModel();
      _loaded = true;
      _applyToLogger(_settings);
    }
  }

  /// Updates settings and persists atomically.
  Future<bool> save(SettingsModel updated) async {
    _settings = updated;
    _applyToLogger(updated);

    try {
      final file = await _settingsFile();
      await _writeAtomic(file, jsonEncode(updated.toJson()));
      log.debug(LogSubsystem.settings, 'Settings saved.');
      return true;
    } catch (e) {
      log.error(LogSubsystem.settings, 'Failed to save settings.', exception: e);
      return false;
    }
  }

  /// Convenience helper: apply a single field change and persist.
  Future<bool> update(SettingsModel Function(SettingsModel s) updater) {
    return save(updater(_settings));
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<File> _settingsFile() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, kSettingsDir));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File(p.join(dir.path, kSettingsFileName));
  }

  /// Write-to-temp-then-rename for atomicity.
  /// Architecture: 06-SECURITY.md §8.4 — file write atomicity
  Future<void> _writeAtomic(File target, String content) async {
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(target.path);
  }

  void _applyToLogger(SettingsModel s) {
    log.minimumLevel = s.logLevel;
    log.persistToFile = s.persistLogsToFile;
  }
}
