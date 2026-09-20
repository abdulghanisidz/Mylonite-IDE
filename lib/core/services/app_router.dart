import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/agent/agent_screen.dart';
import '../../features/editor/editor_screen.dart';
import '../../features/explorer/explorer_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/model_manager/model_manager_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/runtime_manager/runtime_manager_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/terminal/terminal_screen.dart';
import '../constants/route_names.dart';

/// Application router configuration using go_router.
///
/// The shell route wraps the five main tab screens (Editor, Explorer,
/// Terminal, Agent, Home) in a persistent [NavigationBar].
/// Settings, Runtime Manager, and Model Manager are pushed on top as
/// full-screen routes.
///
/// Architecture: 02-ARCHITECTURE.md §UI Structure
class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: kRouteHome,
    debugLogDiagnostics: true,
    routes: [
      // ── Shell: bottom-nav tabs ─────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          // Tab 0 — Home / Projects
          StatefulShellBranch(routes: [
            GoRoute(
              path: kRouteHome,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HomeScreen()),
              routes: [
                GoRoute(
                  path: 'projects',
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: ProjectsScreen()),
                ),
              ],
            ),
          ]),

          // Tab 1 — Code Editor
          StatefulShellBranch(routes: [
            GoRoute(
              path: kRouteEditor,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: EditorScreen()),
            ),
          ]),

          // Tab 2 — File Explorer
          StatefulShellBranch(routes: [
            GoRoute(
              path: kRouteExplorer,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ExplorerScreen()),
            ),
          ]),

          // Tab 3 — Terminal
          StatefulShellBranch(routes: [
            GoRoute(
              path: kRouteTerminal,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: TerminalScreen()),
            ),
          ]),

          // Tab 4 — AI Agent
          StatefulShellBranch(routes: [
            GoRoute(
              path: kRouteAgent,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: AgentScreen()),
            ),
          ]),
        ],
      ),

      // ── Full-screen overlay routes ─────────────────────────────────────
      GoRoute(
        path: kRouteSettings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: kRouteRuntimeManager,
        builder: (context, state) => const RuntimeManagerScreen(),
      ),
      GoRoute(
        path: kRouteModelManager,
        builder: (context, state) => const ModelManagerScreen(),
      ),
    ],
  );
}

/// Persistent bottom-navigation shell.
///
/// Wraps the five tab destinations and keeps their scroll/state positions
/// via [StatefulShellRoute.indexedStack].
class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.code_outlined),
      selectedIcon: Icon(Icons.code),
      label: 'Editor',
    ),
    NavigationDestination(
      icon: Icon(Icons.folder_outlined),
      selectedIcon: Icon(Icons.folder),
      label: 'Files',
    ),
    NavigationDestination(
      icon: Icon(Icons.terminal_outlined),
      selectedIcon: Icon(Icons.terminal),
      label: 'Terminal',
    ),
    NavigationDestination(
      icon: Icon(Icons.smart_toy_outlined),
      selectedIcon: Icon(Icons.smart_toy),
      label: 'Agent',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: _destinations,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
    );
  }
}
