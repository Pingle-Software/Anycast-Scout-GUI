import 'package:anycast_scout_gui/src/app/localization/app_strings.dart';
import 'package:anycast_scout_gui/src/features/probe_session/application/dashboard_controller.dart';
import 'package:anycast_scout_gui/src/pages/dashboard/presentation/dashboard_section.dart';
import 'package:anycast_scout_gui/src/pages/dashboard/presentation/dashboard_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final strings = AppStrings.forLanguage(AppLanguage.en);
    final selected = ref.watch(dashboardSectionProvider);

    return Scaffold(
      body: DashboardShell(selected: selected, state: state, strings: strings),
    );
  }
}
