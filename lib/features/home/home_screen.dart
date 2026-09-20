import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/route_names.dart';
import '../../core/models/project_model.dart';
import '../../core/providers/project_providers.dart';
import '../../ui/theme/app_theme.dart';

/// Home screen — shows active project + recent project list.
///
/// Phase 2: Connected to real project data via Riverpod providers.
///
/// Architecture: 02-ARCHITECTURE.md §UI Structure
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProject = ref.watch(activeProjectProvider);
    final projects = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mylonite IDE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push(kRouteSettings),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Active project banner ──────────────────────────────────
            if (activeProject != null) ...[
              _ActiveProjectBanner(project: activeProject),
              const SizedBox(height: 20),
            ],

            // ── Hero / intro ───────────────────────────────────────────
            if (activeProject == null) ...[
              Text(
                'Mylonite IDE',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Edit, run, and debug code — fully offline.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // ── Quick actions ──────────────────────────────────────────
            _QuickActionCard(
              icon: Icons.add_circle_outline,
              title: 'New Project',
              subtitle: 'Start a Python or JavaScript project',
              onTap: () => context.go(kRouteProjects),
            ),
            const SizedBox(height: 10),
            _QuickActionCard(
              icon: Icons.folder_open_outlined,
              title: 'All Projects',
              subtitle: projects.isEmpty
                  ? 'No projects yet'
                  : '${projects.length} project${projects.length == 1 ? '' : 's'}',
              onTap: () => context.go(kRouteProjects),
            ),
            const SizedBox(height: 10),
            _QuickActionCard(
              icon: Icons.memory_outlined,
              title: 'Model Manager',
              subtitle: 'Download and activate local AI models',
              onTap: () => context.push(kRouteModelManager),
            ),

            // ── Recent projects ────────────────────────────────────────
            if (projects.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text(
                'RECENT PROJECTS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ...projects
                  .take(5)
                  .map(
                    (p) => _RecentProjectTile(
                      project: p,
                      isActive: activeProject?.id == p.id,
                      ref: ref,
                    ),
                  ),
            ],

            // ── Status bar ─────────────────────────────────────────────
            const SizedBox(height: 28),
            const _StatusBar(),
          ],
        ),
      ),
    );
  }
}

// ── Active project banner ─────────────────────────────────────────────────────

class _ActiveProjectBanner extends StatelessWidget {
  const _ActiveProjectBanner({required this.project});
  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  project.primaryLanguage.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () => ctx.go(kRouteExplorer),
              child: const Text(
                'Continue →',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick action card ─────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.55),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ── Recent project tile ───────────────────────────────────────────────────────

class _RecentProjectTile extends StatelessWidget {
  const _RecentProjectTile({
    required this.project,
    required this.isActive,
    required this.ref,
  });

  final ProjectModel project;
  final bool isActive;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final lastDate = project.lastOpenedAt ?? project.createdAt;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: (isActive ? AppColors.secondary : AppColors.primary)
            .withValues(alpha: 0.15),
        child: Text(
          project.primaryLanguage.name.substring(0, 2).toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isActive ? AppColors.secondary : AppColors.primary,
          ),
        ),
      ),
      title: Text(
        project.name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _relativeDate(lastDate),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurface
              .withValues(alpha: 0.45),
        ),
      ),
      trailing: isActive
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'open',
                style: TextStyle(fontSize: 10, color: AppColors.secondary),
              ),
            )
          : null,
      onTap: () async {
        await ref.read(projectListProvider.notifier).openProject(project);
        ref.read(activeProjectProvider.notifier).state = project;
        if (context.mounted) context.go(kRouteExplorer);
      },
    );
  }

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM y').format(date);
  }
}

// ── Status bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.darkBorder.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.warning),
          const SizedBox(width: 8),
          Text('No model loaded', style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(
            'v0.1.0 · Phase 3',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
