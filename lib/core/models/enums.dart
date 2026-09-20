/// Shared enums across all subsystems.
///
/// Architecture: 07-DATA-MODELS.md — enum values referenced in every model.
library;

// ── Language ──────────────────────────────────────────────────────────────

/// Supported programming languages.
enum Language {
  python,
  javascript,
  typescript,
  dart,
  markdown,
  json,
  text,
  other;

  String get displayName => switch (this) {
    Language.python => 'Python',
    Language.javascript => 'JavaScript',
    Language.typescript => 'TypeScript',
    Language.dart => 'Dart',
    Language.markdown => 'Markdown',
    Language.json => 'JSON',
    Language.text => 'Plain Text',
    Language.other => 'Other',
  };

  /// Common file extensions for this language.
  List<String> get extensions => switch (this) {
    Language.python => ['py', 'pyw'],
    Language.javascript => ['js', 'mjs', 'cjs'],
    Language.typescript => ['ts', 'tsx'],
    Language.dart => ['dart'],
    Language.markdown => ['md', 'markdown'],
    Language.json => ['json'],
    Language.text => ['txt'],
    Language.other => [],
  };

  static Language fromExtension(String ext) {
    final lower = ext.toLowerCase().replaceFirst('.', '');
    for (final lang in Language.values) {
      if (lang.extensions.contains(lower)) return lang;
    }
    return Language.other;
  }
}

// ── Runtime ───────────────────────────────────────────────────────────────

/// Runtime operational status.
/// Architecture: 04-RUNTIME-SYSTEM.md §3.4
enum RuntimeStatus {
  available,
  notInstalled,
  installing,
  healthCheckFailed,
  running,
  error;

  bool get isUsable => this == RuntimeStatus.available;
}

// ── Agent ─────────────────────────────────────────────────────────────────

/// Agent session lifecycle states.
/// Architecture: 03-AI-AGENT.md §3.1
enum AgentSessionStatus {
  idle,
  initializing,
  analyzing,
  planning,
  acting,
  waitingConfirmation,
  observing,
  evaluating,
  fixing,
  validating,
  complete,
  cancelled,
  error;

  bool get isTerminal =>
      this == AgentSessionStatus.complete ||
      this == AgentSessionStatus.cancelled ||
      this == AgentSessionStatus.error;

  bool get isActive => !isTerminal && this != AgentSessionStatus.idle;
}

/// Roles for messages within an agent session.
/// Architecture: 07-DATA-MODELS.md §12
enum MessageRole { user, assistant, system, toolCall, toolResult }

/// Tool execution result statuses.
/// Architecture: 07-DATA-MODELS.md §14
enum ToolResultStatus {
  success,
  error,
  rejectedByUser,
  timeout,
  parseError,
  toolNotFound,
  toolNotPermitted,
  pathTraversal,
  validationError,
}

/// Tool permission levels.
/// Architecture: 03-AI-AGENT.md §9.1
enum ToolPermission { safe, needsConfirmation, restricted }

// ── AI Provider ───────────────────────────────────────────────────────────

/// AI provider types.
/// Architecture: 03-AI-AGENT.md §17.2
enum AIProviderType { local, gemini, openAI, custom }

/// AI provider availability status.
enum AIProviderStatus { ready, notReady, loading, error }

/// Network mode controlling which AI providers are permitted.
/// Architecture: 02-ARCHITECTURE.md (PRD §26)
enum NetworkMode {
  offline,
  online,
  auto;

  String get displayName => switch (this) {
    NetworkMode.offline => 'Offline',
    NetworkMode.online => 'Online',
    NetworkMode.auto => 'Auto',
  };
}

// ── AI Model ──────────────────────────────────────────────────────────────

/// Quantization format for GGUF models.
/// Architecture: 05-OFFLINE-AI.md §5.2
// ignore: constant_identifier_names
enum ModelQuantization {
  f32,
  f16,
  q8_0,
  // ignore: constant_identifier_names
  q4_k_m,
  // ignore: constant_identifier_names
  q4_k_s,
  // ignore: constant_identifier_names
  q3_k_m,
  // ignore: constant_identifier_names
  q2_k,
  // ignore: constant_identifier_names
  iq4_xs,
  other;

  String get label => switch (this) {
    ModelQuantization.f32 => 'F32',
    ModelQuantization.f16 => 'F16',
    ModelQuantization.q8_0 => 'Q8_0',
    ModelQuantization.q4_k_m => 'Q4_K_M',
    ModelQuantization.q4_k_s => 'Q4_K_S',
    ModelQuantization.q3_k_m => 'Q3_K_M',
    ModelQuantization.q2_k => 'Q2_K',
    ModelQuantization.iq4_xs => 'IQ4_XS',
    ModelQuantization.other => 'Other',
  };
}

/// Device tier profile a model targets.
/// Architecture: 05-OFFLINE-AI.md §20
enum ModelProfile {
  tiny,
  balanced,
  power;

  String get displayName => switch (this) {
    ModelProfile.tiny => 'Tiny (~1B)',
    ModelProfile.balanced => 'Balanced (~3B)',
    ModelProfile.power => 'Power (~7B)',
  };
}

// ── Logging ───────────────────────────────────────────────────────────────

/// Log severity levels.
/// Architecture: 02-ARCHITECTURE.md §LoggingService, NFR-010
enum LogLevel {
  verbose,
  debug,
  info,
  warn,
  error;

  bool operator >=(LogLevel other) => index >= other.index;
}

/// Subsystem tags for structured log entries.
/// Architecture: 02-ARCHITECTURE.md §LoggingService
enum LogSubsystem {
  ui,
  core,
  filesystem,
  runtime,
  agent,
  ai,
  security,
  process,
  settings,
}

// ── Diagnostic ────────────────────────────────────────────────────────────

/// Severity of a code diagnostic.
/// Architecture: 07-DATA-MODELS.md §17
enum DiagnosticSeverity { error, warning, info }

/// Source that produced a diagnostic.
enum DiagnosticSource { runtime, staticAnalysis, agent }

// ── Project ───────────────────────────────────────────────────────────────

/// Project lifecycle status.
/// Architecture: 07-DATA-MODELS.md §4
enum ProjectStatus { active, archived }

// ── Security / Audit ──────────────────────────────────────────────────────

/// Types of security events recorded in the audit log.
/// Architecture: 06-SECURITY.md §19.3, 07-DATA-MODELS.md §19
enum AuditEventType {
  pathTraversalAttempt,
  restrictedToolAttempt,
  confirmationDenied,
  confirmationTimeout,
  iterationLimitReached,
  tokenBudgetExhausted,
  suspiciousBulkModification,
}
