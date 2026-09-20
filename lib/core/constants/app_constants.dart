/// App-wide constants.
///
/// Centralises magic numbers and string literals so they are
/// never duplicated across the codebase.
library;

/// Application identity
const String kAppName = 'Mylonite IDE';
const String kAppVersion = '0.1.0';
const String kPackageName = 'com.offlinemobileide.aioide';

/// Storage directory names (relative to getFilesDir())
/// Architecture: 07-DATA-MODELS.md §21 Storage Layout
const String kProjectsDir = 'projects';
const String kRuntimesDir = 'runtimes';
const String kModelsDir = 'models';
const String kSettingsDir = 'settings';
const String kIndexDir = 'index';
const String kLogsDir = 'logs';
const String kTmpDir = 'tmp';

/// Settings file names
const String kSettingsFileName = 'settings.json';
const String kProvidersFileName = 'providers.json';

/// Project metadata file
const String kProjectMetaFileName = 'project.json';

/// Agent session / execution retention limits
/// Architecture: 07-DATA-MODELS.md §11, §16
const int kMaxSessionsPerProject = 50;
const int kMaxExecutionsPerProject = 20;

/// Agent loop limits (defaults — overridable in Settings)
/// Architecture: 03-AI-AGENT.md §13.1
const int kDefaultAgentMaxIterations = 20;
const int kAgentHardMaxIterations = 50;
const int kDefaultMaxToolCallsPerIteration = 5;
const int kAgentHardMaxToolCallsPerIteration = 10;
const int kDefaultNoToolCallStreakLimit = 3;
const int kDefaultConfirmationTimeoutSeconds = 120;
const int kDefaultMaxFileWritesPerSession = 20;

/// Execution limits
/// Architecture: 03-AI-AGENT.md §7 tool definitions
const int kDefaultExecutionTimeoutSeconds = 30;
const int kAgentMaxExecutionTimeoutSeconds = 120;
const int kUserExecutionTimeoutSeconds = 300;

/// AI model / inference defaults
/// Architecture: 05-OFFLINE-AI.md §12.3, §20
const double kContextBudgetMultiplier = 0.75;
const int kModelOutputReserveTokens = 1024;
const int kModelIdleUnloadMinutes = 10;

/// Security limits
/// Architecture: 06-SECURITY.md §6.3, 03-AI-AGENT.md §13.1
const int kMassModificationThresholdPerResponse = 5;
const int kSessionWriteLimit = 20;
const int kMaxReadFileSizeBytes = 500 * 1024; // 500 KB

/// Logging
/// Architecture: 02-ARCHITECTURE.md §LoggingService
const int kLogRingBufferSize = 500;
const int kLogFileMaxBytes = 5 * 1024 * 1024; // 5 MB
const int kLogFileRotations = 3;
