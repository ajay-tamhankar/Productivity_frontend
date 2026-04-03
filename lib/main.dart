import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/routes/app_router.dart';
import 'data/repositories/local_storage_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Await shared preferences to prevent provider lookup errors
  final sharedPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(AsyncValue.data(sharedPrefs)),
      ],
      child: const ProductionMonitoringApp(),
    ),
  );
}

class ProductionMonitoringApp extends ConsumerWidget {
  const ProductionMonitoringApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Production Sync',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
