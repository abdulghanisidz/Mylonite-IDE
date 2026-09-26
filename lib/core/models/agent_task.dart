/// Represents an autonomous agent task with status tracking.
///
/// The agent follows a SENSE→DECIDE→ACT→CHECK→RECOVER loop:
/// - SENSE: Parse user request and understand intent
/// - DECIDE: Plan approach and determine what code to generate
/// - ACT: Generate code using AI model
/// - CHECK: Execute code and validate results
/// - RECOVER: If errors occur, analyze and regenerate
library;

import 'execution_result.dart';

/// Task status in the autonomous agent loop.
enum AgentTaskStatus {
  /// Task is queued, not started yet.
  pending,

  /// SENSE: Analyzing user request.
  sensing,

  /// DECIDE: Planning approach.
  deciding,

  /// ACT: Generating code.
  generating,

  /// CHECK: Executing generated code.
  executing,

  /// CHECK: Validating execution results.
  validating,

  /// RECOVER: Analyzing errors and planning fix.
  analyzing,

  /// RECOVER: Regenerating corrected code.
  fixing,

  /// Task completed successfully.
  completed,

  /// Task failed after max retry attempts.
  failed,

  /// Task cancelled by user.
  cancelled,
}

/// Version of generated code with execution results.
class CodeVersion {
  /// The generated Python code.
  final String code;

  /// Version number (starts at 1).
  final int version;

  /// Timestamp when this version was generated.
  final DateTime timestamp;

  /// Execution result (if executed).
  final ExecutionResult? executionResult;

  /// AI's reasoning for this version.
  final String? reasoning;

  /// Error analysis (if this version failed).
  final String? errorAnalysis;

  CodeVersion({
    required this.code,
    required this.version,
    required this.timestamp,
    this.executionResult,
    this.reasoning,
    this.errorAnalysis,
  });

  /// Whether this version executed successfully.
  bool get isSuccessful =>
      executionResult != null && executionResult!.exitCode == 0;

  /// Whether this version has errors.
  bool get hasErrors =>
      executionResult != null && executionResult!.exitCode != 0;

  Map<String, dynamic> toJson() => {
    'code': code,
    'version': version,
    'timestamp': timestamp.toIso8601String(),
    'executionResult': executionResult?.toJson(),
    'reasoning': reasoning,
    'errorAnalysis': errorAnalysis,
  };

  factory CodeVersion.fromJson(Map<String, dynamic> json) => CodeVersion(
    code: json['code'] as String,
    version: json['version'] as int,
    timestamp: DateTime.parse(json['timestamp'] as String),
    executionResult: json['executionResult'] != null
        ? ExecutionResult.fromJson(
            json['executionResult'] as Map<String, dynamic>,
          )
        : null,
    reasoning: json['reasoning'] as String?,
    errorAnalysis: json['errorAnalysis'] as String?,
  );
}

/// Represents a task for the autonomous agent.
class AgentTask {
  /// Unique task ID.
  final String id;

  /// User's natural language request.
  final String userRequest;

  /// Current status in the agent loop.
  AgentTaskStatus status;

  /// All code versions generated for this task.
  final List<CodeVersion> codeVersions;

  /// Number of retry attempts made.
  int retryCount;

  /// Maximum allowed retries.
  final int maxRetries;

  /// Task creation timestamp.
  final DateTime createdAt;

  /// Task completion/failure timestamp.
  DateTime? completedAt;

  /// Final result message.
  String? resultMessage;

  /// Current loop iteration messages for UI display.
  final List<String> loopMessages;

  /// Project ID where code should be saved.
  final String? projectId;

  /// Filename for the generated code.
  final String? filename;

  AgentTask({
    required this.id,
    required this.userRequest,
    this.status = AgentTaskStatus.pending,
    List<CodeVersion>? codeVersions,
    this.retryCount = 0,
    this.maxRetries = 3,
    DateTime? createdAt,
    this.completedAt,
    this.resultMessage,
    List<String>? loopMessages,
    this.projectId,
    this.filename,
  }) : codeVersions = codeVersions ?? [],
       createdAt = createdAt ?? DateTime.now(),
       loopMessages = loopMessages ?? [];

  /// Get the latest code version.
  CodeVersion? get latestVersion =>
      codeVersions.isEmpty ? null : codeVersions.last;

  /// Get the first successful version.
  CodeVersion? get successfulVersion => codeVersions.firstWhere(
    (v) => v.isSuccessful,
    orElse: () => codeVersions.first,
  );

  /// Whether task is in a terminal state.
  bool get isTerminal =>
      status == AgentTaskStatus.completed ||
      status == AgentTaskStatus.failed ||
      status == AgentTaskStatus.cancelled;

  /// Whether task is still running.
  bool get isRunning => !isTerminal;

  /// Whether task succeeded.
  bool get isSuccessful => status == AgentTaskStatus.completed;

  /// Whether task has reached max retries.
  bool get hasReachedMaxRetries => retryCount >= maxRetries;

  /// Add a new code version.
  void addCodeVersion(CodeVersion version) {
    codeVersions.add(version);
  }

  /// Add a loop message for UI display.
  void addLoopMessage(String message) {
    loopMessages.add('[${DateTime.now().toIso8601String()}] $message');
  }

  /// Update task status.
  void updateStatus(AgentTaskStatus newStatus) {
    status = newStatus;
    if (isTerminal && completedAt == null) {
      completedAt = DateTime.now();
    }
  }

  /// Get status display text.
  String get statusText {
    switch (status) {
      case AgentTaskStatus.pending:
        return 'Pending';
      case AgentTaskStatus.sensing:
        return 'Understanding request...';
      case AgentTaskStatus.deciding:
        return 'Planning approach...';
      case AgentTaskStatus.generating:
        return 'Generating code...';
      case AgentTaskStatus.executing:
        return 'Executing code...';
      case AgentTaskStatus.validating:
        return 'Validating results...';
      case AgentTaskStatus.analyzing:
        return 'Analyzing errors...';
      case AgentTaskStatus.fixing:
        return 'Fixing code (attempt ${retryCount + 1}/$maxRetries)...';
      case AgentTaskStatus.completed:
        return 'Completed ✓';
      case AgentTaskStatus.failed:
        return 'Failed ✗';
      case AgentTaskStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Get elapsed time.
  Duration get elapsed {
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(createdAt);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userRequest': userRequest,
    'status': status.name,
    'codeVersions': codeVersions.map((v) => v.toJson()).toList(),
    'retryCount': retryCount,
    'maxRetries': maxRetries,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'resultMessage': resultMessage,
    'loopMessages': loopMessages,
    'projectId': projectId,
    'filename': filename,
  };

  factory AgentTask.fromJson(Map<String, dynamic> json) => AgentTask(
    id: json['id'] as String,
    userRequest: json['userRequest'] as String,
    status: AgentTaskStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => AgentTaskStatus.pending,
    ),
    codeVersions:
        (json['codeVersions'] as List<dynamic>?)
            ?.map((v) => CodeVersion.fromJson(v as Map<String, dynamic>))
            .toList() ??
        [],
    retryCount: json['retryCount'] as int? ?? 0,
    maxRetries: json['maxRetries'] as int? ?? 3,
    createdAt: DateTime.parse(json['createdAt'] as String),
    completedAt: json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String)
        : null,
    resultMessage: json['resultMessage'] as String?,
    loopMessages:
        (json['loopMessages'] as List<dynamic>?)
            ?.map((m) => m as String)
            .toList() ??
        [],
    projectId: json['projectId'] as String?,
    filename: json['filename'] as String?,
  );

  /// Create a copy with updated fields.
  AgentTask copyWith({
    String? id,
    String? userRequest,
    AgentTaskStatus? status,
    List<CodeVersion>? codeVersions,
    int? retryCount,
    int? maxRetries,
    DateTime? createdAt,
    DateTime? completedAt,
    String? resultMessage,
    List<String>? loopMessages,
    String? projectId,
    String? filename,
  }) => AgentTask(
    id: id ?? this.id,
    userRequest: userRequest ?? this.userRequest,
    status: status ?? this.status,
    codeVersions: codeVersions ?? this.codeVersions,
    retryCount: retryCount ?? this.retryCount,
    maxRetries: maxRetries ?? this.maxRetries,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt ?? this.completedAt,
    resultMessage: resultMessage ?? this.resultMessage,
    loopMessages: loopMessages ?? this.loopMessages,
    projectId: projectId ?? this.projectId,
    filename: filename ?? this.filename,
  );
}
