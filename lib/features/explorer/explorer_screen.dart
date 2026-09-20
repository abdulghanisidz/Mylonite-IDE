import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';
import '../../core/models/project_model.dart';
import '../../core/providers/project_providers.dart';
import '../../core/services/workspace_manager.dart';
import '../../ui/theme/app_theme.dart';

/// File explorer screen — live file tree with full CRUD operations.
///
/// Phase 2B additions: create file, create folder, rename, delete
/// via long-press context menu and AppBar action buttons.
///
/// Architecture: 02-ARCHITECTURE.md §WorkspaceManager, FR-010–FR-019
class ExplorerScreen extends ConsumerWidget {
  const ExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProject = ref.watch(activeProjectProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            tooltip: 'New File',
            onPressed: activeProject == null
                ? null
                : () => _showCreateDialog(context, ref, isFolder: false),
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'New Folder',
            onPressed: activeProject == null
                ? null
                : () => _showCreateDialog(context, ref, isFolder: true),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(rootFilesProvider),
          ),
        ],
      ),
      body: activeProject == null
          ? _NoProjectState()
          : Column(
              children: [
                _ProjectHeader(project: activeProject),
                const Divider(height: 1),
                const Expanded(child: _FileTreeView()),
              ],
            ),
    );
  }

  /// Shows a dialog to create a new file or folder at the workspace root.
  void _showCreateDialog(
    BuildContext context,
    WidgetRef ref, {
    required bool isFolder,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _CreateItemDialog(
        isFolder: isFolder,
        parentRelative: '',
        onConfirm: (name) async {
          final ws = ref.read(workspaceManagerProvider);
          if (ws == null) return;
          final relative = name.trim().isEmpty ? null : name.trim();
          if (relative == null) return;

          final result = isFolder
              ? await ws.createDirectory(relative)
              : await ws.createFile(relative, '');

          if (result.isErr && ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(result.errorOrNull!.message),
                backgroundColor: AppColors.error,
              ),
            );
          } else {
            ref.invalidate(rootFilesProvider);
          }
        },
      ),
    );
  }
}

// ── No project open ───────────────────────────────────────────────────────────

class _NoProjectState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            'No project open',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go(kRouteProjects),
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Open a Project'),
          ),
        ],
      ),
    );
  }
}

// ── Project header ────────────────────────────────────────────────────────────

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.project});
  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          const Icon(Icons.folder, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              project.name,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            project.primaryLanguage.displayName,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.primary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── File tree view ────────────────────────────────────────────────────────────

class _FileTreeView extends ConsumerStatefulWidget {
  const _FileTreeView();

  @override
  ConsumerState<_FileTreeView> createState() => _FileTreeViewState();
}

class _FileTreeViewState extends ConsumerState<_FileTreeView> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    // Subscribe to the file watcher — this keeps it alive while the Explorer
    // is on screen, and auto-refreshes rootFilesProvider on change events.
    ref.watch(workspaceWatcherProvider);

    final filesAsync = ref.watch(rootFilesProvider);

    return filesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error: $err',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
      data: (rootNodes) {
        if (rootNodes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  'Workspace is empty',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showCreate(context, '', false),
                  icon: const Icon(Icons.note_add_outlined, size: 16),
                  label: const Text('Create a file'),
                ),
              ],
            ),
          );
        }
        return ListView(children: _buildItems(rootNodes, 0));
      },
    );
  }

  List<Widget> _buildItems(List<FileNode> nodes, int depth) {
    final items = <Widget>[];
    for (final node in nodes) {
      items.add(
        _FileItem(
          node: node,
          depth: depth,
          isExpanded: _expanded.contains(node.relativePath),
          onTap: () => _handleTap(node),
          onLongPress: () => _showContextMenu(context, node),
        ),
      );
      if (node.isDirectory && _expanded.contains(node.relativePath)) {
        items.addAll(_buildItems(node.children, depth + 1));
      }
    }
    return items;
  }

  void _handleTap(FileNode node) {
    if (node.isDirectory) {
      setState(() {
        if (_expanded.contains(node.relativePath)) {
          _expanded.remove(node.relativePath);
        } else {
          _expanded.add(node.relativePath);
        }
      });
      ref.invalidate(rootFilesProvider);
    } else {
      // Open file in the editor and navigate to the Editor tab
      final ec = ref.read(editorControllerProvider);
      if (ec != null) {
        ec.openFile(node.relativePath).then((_) {
          if (mounted) context.go(kRouteEditor);
        });
      }
    }
  }

  // ── Context menu (long-press) ─────────────────────────────────────────────

  void _showContextMenu(BuildContext context, FileNode node) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => _FileContextMenu(
        node: node,
        onCreateFile: node.isDirectory
            ? () {
                Navigator.pop(context);
                _showCreate(context, node.relativePath, false);
              }
            : null,
        onCreateFolder: node.isDirectory
            ? () {
                Navigator.pop(context);
                _showCreate(context, node.relativePath, true);
              }
            : null,
        onRename: () {
          Navigator.pop(context);
          _showRename(context, node);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(context, node);
        },
      ),
    );
  }

  void _showCreate(BuildContext context, String parentRelative, bool isFolder) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _CreateItemDialog(
        isFolder: isFolder,
        parentRelative: parentRelative,
        onConfirm: (name) async {
          final ws = ref.read(workspaceManagerProvider);
          if (ws == null) return;
          final relative = parentRelative.isEmpty
              ? name.trim()
              : '$parentRelative/${name.trim()}';

          final result = isFolder
              ? await ws.createDirectory(relative)
              : await ws.createFile(relative, '');

          if (result.isErr && ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(result.errorOrNull!.message),
                backgroundColor: AppColors.error,
              ),
            );
          } else {
            ref.invalidate(rootFilesProvider);
          }
        },
      ),
    );
  }

  void _showRename(BuildContext context, FileNode node) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _RenameDialog(
        node: node,
        onConfirm: (newName) async {
          final ws = ref.read(workspaceManagerProvider);
          if (ws == null) return;

          // Build new relative path — same parent dir, new name
          final parent = node.relativePath.contains('/')
              ? node.relativePath.substring(
                  0,
                  node.relativePath.lastIndexOf('/'),
                )
              : '';
          final newRelative = parent.isEmpty ? newName : '$parent/$newName';

          final result = await ws.renameFile(node.relativePath, newRelative);

          if (result.isErr && ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(result.errorOrNull!.message),
                backgroundColor: AppColors.error,
              ),
            );
          } else {
            ref.invalidate(rootFilesProvider);
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, FileNode node) async {
    final label = node.isDirectory ? 'folder' : 'file';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $label?'),
        content: RichText(
          text: TextSpan(
            style: Theme.of(ctx).textTheme.bodyMedium,
            children: [
              const TextSpan(text: 'Permanently delete '),
              TextSpan(
                text: '"${node.name}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              node.isDirectory
                  ? const TextSpan(
                      text: ' and all its contents? This cannot be undone.',
                    )
                  : const TextSpan(text: '? This cannot be undone.'),
            ],
          ),
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

    if (confirmed != true) return;

    final ws = ref.read(workspaceManagerProvider);
    if (ws == null) return;

    final result = node.isDirectory
        ? await ws.deleteDirectory(node.relativePath)
        : await ws.deleteFile(node.relativePath);

    if (result.isErr && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorOrNull!.message),
          backgroundColor: AppColors.error,
        ),
      );
    } else if (context.mounted) {
      // Remove expand state if it was a directory
      _expanded.remove(node.relativePath);
      ref.invalidate(rootFilesProvider);
    }
  }
}

// ── Single file/folder row ────────────────────────────────────────────────────

class _FileItem extends StatelessWidget {
  const _FileItem({
    required this.node,
    required this.depth,
    required this.isExpanded,
    required this.onTap,
    required this.onLongPress,
  });

  final FileNode node;
  final int depth;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12.0 + depth * 16.0,
          right: 12,
          top: 6,
          bottom: 6,
        ),
        child: Row(
          children: [
            if (node.isDirectory)
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 16,
                color: AppColors.editorForeground.withValues(alpha: 0.5),
              )
            else
              const SizedBox(width: 16),
            const SizedBox(width: 4),
            Icon(
              node.isDirectory
                  ? (isExpanded ? Icons.folder_open : Icons.folder_outlined)
                  : _iconForFile(node.name),
              size: 16,
              color: node.isDirectory
                  ? AppColors.warning
                  : AppColors.editorForeground.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node.name,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  color: AppColors.editorForeground,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!node.isDirectory && node.sizeBytes > 0)
              Text(
                _formatSize(node.sizeBytes),
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.editorForeground.withValues(alpha: 0.35),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForFile(String name) {
    if (name.endsWith('.py')) return Icons.code;
    if (name.endsWith('.js') || name.endsWith('.ts')) return Icons.javascript;
    if (name.endsWith('.md')) return Icons.article_outlined;
    if (name.endsWith('.json')) return Icons.data_object;
    if (name.endsWith('.txt')) return Icons.text_snippet_outlined;
    if (name.endsWith('.yaml') || name.endsWith('.yml')) {
      return Icons.settings_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}K';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}M';
  }
}

// ── Context menu bottom sheet ─────────────────────────────────────────────────

class _FileContextMenu extends StatelessWidget {
  const _FileContextMenu({
    required this.node,
    required this.onRename,
    required this.onDelete,
    this.onCreateFile,
    this.onCreateFolder,
  });

  final FileNode node;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback? onCreateFile;
  final VoidCallback? onCreateFolder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Icon(
                  node.isDirectory
                      ? Icons.folder_outlined
                      : Icons.insert_drive_file_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'JetBrains Mono',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Actions
          if (onCreateFile != null)
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('New File here'),
              onTap: onCreateFile,
              dense: true,
            ),
          if (onCreateFolder != null)
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New Folder here'),
              onTap: onCreateFolder,
              dense: true,
            ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('Rename'),
            onTap: onRename,
            dense: true,
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.error),
            title: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: onDelete,
            dense: true,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Create file/folder dialog ─────────────────────────────────────────────────

class _CreateItemDialog extends StatefulWidget {
  const _CreateItemDialog({
    required this.isFolder,
    required this.parentRelative,
    required this.onConfirm,
  });

  final bool isFolder;
  final String parentRelative;
  final Future<void> Function(String name) onConfirm;

  @override
  State<_CreateItemDialog> createState() => _CreateItemDialogState();
}

class _CreateItemDialogState extends State<_CreateItemDialog> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isFolder ? 'folder' : 'file';
    final hint = widget.isFolder ? 'my-folder' : 'main.py';

    return AlertDialog(
      title: Text('New $label'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onChanged: (_) => setState(() {}),
        onSubmitted: _ctrl.text.trim().isNotEmpty ? (_) => _submit() : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _ctrl.text.trim().isEmpty || _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await widget.onConfirm(_ctrl.text.trim());
    if (mounted) Navigator.pop(context);
  }
}

// ── Rename dialog ─────────────────────────────────────────────────────────────

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.node, required this.onConfirm});

  final FileNode node;
  final Future<void> Function(String newName) onConfirm;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _ctrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.node.name);
    _ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _ctrl.text.length,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final changed =
        _ctrl.text.trim() != widget.node.name && _ctrl.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'New name'),
        onChanged: (_) => setState(() {}),
        onSubmitted: changed ? (_) => _submit() : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: changed && !_busy ? _submit : null,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Rename'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await widget.onConfirm(_ctrl.text.trim());
    if (mounted) Navigator.pop(context);
  }
}
