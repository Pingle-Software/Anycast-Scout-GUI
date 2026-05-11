import 'package:anycast_scout_gui/src/app/localization/app_strings.dart';
import 'package:anycast_scout_gui/src/app/theme/app_theme.dart';
import 'package:anycast_scout_gui/src/app/theme/theme_preference_controller.dart';
import 'package:anycast_scout_gui/src/pages/dashboard/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnycastScoutGuiApp extends ConsumerWidget {
  const AnycastScoutGuiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreference = ref.watch(appThemePreferenceProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppStrings.forLanguage(AppLanguage.en).appTitle,
      themeMode: themePreference.themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeAnimationDuration: const Duration(milliseconds: 140),
      home: const DashboardPage(),
    );
  }
}
