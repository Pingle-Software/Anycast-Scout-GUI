import 'dart:io';

import 'package:anycast_scout_gui/src/app/localization/app_strings.dart';
import 'package:anycast_scout_gui/src/features/probe_session/domain/dashboard_state.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/workflow_config.dart';
import 'package:anycast_scout_gui/src/pages/dashboard/presentation/status_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final strings = AppStrings.forLanguage(AppLanguage.en);

  test('scan progress status is presented as compact status label', () {
    expect(
      compactStatusText('scanned=102 valid=0', strings),
      strings.scanRunning,
    );
  });

  test('discovery progress status is presented as compact status label', () {
    expect(
      compactStatusText('discovery targets written=8192', strings),
      strings.discoveryRunning,
    );
  });

  test('status summary falls back to running label without raw progress', () {
    final workspaceRoot = Directory.current.path;
    final state = DashboardState.initial(
      workspaceRoot,
      '/tmp/anycast-scout',
      defaultConfigValues(workspaceRoot),
    ).copyWith(status: '', running: true);

    expect(statusSummaryText(state, strings), strings.running);
  });

  test('dashboard status formats scan counters as user-facing text', () {
    final state = _state().copyWith(
      running: true,
      status: 'scanned=34535 valid=0',
      metrics: {'scanned_count': 34535, 'scan_valid_count': 0},
    );

    final message = dashboardStatusMessage(state, strings);

    expect(message.title, strings.scanRunning);
    expect(message.body, contains('No valid IPs found yet'));
    expect(message.body, contains('34,535'));
    expect(message.body, contains(strings.statusInProgress));
  });

  test(
    'running ASN workflow starts as discovery stage before counters arrive',
    () {
      final state = _state().copyWith(running: true, status: 'Running');

      expect(statusStage(state), StatusStage.discovery);
      expect(
        dashboardStatusMessage(state, strings).title,
        strings.discoveryRunning,
      );
    },
  );

  test('connect progress status is formatted without raw protocol line', () {
    final state = _state().copyWith(
      running: true,
      status:
          'sing-box batch start=0 size=4 scan-valid=230 sing-box-ok=7 usable=3',
      metrics: {'scan_valid_count': 230, 'usable_count': 3},
    );

    final message = dashboardStatusMessage(state, strings);

    expect(statusStage(state), StatusStage.connect);
    expect(message.title, strings.connectRunning);
    expect(message.body, contains('230'));
    expect(message.body, contains('3 usable'));
  });
}

DashboardState _state() {
  final workspaceRoot = Directory.current.path;
  return DashboardState.initial(
    workspaceRoot,
    '/tmp/anycast-scout',
    defaultConfigValues(workspaceRoot),
  );
}
