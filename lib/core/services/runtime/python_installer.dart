import 'dart:io';

import 'package:path/path.dart' as path;

import '../logging_service.dart';
import '../../models/enums.dart';

/// PythonInstaller — Downloads and installs Python for Android.
///
/// For the hackathon MVP, we'll use a pragmatic approach:
/// 1. Try to use system Python first (Termux, if installed)
/// 2. If not available, guide user to install Termux
/// 3. Future: Bundle Python ARM64 binary in assets or download it
///
/// Python for Android options:
/// - Termux Python (best, already compiled, ~75MB)
/// - Python-for-Android (Kivy project)
/// - Chaquopy (commercial, not suitable)
/// - Custom cross-compilation (too complex for MVP)
///
/// Architecture: 04-RUNTIME-SYSTEM.md §3
class PythonInstaller {
  PythonInstaller._();
  static final PythonInstaller instance = PythonInstaller._();

  /// Installation status
  bool _isInstalling = false;

  /// Check if Python is available via common paths.
  ///
  /// Checks (in order):
  /// 1. System PATH via 'which' command (works with Termux) - BEST
  /// 2. Direct python3/python execution test
  /// 3. App's private storage (for bundled Python)
  /// 4. Termux installation paths (may fail due to permissions)
  Future<PythonInstallationInfo> detect() async {
    log.info(LogSubsystem.runtime, 'Detecting Python installation...');

    // Method 1: Check if python3 is in PATH (WORKS WITH TERMUX!)
    try {
      log.debug(LogSubsystem.runtime, 'Checking PATH: which python3');
      final whichResult = await Process.run('sh', [
        '-c',
        'which python3',
      ], runInShell: false).timeout(const Duration(seconds: 3));

      if (whichResult.exitCode == 0) {
        final pythonPath = whichResult.stdout.toString().trim();
        if (pythonPath.isNotEmpty) {
          log.info(LogSubsystem.runtime, 'Found Python in PATH: $pythonPath');

          // Get version
          final version = await _getPythonVersion('python3');

          return PythonInstallationInfo(
            available: true,
            executable: 'python3', // Use command name, not full path
            version: version,
            source: PythonSource.system,
          );
        }
      }
    } catch (e) {
      log.debug(LogSubsystem.runtime, 'which command failed: $e');
    }

    // Method 2: Try executing python3 directly
    try {
      log.debug(LogSubsystem.runtime, 'Trying direct: python3 --version');
      final result = await Process.run('python3', [
        '--version',
      ], runInShell: false).timeout(const Duration(seconds: 3));

      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        log.info(LogSubsystem.runtime, 'Python3 command works: $version');

        return PythonInstallationInfo(
          available: true,
          executable: 'python3',
          version: version,
          source: PythonSource.system,
        );
      }
    } catch (e) {
      log.debug(LogSubsystem.runtime, 'Direct python3 failed: $e');
    }

    // Method 3: Check app's private storage
    final appPythonPath = await _getAppPythonPath();
    if (await _testPythonExecutable(appPythonPath)) {
      log.info(
        LogSubsystem.runtime,
        'Found Python in app storage: $appPythonPath',
      );
      return PythonInstallationInfo(
        available: true,
        executable: appPythonPath,
        version: await _getPythonVersion(appPythonPath),
        source: PythonSource.bundled,
      );
    }

    // Method 4: Try Termux paths (likely to fail due to Android sandboxing)
    const termuxPython = '/data/data/com.termux/files/usr/bin/python3';
    if (await _testPythonExecutable(termuxPython)) {
      log.info(LogSubsystem.runtime, 'Found Termux Python: $termuxPython');
      return PythonInstallationInfo(
        available: true,
        executable: termuxPython,
        version: await _getPythonVersion(termuxPython),
        source: PythonSource.termux,
      );
    }

    // Method 5: Check system PATH (fallback)
    for (final name in ['python']) {
      if (await _testPythonExecutable(name)) {
        log.info(LogSubsystem.runtime, 'Found system Python: $name');
        return PythonInstallationInfo(
          available: true,
          executable: name,
          version: await _getPythonVersion(name),
          source: PythonSource.system,
        );
      }
    }

    log.warn(LogSubsystem.runtime, 'No Python installation detected');
    log.info(
      LogSubsystem.runtime,
      'Install Termux from F-Droid, then run: pkg install python',
    );

    return PythonInstallationInfo(
      available: false,
      executable: null,
      version: null,
      source: null,
    );
  }

  /// Test if a Python executable works.
  Future<bool> _testPythonExecutable(String executable) async {
    try {
      final result = await Process.run(executable, [
        '--version',
      ], runInShell: false).timeout(const Duration(seconds: 3));
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Get Python version string.
  Future<String?> _getPythonVersion(String executable) async {
    try {
      final result = await Process.run(executable, [
        '--version',
      ], runInShell: false).timeout(const Duration(seconds: 3));
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (e) {
      log.debug(LogSubsystem.runtime, 'Failed to get Python version: $e');
    }
    return null;
  }

  /// Get path where app should store its own Python installation.
  Future<String> _getAppPythonPath() async {
    // Use app's private files directory
    final appDir = Directory('/data/data/com.offlinemobileide.aioide/files');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return path.join(appDir.path, 'python', 'bin', 'python3');
  }

  /// Install Python (placeholder for future implementation).
  ///
  /// For MVP/hackathon: Guide user to install Termux instead.
  /// Future: Download and extract Python ARM64 binary.
  Future<bool> install({
    required Function(double progress, String status) onProgress,
  }) async {
    if (_isInstalling) {
      log.warn(LogSubsystem.runtime, 'Python installation already in progress');
      return false;
    }

    _isInstalling = true;
    try {
      onProgress(0.1, 'Preparing installation...');

      // For MVP: This is a placeholder
      // Real implementation would:
      // 1. Download Python ARM64 tarball from GitHub releases
      // 2. Extract to app's private storage
      // 3. Set permissions
      // 4. Create wrapper script

      await Future.delayed(const Duration(seconds: 1));
      onProgress(0.5, 'Installation not yet implemented');

      log.info(
        LogSubsystem.runtime,
        'Python installation not yet implemented. User should install Termux.',
      );

      return false;
    } catch (e) {
      log.error(LogSubsystem.runtime, 'Python installation failed: $e');
      return false;
    } finally {
      _isInstalling = false;
    }
  }

  /// Get installation instructions for the user.
  String getInstallationInstructions() {
    return '''
# How to Get Python for Mylonite IDE

## Option 1: Install Termux (Recommended for Hackathon)

1. Install Termux from F-Droid: https://f-droid.org/en/packages/com.termux/
   (Google Play version is outdated and won't work)

2. Open Termux and run:
   pkg update && pkg install python

3. Restart Mylonite IDE

Termux provides a full Python 3.12+ environment with pip support.

## Option 2: Wait for Bundled Python (Coming Soon)

We're working on bundling Python directly with the app so you won't need Termux.
This will be available in the next update.

## Why Termux?

Android doesn't include Python by default. Termux is a terminal emulator that provides
a Linux environment with Python, pip, and other development tools.

## Verification

Once Termux is installed, go to Settings → Runtime Manager to verify Python is detected.
''';
  }
}

/// Information about detected Python installation.
class PythonInstallationInfo {
  final bool available;
  final String? executable;
  final String? version;
  final PythonSource? source;

  const PythonInstallationInfo({
    required this.available,
    required this.executable,
    required this.version,
    required this.source,
  });

  @override
  String toString() {
    if (!available) return 'PythonInstallationInfo(available: false)';
    return 'PythonInstallationInfo(available: true, executable: $executable, '
        'version: $version, source: $source)';
  }
}

/// Source of Python installation.
enum PythonSource {
  system, // System PATH
  termux, // Termux installation
  bundled, // Bundled with app
}
