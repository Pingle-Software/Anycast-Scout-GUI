import 'package:anycast_scout_gui/src/app/localization/app_strings.dart';
import 'package:anycast_scout_gui/src/app/theme/app_theme.dart';
import 'package:anycast_scout_gui/src/pages/dashboard/dashboard_page.dart';
import 'package:flutter/material.dart';

class AnycastScoutGuiApp extends StatelessWidget {
  const AnycastScoutGuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppStrings.forLanguage(AppLanguage.en).appTitle,
      themeMode: ThemeMode.light,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const DashboardPage(),
    );
  }
}
