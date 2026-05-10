import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:anycast_scout_gui/src/features/probe_session/application/dashboard_controller.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/backend_availability.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/core_probe_runner_factory.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/core_runner.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/platform_file_revealer.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/system_clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progress lines are batched before updating dashboard state', () async {
    final container = ProviderContainer(
      overrides: [appClockProvider.overrideWithValue(_FixedClock())],
    );
    addTearDown(container.dispose);

    final controller = container.read(dashboardProvider.notifier);

    for (var index = 0; index < 10; index++) {
      controller.handleProgress('scanned=$index valid=$index');
    }

    expect(container.read(dashboardProvider).logs, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 150));

    final state = container.read(dashboardProvider);
    expect(state.logs, hasLength(10));
    expect(state.metricInt('scanned_count'), 9);
    expect(state.metricInt('scan_valid_count'), 9);
  });

  test(
    'start workflow leaves the controller responsive while scan is pending',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'anycast-scout-gui-controller-test-',
      );
      addTearDown(() {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });

      final runner = _HoldingRunner();
      final container = ProviderContainer(
        overrides: [
          appClockProvider.overrideWithValue(_FixedClock()),
          backendAvailabilityProvider.overrideWithValue(
            const _AvailableBackend(),
          ),
          coreProbeRunnerFactoryProvider.overrideWithValue(
            _FakeRunnerFactory(runner),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(dashboardProvider.notifier);
      controller
        ..updateCoreBinary('/tmp/anycast-scout')
        ..updateTextField('sing_box_config', '${temp.path}/sing-box.json')
        ..updateTextField('session_path', '${temp.path}/session.json')
        ..updateTextField('targets_output', '${temp.path}/targets.csv')
        ..updateTextField('scan_output', '${temp.path}/selected.csv')
        ..updateTextField('urltest_output', '${temp.path}/urltests.json');

      final workflow = controller.startWorkflow();
      await runner.started.future;

      expect(container.read(dashboardProvider).running, isTrue);

      controller.updateTextField('manual_targets', '203.0.113.1');

      final responsiveState = container.read(dashboardProvider);
      expect(responsiveState.running, isTrue);
      expect(responsiveState.text('manual_targets'), '203.0.113.1');

      runner.complete();
      await workflow;

      expect(container.read(dashboardProvider).running, isFalse);
    },
  );

  test('continue session restores paths and runs scan in resume mode', () async {
    final temp = Directory.systemTemp.createTempSync(
      'anycast-scout-gui-continue-test-',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    final sessionPath = '${temp.path}/saved-session.json';
    final targetsPath = '${temp.path}/saved-session.targets.csv';
    File(targetsPath).writeAsStringSync(
      'ip,port,source,asn,name,prefix\n1.1.1.1,443,fixture,13335,Cloudflare,1.1.1.0/24\n',
    );
    File(sessionPath).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'saved_at_unix': 1777982400,
        'config': {'session_path': sessionPath, 'targets_output': targetsPath, 'scan_output': '${temp.path}/saved-session.selected.csv', 'urltest_output': '${temp.path}/saved-session.urltests.json', 'sing_box_config': '${temp.path}/sing-box.json', 'asn_list': 'AS13335'},
        'last_scan_results': const <Map<String, dynamic>>[],
        'last_urltest_results': const <Map<String, dynamic>>[],
        'workflow_metrics': {'target_count': 1, 'scanned_count': 1},
        'gui': {'core_binary': '/tmp/anycast-scout', 'status': 'Stopped'},
      })}\n',
    );

    final runner = _HoldingRunner();
    final container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(_FixedClock()),
        backendAvailabilityProvider.overrideWithValue(
          const _AvailableBackend(),
        ),
        coreProbeRunnerFactoryProvider.overrideWithValue(
          _FakeRunnerFactory(runner),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(dashboardProvider.notifier);
    final workflow = controller.continueSessionFromPath(sessionPath);
    await runner.started.future;

    expect(container.read(dashboardProvider).running, isTrue);
    expect(runner.lastResume, isTrue);
    expect(runner.lastConfig?.sessionPath, sessionPath);
    expect(runner.lastConfig?.text('targets_output'), targetsPath);

    runner.complete();
    await workflow;

    expect(container.read(dashboardProvider).running, isFalse);
  });

  test('timeout fallback runs as a separate post-scan action', () async {
    final temp = Directory.systemTemp.createTempSync(
      'anycast-scout-gui-timeout-fallback-test-',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    final runner = _HoldingRunner();
    final container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(_FixedClock()),
        backendAvailabilityProvider.overrideWithValue(
          const _AvailableBackend(),
        ),
        coreProbeRunnerFactoryProvider.overrideWithValue(
          _FakeRunnerFactory(runner),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(dashboardProvider.notifier);
    controller
      ..updateCoreBinary('/tmp/anycast-scout')
      ..updateTextField('sing_box_config', '${temp.path}/sing-box.json')
      ..updateTextField('session_path', '${temp.path}/session.json')
      ..updateTextField('scan_output', '${temp.path}/selected.csv')
      ..updateTextField('urltest_output', '${temp.path}/urltests.json')
      ..updateTextField('targets_output', '${temp.path}/targets.csv');
    container
        .read(dashboardProvider.notifier)
        .handleProgress('scanned=10 valid=2');

    final workflow = controller.continueTimeoutFallback();
    await runner.timeoutFallbackStarted.future;

    expect(container.read(dashboardProvider).running, isTrue);

    runner.completeTimeoutFallback(
      const TimeoutFallbackOutcome(
        candidateCount: 5,
        testedCount: 3,
        successfulCount: 1,
        remainingCount: 2,
      ),
    );
    await workflow;

    final state = container.read(dashboardProvider);
    expect(state.running, isFalse);
    expect(state.metricInt('timeout_fallback_tested_count'), 3);
    expect(state.metricInt('timeout_fallback_ok_count'), 1);
    expect(state.metricInt('timeout_fallback_pending_count'), 2);
  });

  test('candidate checks run as a separate post-scan action', () async {
    final temp = Directory.systemTemp.createTempSync(
      'anycast-scout-gui-candidate-check-test-',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    final runner = _HoldingRunner();
    final container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(_FixedClock()),
        backendAvailabilityProvider.overrideWithValue(
          const _AvailableBackend(),
        ),
        coreProbeRunnerFactoryProvider.overrideWithValue(
          _FakeRunnerFactory(runner),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(dashboardProvider.notifier);
    controller
      ..updateCoreBinary('/tmp/anycast-scout')
      ..updateTextField('sing_box_config', '${temp.path}/sing-box.json')
      ..updateTextField('session_path', '${temp.path}/session.json')
      ..updateTextField('scan_output', '${temp.path}/selected.csv')
      ..updateTextField('urltest_output', '${temp.path}/urltests.json')
      ..updateTextField('targets_output', '${temp.path}/targets.csv');

    final workflow = controller.checkCandidates();
    await runner.candidateConnectStarted.future;

    expect(container.read(dashboardProvider).running, isTrue);

    runner.completeCandidateConnect(
      const CandidateConnectOutcome(
        candidateCount: 2,
        testedCount: 2,
        successfulCount: 1,
        remainingCount: 0,
      ),
    );
    await workflow;

    final state = container.read(dashboardProvider);
    expect(state.running, isFalse);
    expect(state.metricInt('candidate_connect_tested_count'), 2);
    expect(state.metricInt('candidate_connect_ok_count'), 1);
    expect(state.metricInt('candidate_connect_pending_count'), 0);
  });

  test('candidate checks can be started directly from a saved session', () async {
    final temp = Directory.systemTemp.createTempSync(
      'anycast-scout-gui-session-candidate-check-test-',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    final sessionPath = '${temp.path}/saved-session.json';
    File(sessionPath).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'saved_at_unix': 1777982400,
        'config': {'session_path': sessionPath, 'scan_output': '${temp.path}/saved-session.selected.csv', 'urltest_output': '${temp.path}/saved-session.urltests.jsonl', 'sing_box_config': '${temp.path}/sing-box.json', 'asn_list': 'AS13335'},
        'last_scan_results': const <Map<String, dynamic>>[],
        'last_urltest_results': const <Map<String, dynamic>>[],
        'workflow_metrics': {'scanned_count': 10, 'scan_valid_count': 2},
        'gui': {'core_binary': '/tmp/anycast-scout', 'status': 'Stopped'},
      })}\n',
    );

    final runner = _HoldingRunner();
    final container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(_FixedClock()),
        backendAvailabilityProvider.overrideWithValue(
          const _AvailableBackend(),
        ),
        coreProbeRunnerFactoryProvider.overrideWithValue(
          _FakeRunnerFactory(runner),
        ),
      ],
    );
    addTearDown(container.dispose);

    final workflow = container
        .read(dashboardProvider.notifier)
        .checkCandidatesFromPath(sessionPath);
    await runner.candidateConnectStarted.future;

    expect(runner.lastConfig?.sessionPath, sessionPath);
    expect(container.read(dashboardProvider).running, isTrue);

    runner.completeCandidateConnect(
      const CandidateConnectOutcome(
        candidateCount: 2,
        testedCount: 2,
        successfulCount: 1,
        remainingCount: 0,
      ),
    );
    await workflow;

    final state = container.read(dashboardProvider);
    expect(state.running, isFalse);
    expect(state.metricInt('candidate_connect_tested_count'), 2);
  });

  test(
    'start workflow reports missing core binary as dashboard error',
    () async {
      final container = ProviderContainer(
        overrides: [appClockProvider.overrideWithValue(_FixedClock())],
      );
      addTearDown(container.dispose);

      final controller = container.read(dashboardProvider.notifier);
      controller.updateCoreBinary('');

      await controller.startWorkflow();

      final error = container.read(dashboardProvider).activeError;
      expect(error?.title, 'Core binary path is empty');
      expect(error?.message, contains('Choose a valid anycast-scout binary'));

      controller.clearError();

      expect(container.read(dashboardProvider).activeError, isNull);
    },
  );

  test('missing usable CSV is reported as dashboard error', () async {
    final temp = Directory.systemTemp.createTempSync(
      'anycast-scout-gui-error-test-',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });
    final container = ProviderContainer(
      overrides: [appClockProvider.overrideWithValue(_FixedClock())],
    );
    addTearDown(container.dispose);

    final controller = container.read(dashboardProvider.notifier);
    controller.updateTextField('session_path', '${temp.path}/session.json');

    await controller.openUsableCsv();

    final error = container.read(dashboardProvider).activeError;
    expect(error?.title, 'Usable CSV not found');
    expect(error?.details, '${temp.path}/session.usable.csv');
  });

  test('failed reveal command is reported as dashboard error', () async {
    final container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(_FixedClock()),
        platformFileRevealerProvider.overrideWithValue(
          _FailingFileRevealer(StateError('open failed')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(dashboardProvider.notifier)
        .revealSessionFile('/tmp/session.json');

    final error = container.read(dashboardProvider).activeError;
    expect(error?.title, 'Could not reveal session file');
    expect(error?.message, 'open failed');
  });

  test('runner failure is reported as workflow dashboard error', () async {
    final temp = Directory.systemTemp.createTempSync(
      'anycast-scout-gui-runner-error-test-',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    final runner = _HoldingRunner();
    final container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(_FixedClock()),
        backendAvailabilityProvider.overrideWithValue(
          const _AvailableBackend(),
        ),
        coreProbeRunnerFactoryProvider.overrideWithValue(
          _FakeRunnerFactory(runner),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(dashboardProvider.notifier);
    controller
      ..updateCoreBinary('/tmp/anycast-scout')
      ..updateTextField('sing_box_config', '${temp.path}/sing-box.json')
      ..updateTextField('session_path', '${temp.path}/session.json')
      ..updateTextField('targets_output', '${temp.path}/targets.csv')
      ..updateTextField('scan_output', '${temp.path}/selected.csv')
      ..updateTextField('urltest_output', '${temp.path}/urltests.json');

    final workflow = controller.startWorkflow();
    await runner.started.future;
    runner.fail(FormatException('missing discovered target count'));
    await workflow;

    final state = container.read(dashboardProvider);
    expect(state.running, isFalse);
    expect(state.activeError?.title, 'Workflow failed');
    expect(state.activeError?.message, 'missing discovered target count');
  });
}

class _FixedClock implements AppClock {
  @override
  DateTime now() => DateTime(2026, 5, 5, 12);
}

class _AvailableBackend implements BackendAvailability {
  const _AvailableBackend();

  @override
  Future<bool> isAvailable(String path) async => true;
}

class _FakeRunnerFactory implements CoreProbeRunnerFactory {
  const _FakeRunnerFactory(this.runner);

  final _HoldingRunner runner;

  @override
  CoreProbeRunner create(
    String backend, {
    required String workingDirectory,
    required RunCancellation cancellation,
  }) {
    return runner;
  }
}

class _HoldingRunner extends CoreProbeRunner {
  _HoldingRunner()
    : started = Completer<void>(),
      candidateConnectStarted = Completer<void>(),
      timeoutFallbackStarted = Completer<void>(),
      _outcome = Completer<ScanOutcome>(),
      _candidateConnectOutcome = Completer<CandidateConnectOutcome>(),
      _timeoutFallbackOutcome = Completer<TimeoutFallbackOutcome>(),
      super('', workingDirectory: '', cancellation: RunCancellation());

  final Completer<void> started;
  final Completer<void> candidateConnectStarted;
  final Completer<void> timeoutFallbackStarted;
  final Completer<ScanOutcome> _outcome;
  final Completer<CandidateConnectOutcome> _candidateConnectOutcome;
  final Completer<TimeoutFallbackOutcome> _timeoutFallbackOutcome;
  ScoutConfig? lastConfig;
  bool? lastResume;

  void complete() {
    _outcome.complete(
      const ScanOutcome(
        targets: <Map<String, dynamic>>[],
        results: <Map<String, dynamic>>[],
        urltests: <Map<String, dynamic>>[],
        logs: <String>[],
        metrics: <String, dynamic>{},
      ),
    );
  }

  void fail(Object error) {
    _outcome.completeError(error);
  }

  void completeTimeoutFallback(TimeoutFallbackOutcome outcome) {
    _timeoutFallbackOutcome.complete(outcome);
  }

  void completeCandidateConnect(CandidateConnectOutcome outcome) {
    _candidateConnectOutcome.complete(outcome);
  }

  @override
  Future<ScanOutcome> scan(
    ScoutConfig config,
    List<Map<String, dynamic>> targets, {
    void Function(String line)? onProgress,
    bool resume = false,
  }) {
    lastConfig = config;
    lastResume = resume;
    if (!started.isCompleted) {
      started.complete();
    }
    return _outcome.future;
  }

  @override
  Future<CandidateConnectOutcome> connectCandidates(
    ScoutConfig config, {
    void Function(String line)? onProgress,
  }) {
    lastConfig = config;
    if (!candidateConnectStarted.isCompleted) {
      candidateConnectStarted.complete();
    }
    return _candidateConnectOutcome.future;
  }

  @override
  Future<TimeoutFallbackOutcome> timeoutFallback(
    ScoutConfig config, {
    void Function(String line)? onProgress,
  }) {
    lastConfig = config;
    if (!timeoutFallbackStarted.isCompleted) {
      timeoutFallbackStarted.complete();
    }
    return _timeoutFallbackOutcome.future;
  }
}

class _FailingFileRevealer implements PlatformFileRevealer {
  const _FailingFileRevealer(this.error);

  final Object error;

  @override
  Future<void> revealDirectory(String path) async {
    throw error;
  }

  @override
  Future<void> revealFile(String path) async {
    throw error;
  }
}
