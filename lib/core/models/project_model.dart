import 'enums.dart';

/// Represents one user project.
///
/// Persisted as JSON at:
///   `<appFilesDir>/projects/<id>/project.json`
///
/// Architecture: 07-DATA-MODELS.md §4
class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.name,
    required this.primaryLanguage,
    required this.workspacePath,
    required this.createdAt,
    this.description,
    this.lastOpenedAt,
    this.lastModifiedAt,
    this.defaultRuntimeId,
    this.defaultModelId,
    this.entryPoint,
    this.status = ProjectStatus.active,
    this.schemaVersion = 1,
  });

  final String id;
  final String name;
  final String? description;
  final Language primaryLanguage;

  /// Absolute path to the workspace directory (the folder containing source files).
  final String workspacePath;

  final DateTime createdAt;
  final DateTime? lastOpenedAt;
  final DateTime? lastModifiedAt;

  final String? defaultRuntimeId;
  final String? defaultModelId;

  /// Relative path to the main entry-point file (e.g. `main.py`).
  final String? entryPoint;

  final ProjectStatus status;
  final int schemaVersion;

  // ── Derived helpers ──────────────────────────────────────────────────────

  /// Absolute path to the project metadata directory.
  /// This is the parent of the workspace directory.
  String get metadataDir {
    // workspacePath = .../projects/<id>/workspace
    // metadataDir  = .../projects/<id>
    final parts = workspacePath.split(RegExp(r'[/\\]'));
    parts.removeLast(); // remove "workspace" segment
    return parts.join('/');
  }

  bool get isActive => status == ProjectStatus.active;

  // ── copyWith ─────────────────────────────────────────────────────────────

  ProjectModel copyWith({
    String? name,
    String? description,
    Language? primaryLanguage,
    DateTime? lastOpenedAt,
    DateTime? lastModifiedAt,
    String? defaultRuntimeId,
    String? defaultModelId,
    String? entryPoint,
    ProjectStatus? status,
  }) {
    return ProjectModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      workspacePath: workspacePath,
      createdAt: createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      defaultRuntimeId: defaultRuntimeId ?? this.defaultRuntimeId,
      defaultModelId: defaultModelId ?? this.defaultModelId,
      entryPoint: entryPoint ?? this.entryPoint,
      status: status ?? this.status,
      schemaVersion: schemaVersion,
    );
  }

  // ── JSON ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'description': description,
        'primaryLanguage': primaryLanguage.name,
        'workspacePath': workspacePath,
        'createdAt': createdAt.toIso8601String(),
        'lastOpenedAt': lastOpenedAt?.toIso8601String(),
        'lastModifiedAt': lastModifiedAt?.toIso8601String(),
        'defaultRuntimeId': defaultRuntimeId,
        'defaultModelId': defaultModelId,
        'entryPoint': entryPoint,
        'status': status.name,
      };

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      schemaVersion: (json['schemaVersion'] as int?) ?? 1,
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      primaryLanguage: Language.values.firstWhere(
        (l) => l.name == json['primaryLanguage'],
        orElse: () => Language.other,
      ),
      workspacePath: json['workspacePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastOpenedAt: json['lastOpenedAt'] != null
          ? DateTime.parse(json['lastOpenedAt'] as String)
          : null,
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.parse(json['lastModifiedAt'] as String)
          : null,
      defaultRuntimeId: json['defaultRuntimeId'] as String?,
      defaultModelId: json['defaultModelId'] as String?,
      entryPoint: json['entryPoint'] as String?,
      status: ProjectStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ProjectStatus.active,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ProjectModel(id: $id, name: $name)';
}
