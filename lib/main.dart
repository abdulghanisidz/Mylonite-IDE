import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/models/enums.dart';
import 'core/models/settings_model.dart';
import 'core/services/app_router.dart';
import 'core/services/logging_service.dart';
import 'core/services/project_manager.dart';
import 'core/services/settings_service.dart';
import 'core/services/runtime/python_runtime.dart';
import 'ui/theme/app_theme.dart';

/// Application entry point for Mylonite IDE.
///
/// Startup sequence (Architecture: 02-ARCHITECTURE.md §12.3):
///   1. Lock orientation to portrait
///   2. Load SettingsService from disk
///   3. Load all project metadata (ProjectManager.loadAll)
///   4. Initialize Python runtime (Phase 5)
///   5. Launch the Flutter widget tree under ProviderScope
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.darkSurface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await SettingsService.instance.load();
  await ProjectManager.instance.loadAll();

  // Phase 5: Initialize Python runtime
  log.info(LogSubsystem.core, 'Initializing Python runtime...');
  await PythonRuntime.instance.initialize();

  log.info(LogSubsystem.core, 'Mylonite IDE starting — Phase 5.');

  runApp(const ProviderScope(child: MyloniteApp()));
}

/// Root widget for Mylonite IDE.
class MyloniteApp extends ConsumerWidget {
  const MyloniteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = SettingsService.instance.current;

    final themeMode = switch (settings.themeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

    return MaterialApp.router(
      title: 'Mylonite IDE',
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      theme: AppTheme.light(editorFontSize: settings.fontSize.toDouble()),
      darkTheme: AppTheme.dark(editorFontSize: settings.fontSize.toDouble()),
      themeMode: themeMode,
    );
  }
}
