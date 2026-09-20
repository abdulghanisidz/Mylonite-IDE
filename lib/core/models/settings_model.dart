import '../constants/app_constants.dart';
import 'enums.dart';

/// Global application settings.
///
/// A single instance is stored at settings/settings.json.
/// Per-project overrides are stored in project.json under a "settings" key.
///
/// Architecture: 07-DATA-MODELS.md §18
class SettingsModel {
  const SettingsModel({
    this.schemaVersion = 1,
    this.activeProviderId = 'local',
    this.networkMode = NetworkMode.auto,
    this.themeMode = AppThemeMode.system,
    this.fontSize = 14,
    this.fontFamily = 'JetBrains Mono',
    this.tabSize = 4,
    this.useSoftTabs = true,
    this.wordWrap = false,
    this.autoSave = true,
    this.showLineNumbers = true,
    this.agentMaxIterations = kDefaultAgentMaxIterations,
    this.confirmationTimeoutSeconds = kDefaultConfirmationTimeoutSeconds,
    this.tokenBudgetMultiplier = kContextBudgetMultiplier,
    this.defaultModelId,
    this.inferenceThreads,
    this.idleUnloadMinutes = kModelIdleUnloadMinutes,
    this.streamingEnabled = true,
    this.defaultPythonVersion,
    this.defaultJsVersion,
    this.executionTimeoutSeconds = kUserExecutionTimeoutSeconds,
    this.logLevel = LogLevel.info,
    this.persistLogsToFile = false,
  });

  final int schemaVersion;

  // AI
  final String activeProviderId;
  final NetworkMode networkMode;
  final String? defaultModelId;
  final int? inferenceThreads; // null = auto-detect from device tier
  final int idleUnloadMinutes;
  final bool streamingEnabled;
  final double tokenBudgetMultiplier;

  // Editor
  final AppThemeMode themeMode;
  final int fontSize;
  final String fontFamily;
  final int tabSize;
  final bool useSoftTabs;
  final bool wordWrap;
  final bool autoSave;
  final bool showLineNumbers;

  // Agent
  final int agentMaxIterations;
  final int confirmationTimeoutSeconds;

  // Runtime
  final String? defaultPythonVersion;
  final String? defaultJsVersion;
  final int executionTimeoutSeconds;

  // Logging
  final LogLevel logLevel;
  final bool persistLogsToFile;

  SettingsModel copyWith({
    int? schemaVersion,
    String? activeProviderId,
    NetworkMode? networkMode,
    AppThemeMode? themeMode,
    int? fontSize,
    String? fontFamily,
    int? tabSize,
    bool? useSoftTabs,
    bool? wordWrap,
    bool? autoSave,
    bool? showLineNumbers,
    int? agentMaxIterations,
    int? confirmationTimeoutSeconds,
    double? tokenBudgetMultiplier,
    String? defaultModelId,
    int? inferenceThreads,
    int? idleUnloadMinutes,
    bool? streamingEnabled,
    String? defaultPythonVersion,
    String? defaultJsVersion,
    int? executionTimeoutSeconds,
    LogLevel? logLevel,
    bool? persistLogsToFile,
  }) {
    return SettingsModel(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      activeProviderId: activeProviderId ?? this.activeProviderId,
      networkMode: networkMode ?? this.networkMode,
      themeMode: themeMode ?? this.themeMode,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      tabSize: tabSize ?? this.tabSize,
      useSoftTabs: useSoftTabs ?? this.useSoftTabs,
      wordWrap: wordWrap ?? this.wordWrap,
      autoSave: autoSave ?? this.autoSave,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      agentMaxIterations: agentMaxIterations ?? this.agentMaxIterations,
      confirmationTimeoutSeconds: confirmationTimeoutSeconds ?? this.confirmationTimeoutSeconds,
      tokenBudgetMultiplier: tokenBudgetMultiplier ?? this.tokenBudgetMultiplier,
      defaultModelId: defaultModelId ?? this.defaultModelId,
      inferenceThreads: inferenceThreads ?? this.inferenceThreads,
      idleUnloadMinutes: idleUnloadMinutes ?? this.idleUnloadMinutes,
      streamingEnabled: streamingEnabled ?? this.streamingEnabled,
      defaultPythonVersion: defaultPythonVersion ?? this.defaultPythonVersion,
      defaultJsVersion: defaultJsVersion ?? this.defaultJsVersion,
      executionTimeoutSeconds: executionTimeoutSeconds ?? this.executionTimeoutSeconds,
      logLevel: logLevel ?? this.logLevel,
      persistLogsToFile: persistLogsToFile ?? this.persistLogsToFile,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'activeProviderId': activeProviderId,
        'networkMode': networkMode.name,
        'themeMode': themeMode.name,
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'tabSize': tabSize,
        'useSoftTabs': useSoftTabs,
        'wordWrap': wordWrap,
        'autoSave': autoSave,
        'showLineNumbers': showLineNumbers,
        'agentMaxIterations': agentMaxIterations,
        'confirmationTimeoutSeconds': confirmationTimeoutSeconds,
        'tokenBudgetMultiplier': tokenBudgetMultiplier,
        'defaultModelId': defaultModelId,
        'inferenceThreads': inferenceThreads,
        'idleUnloadMinutes': idleUnloadMinutes,
        'streamingEnabled': streamingEnabled,
        'defaultPythonVersion': defaultPythonVersion,
        'defaultJsVersion': defaultJsVersion,
        'executionTimeoutSeconds': executionTimeoutSeconds,
        'logLevel': logLevel.name,
        'persistLogsToFile': persistLogsToFile,
      };

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      schemaVersion: (json['schemaVersion'] as int?) ?? 1,
      activeProviderId: (json['activeProviderId'] as String?) ?? 'local',
      networkMode: NetworkMode.values.firstWhere(
        (e) => e.name == json['networkMode'],
        orElse: () => NetworkMode.auto,
      ),
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == json['themeMode'],
        orElse: () => AppThemeMode.system,
      ),
      fontSize: (json['fontSize'] as int?) ?? 14,
      fontFamily: (json['fontFamily'] as String?) ?? 'JetBrains Mono',
      tabSize: (json['tabSize'] as int?) ?? 4,
      useSoftTabs: (json['useSoftTabs'] as bool?) ?? true,
      wordWrap: (json['wordWrap'] as bool?) ?? false,
      autoSave: (json['autoSave'] as bool?) ?? true,
      showLineNumbers: (json['showLineNumbers'] as bool?) ?? true,
      agentMaxIterations: (json['agentMaxIterations'] as int?) ?? kDefaultAgentMaxIterations,
      confirmationTimeoutSeconds:
          (json['confirmationTimeoutSeconds'] as int?) ?? kDefaultConfirmationTimeoutSeconds,
      tokenBudgetMultiplier:
          (json['tokenBudgetMultiplier'] as num?)?.toDouble() ?? kContextBudgetMultiplier,
      defaultModelId: json['defaultModelId'] as String?,
      inferenceThreads: json['inferenceThreads'] as int?,
      idleUnloadMinutes: (json['idleUnloadMinutes'] as int?) ?? kModelIdleUnloadMinutes,
      streamingEnabled: (json['streamingEnabled'] as bool?) ?? true,
      defaultPythonVersion: json['defaultPythonVersion'] as String?,
      defaultJsVersion: json['defaultJsVersion'] as String?,
      executionTimeoutSeconds:
          (json['executionTimeoutSeconds'] as int?) ?? kUserExecutionTimeoutSeconds,
      logLevel: LogLevel.values.firstWhere(
        (e) => e.name == json['logLevel'],
        orElse: () => LogLevel.info,
      ),
      persistLogsToFile: (json['persistLogsToFile'] as bool?) ?? false,
    );
  }
}

/// Theme mode options (wraps Flutter's ThemeMode with serialisable name).
enum AppThemeMode {
  system,
  light,
  dark;

  String get displayName => switch (this) {
        AppThemeMode.system => 'System Default',
        AppThemeMode.light => 'Light',
        AppThemeMode.dark => 'Dark',
      };
}
