import 'package:flutter/services.dart';

/// Memory information returned by [SystemChannel.getMemoryInfo].
class MemoryInfo {
  const MemoryInfo({
    required this.availBytes,
    required this.totalBytes,
    required this.lowMemory,
    required this.thresholdBytes,
  });

  final int availBytes;
  final int totalBytes;
  final bool lowMemory;
  final int thresholdBytes;

  int get availMb => availBytes ~/ (1024 * 1024);
  int get totalMb => totalBytes ~/ (1024 * 1024);

  /// True when available RAM is below the system low-memory threshold.
  bool get isCriticallyLow => lowMemory;
}

/// Thermal status codes mirroring Android's PowerManager.ThermalStatus.
/// Architecture: 05-OFFLINE-AI.md §18.2
enum ThermalStatus {
  none(0),
  light(1),
  moderate(2),
  severe(3),
  critical(4),
  emergency(5),
  shutdown(6);

  const ThermalStatus(this.code);
  final int code;

  static ThermalStatus fromCode(int code) =>
      ThermalStatus.values.firstWhere((s) => s.code == code, orElse: () => ThermalStatus.none);

  /// Whether the application should reduce inference load at this status.
  bool get shouldReduceLoad => index >= ThermalStatus.moderate.index;

  /// Whether inference should be paused immediately.
  bool get shouldPauseInference => index >= ThermalStatus.emergency.index;
}

/// Dart side of the `ide/system` Platform Channel.
///
/// Wraps [SystemChannel.kt] to expose Android system metrics to the
/// application core.
///
/// Architecture: 02-ARCHITECTURE.md §11.1, §4.5, §4.6
class SystemChannel {
  SystemChannel._();
  static final SystemChannel instance = SystemChannel._();

  static const _method = MethodChannel('ide/system');

  /// Query available and total RAM from Android's ActivityManager.
  Future<MemoryInfo> getMemoryInfo() async {
    final result = await _method.invokeMapMethod<String, dynamic>('getMemoryInfo');
    return MemoryInfo(
      availBytes: result?['availBytes'] as int? ?? 0,
      totalBytes: result?['totalBytes'] as int? ?? 0,
      lowMemory: result?['lowMemory'] as bool? ?? false,
      thresholdBytes: result?['thresholdBytes'] as int? ?? 0,
    );
  }

  /// Query the device's current thermal status (API 29+; returns [ThermalStatus.none] below).
  Future<ThermalStatus> getThermalStatus() async {
    final result = await _method.invokeMapMethod<String, dynamic>('getThermalStatus');
    final code = result?['status'] as int? ?? 0;
    return ThermalStatus.fromCode(code);
  }

  /// Returns true when Android's Battery Saver mode is active.
  Future<bool> isPowerSaveMode() async {
    final result = await _method.invokeMapMethod<String, dynamic>('isPowerSaveMode');
    return result?['enabled'] as bool? ?? false;
  }
}
