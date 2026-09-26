/// Diagnostic — Represents a code issue (error, warning, info).
///
/// Used by:
/// - Code editor gutter (error markers)
/// - Status bar (diagnostic count)
/// - Python/JavaScript runtime (traceback parsing)
/// - AI agent (code correction context)
///
/// Architecture: 07-DATA-MODELS.md §Diagnostic
enum DiagnosticSeverity { error, warning, info, hint }

class Diagnostic {
  final DiagnosticSeverity severity;
  final String message;
  final String? file;
  final int? line;
  final int? column;
  final String? source; // e.g., 'python', 'javascript', 'linter'
  final String? code; // e.g., 'E501', 'NameError'

  const Diagnostic({
    required this.severity,
    required this.message,
    this.file,
    this.line,
    this.column,
    this.source,
    this.code,
  });

  /// Create a copy with updated fields.
  Diagnostic copyWith({
    DiagnosticSeverity? severity,
    String? message,
    String? file,
    int? line,
    int? column,
    String? source,
    String? code,
  }) {
    return Diagnostic(
      severity: severity ?? this.severity,
      message: message ?? this.message,
      file: file ?? this.file,
      line: line ?? this.line,
      column: column ?? this.column,
      source: source ?? this.source,
      code: code ?? this.code,
    );
  }

  Map<String, dynamic> toJson() => {
    'severity': severity.name,
    'message': message,
    'file': file,
    'line': line,
    'column': column,
    'source': source,
    'code': code,
  };

  factory Diagnostic.fromJson(Map<String, dynamic> json) => Diagnostic(
    severity: DiagnosticSeverity.values.firstWhere(
      (s) => s.name == json['severity'],
      orElse: () => DiagnosticSeverity.error,
    ),
    message: json['message'] as String,
    file: json['file'] as String?,
    line: json['line'] as int?,
    column: json['column'] as int?,
    source: json['source'] as String?,
    code: json['code'] as String?,
  );

  @override
  String toString() {
    final location = file != null && line != null
        ? '$file:$line${column != null ? ':$column' : ''}'
        : file ?? 'unknown';
    return '$severity: $message ($location)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Diagnostic &&
          runtimeType == other.runtimeType &&
          severity == other.severity &&
          message == other.message &&
          file == other.file &&
          line == other.line &&
          column == other.column &&
          source == other.source &&
          code == other.code;

  @override
  int get hashCode =>
      severity.hashCode ^
      message.hashCode ^
      file.hashCode ^
      line.hashCode ^
      column.hashCode ^
      source.hashCode ^
      code.hashCode;
}
