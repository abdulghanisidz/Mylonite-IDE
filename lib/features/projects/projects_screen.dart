import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/route_names.dart';
import '../../core/models/enums.dart';
import '../../core/models/project_model.dart';
import '../../core/providers/project_providers.dart';
import '../../platform/channels/storage_channel.dart';
import '../../ui/theme/app_theme.dart';

/// Projects screen — live list of all user projects.
///
/// Phase 2B additions:
///   • Import project from ZIP (AppBar action)
///   • Export project to ZIP (per-project popup menu)
///
/// Architecture: FR-001–FR-009, FR-007 (import), FR-008 (export)
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          // Import from ZIP
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Import project from ZIP',
            onPressed: () => _importProject(context, ref),
          ),
          // New project
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Project',
            onPressed: () => _showNewProjectSheet(context, ref),
          ),
        ],
      ),
      body: projects.isEmpty
          ? const _EmptyState()
          : _ProjectList(projects: projects),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewProjectSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showNewProjectSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _NewProjectSheet(parentRef: ref),
    );
  }

  /// Full import flow:
  ///   1. Open SAF file picker filtered to ZIP
  ///   2. Read bytes via StorageChannel
  ///   3. Ask user for project name + language
  ///   4. Call importProject on the notifier
  Future<void> _importProject(BuildContext context, WidgetRef ref) async {
    // Step 1 — pick file
    final uri = await StorageChannel.instance.openFilePicker(
      mimeType: 'application/zip',
    );
    if (uri == null || !context.mounted) return;

    // Step 2 — read bytes (show progress)
    final scaffoldMsg = ScaffoldMessenger.of(context);
    scaffoldMsg.showSnackBar(
      const SnackBar(
        content: Text('Reading ZIP…'),
        duration: Duration(seconds: 30),
      ),
    );

    final bytes = await StorageChannel.instance.readFromUri(uri);
    scaffoldMsg.clearSnackBars();

    if (bytes == null || !context.mounted) {
      scaffoldMsg.showSnackBar(
        const SnackBar(
          content: Text('Failed to read the selected file.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Step 3 — ask name + language
    final result = await showDialog<_ImportParams>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (result == null || !context.mounted) return;

    // Step 4 — import
    scaffoldMsg.showSnackBar(
      const SnackBar(
        content: Text('Importing project…'),
        duration: Duration(seconds: 60),
      ),
    );

    final project = await ref
        .read(projectListProvider.notifier)
        .importProject(
          name: result.name,
          language: result.language,
          zipBytes: bytes,
        );

    scaffoldMsg.clearSnackBars();
    if (!context.mounted) return;

    if (project == null) {
      scaffoldMsg.showSnackBar(
        const SnackBar(
          content: Text('Import failed. The ZIP may be invalid.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    scaffoldMsg.showSnackBar(
      SnackBar(
        content: Text('Imported "${project.name}" successfully.'),
        backgroundColor: AppColors.secondary,
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.25),
          ),
          const SizedBox(height: 20),
          Text(
            'No projects yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "New Project" to get started.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Project list ──────────────────────────────────────────────────────────────

class _ProjectList extends ConsumerWidget {
  const _ProjectList({required this.projects});
  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: projects.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) => _ProjectTile(project: projects[i]),
    );
  }
}

class _ProjectTile extends ConsumerWidget {
  const _ProjectTile({required this.project});
  final ProjectModel project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langColor = _langColor(project.primaryLanguage);
    final lastOpened = project.lastOpenedAt != null
        ? 'Opened ${_relativeDate(project.lastOpenedAt!)}'
        : 'Created ${_relativeDate(project.createdAt)}';

    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: langColor.withValues(alpha: 0.15),
        child: Text(
          _langIcon(project.primaryLanguage),
          style: TextStyle(fontSize: 18, color: langColor),
        ),
      ),
      title: Text(
        project.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${project.primaryLanguage.displayName} · $lastOpened',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      trailing: PopupMenuButton<_ProjectAction>(
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (action) => _handleAction(context, ref, action),
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _ProjectAction.open,
            child: ListTile(
              leading: Icon(Icons.folder_open_outlined),
              title: Text('Open'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          PopupMenuItem(
            value: _ProjectAction.export,
            child: ListTile(
              leading: Icon(Icons.file_upload_outlined),
              title: Text('Export as ZIP'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          PopupMenuItem(
            value: _ProjectAction.delete,
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Delete', style: TextStyle(color: AppColors.error)),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
      onTap: () => _openProject(context, ref),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _ProjectAction action,
  ) async {
    switch (action) {
      case _ProjectAction.open:
        await _openProject(context, ref);
      case _ProjectAction.export:
        await _exportProject(context, ref);
      case _ProjectAction.delete:
        await _confirmDelete(context, ref);
    }
  }

  Future<void> _openProject(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(projectListProvider.notifier)
        .openProject(project);
    if (!ok || !context.mounted) return;
    ref.read(activeProjectProvider.notifier).state = project;
    context.go(kRouteExplorer);
  }

  /// Export flow:
  ///   1. Build ZIP bytes from the workspace
  ///   2. Open SAF directory picker
  ///   3. Create a file in the chosen directory and write the bytes
  Future<void> _exportProject(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Building ZIP…'),
        duration: Duration(seconds: 60),
      ),
    );

    // Step 1 — build ZIP
    final bytes = await ref
        .read(projectListProvider.notifier)
        .exportProject(project);

    messenger.clearSnackBars();
    if (!context.mounted) return;

    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Export failed.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Step 2 — pick a destination directory
    final dirUri = await StorageChannel.instance.openDirectoryPicker();
    if (dirUri == null || !context.mounted) return;

    // Step 3 — write the ZIP into that directory.
    // We use ACTION_CREATE_DOCUMENT via the document tree URI.
    // The simplest approach on Android: write to a file in the chosen tree.
    // We construct a document URI for a new file inside the chosen tree.
    final fileName = '${project.name.replaceAll(RegExp(r'[^\w\-]'), '_')}.zip';
    final fileUri = '$dirUri/document/${Uri.encodeComponent(fileName)}';

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Saving ZIP…'),
        duration: Duration(seconds: 30),
      ),
    );

    final success = await StorageChannel.instance.writeToUri(fileUri, bytes);
    messenger.clearSnackBars();
    if (!context.mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Exported "$fileName" successfully.'
              : 'Could not write to the selected location.',
        ),
        backgroundColor: success ? AppColors.secondary : AppColors.error,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          'This will permanently delete "${project.name}" '
          'and all its files. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(projectListProvider.notifier).deleteProject(project);
    }
  }

  Color _langColor(Language lang) => switch (lang) {
    Language.python => const Color(0xFF3572A5),
    Language.javascript => const Color(0xFFF1E05A),
    Language.typescript => const Color(0xFF2B7489),
    _ => AppColors.primary,
  };

  String _langIcon(Language lang) => switch (lang) {
    Language.python => 'Py',
    Language.javascript => 'JS',
    Language.typescript => 'TS',
    Language.dart => 'Dt',
    _ => '?',
  };

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM y').format(date);
  }
}

enum _ProjectAction { open, export, delete }

// ── Import dialog ─────────────────────────────────────────────────────────────

class _ImportParams {
  const _ImportParams({required this.name, required this.language});
  final String name;
  final Language language;
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _nameCtrl = TextEditingController();
  Language _language = Language.python;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _nameCtrl.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Import project'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Project name',
              hintText: 'my-imported-project',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text('Language', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [Language.python, Language.javascript]
                .map(
                  (lang) => ChoiceChip(
                    label: Text(lang.displayName),
                    selected: _language == lang,
                    onSelected: (_) => setState(() => _language = lang),
                    selectedColor: AppColors.primary.withValues(alpha: 0.25),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: canConfirm
              ? () => Navigator.pop(
                  context,
                  _ImportParams(
                    name: _nameCtrl.text.trim(),
                    language: _language,
                  ),
                )
              : null,
          child: const Text('Import'),
        ),
      ],
    );
  }
}

// ── New project sheet ─────────────────────────────────────────────────────────

class _NewProjectSheet extends ConsumerStatefulWidget {
  const _NewProjectSheet({required this.parentRef});
  final WidgetRef parentRef;

  @override
  ConsumerState<_NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends ConsumerState<_NewProjectSheet> {
  final _nameController = TextEditingController();
  Language _language = Language.python;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _creating = true);

    final project = await ref
        .read(projectListProvider.notifier)
        .createProject(name: name, language: _language);

    if (!mounted) return;
    setState(() => _creating = false);

    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create project.')),
      );
      return;
    }

    Navigator.pop(context);

    await ref.read(projectListProvider.notifier).openProject(project);
    if (!mounted) return;
    ref.read(activeProjectProvider.notifier).state = project;
    // ignore: use_build_context_synchronously
    context.go(kRouteExplorer);
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = _nameController.text.trim().isNotEmpty && !_creating;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('New Project', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (canCreate) _create();
            },
            decoration: const InputDecoration(
              labelText: 'Project name',
              hintText: 'my-calculator',
              prefixIcon: Icon(Icons.folder_outlined),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Language',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [Language.python, Language.javascript]
                .map(
                  (lang) => _LangChip(
                    language: lang,
                    selected: _language == lang,
                    onTap: () => setState(() => _language = lang),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: canCreate ? _create : null,
              child: _creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Project'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final Language language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(language.displayName),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.25),
      checkmarkColor: AppColors.primary,
      avatar: selected
          ? null
          : Icon(
              language == Language.python ? Icons.code : Icons.javascript,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.5),
            ),
    );
  }
}
