import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DashboardSection { dashboard, journal, sessions, settings }

final dashboardSectionProvider =
    NotifierProvider<DashboardSectionController, DashboardSection>(
      DashboardSectionController.new,
    );

class DashboardSectionController extends Notifier<DashboardSection> {
  @override
  DashboardSection build() => DashboardSection.dashboard;

  void select(DashboardSection section) => state = section;
}
