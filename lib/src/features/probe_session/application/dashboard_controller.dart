import 'dart:async';
import 'dart:io';

import 'package:anycast_scout_gui/src/features/probe_session/domain/dashboard_state.dart';
import 'package:anycast_scout_gui/src/features/probe_session/domain/discovery_profile.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/artifact_repository.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/backend_availability.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/core_probe_runner_factory.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/core_runner.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/file_selection_service.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/platform_file_revealer.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/session_repository.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/system_clock.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/workflow_config.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/workspace_locator.dart';
import 'package:anycast_scout_gui/src/shared/config/ui_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardProvider = NotifierProvider<DashboardController, DashboardState>(
  DashboardController.new,
);

enum WorkflowStartMode { newSession, continueRestored }

enum _PostStopAction { checkCandidates }

const _progressFlushInterval = Duration(milliseconds: 100);
const _maxBufferedProgressLines = 128;

class DashboardController extends Notifier<DashboardState> {
  RunCancellation? _cancellation;
  DateTime? _lastArtifactRefreshAt;
  Timer? _progressFlushTimer;
  final List<String> _pendingProgressLines = <String>[];
  _PostStopAction? _postStopAction;
  bool _bootstrapped = false;

  @override
  DashboardState build() {
    ref.onDispose(() {
      _progressFlushTimer?.cancel();
      _cancellation?.cancel();
    });

    final workspaceRoot = detectWorkspaceRoot();
    final initial = DashboardState.initial(
      workspaceRoot,
      detectCoreBinary(workspaceRoot),
      defaultConfigValues(workspaceRoot),
    );
    if (!_bootstrapped) {
      _bootstrapped = true;
      unawaited(_bootstrap(initial));
    }
    return initial;
  }

  void updateCoreBinary(String value) {
    _patch((current) => current.copyWith(coreBinaryPath: value));
  }

  void updateTextField(String key, String value) {
    _patch((current) {
      final nextConfig = Map<String, dynamic>.from(current.config)
        ..[key] = value;
      return current.copyWith(config: nextConfig);
    });
  }

  void updateBoolField(String key, bool value) {
    _patch((current) {
      final nextConfig = Map<String, dynamic>.from(current.config)
        ..[key] = value;
      return current.copyWith(config: nextConfig);
    });
  }

  void updateChoiceField(String key, String value) {
    updateTextField(key, value);
  }

  void updateDiscoveryProfile(DiscoveryProfile value) {
    _patch((current) {
      final nextConfig = Map<String, dynamic>.from(current.config)
        ..[DiscoveryProfile.configKey] = value.name;
      if (value == DiscoveryProfile.cloudflareCandidates) {
        nextConfig['asn_list'] = defaultCloudflareAsnList;
        nextConfig['limit_targets'] = false;
      }
      return current.copyWith(
        config: normalizeConfigValues(current.workspaceRoot, nextConfig),
        formVersion: current.formVersion + 1,
      );
    });
  }

  Future<void> pickCoreBinary() async {
    try {
      final path = await ref
          .read(fileSelectionGatewayProvider)
          .pickExecutable();
      if (path != null && path.trim().isNotEmpty) {
        updateCoreBinary(path);
      }
    } catch (error) {
      _reportError('Core binary selection failed', error);
    }
  }

  Future<void> pickSingBoxConfig() async {
    try {
      final path = await ref.read(fileSelectionGatewayProvider).pickJsonFile();
      if (path != null && path.trim().isNotEmpty) {
        final trimmed = path.trim();
        final tags = singBoxOutboundTagsFromPath(state.workspaceRoot, trimmed);
        _patch((current) {
          final currentOutbound = current.text('outbound_tag');
          final nextConfig = Map<String, dynamic>.from(current.config)
            ..['sing_box_config'] = trimmed;
          if (!tags.contains(currentOutbound)) {
            nextConfig['outbound_tag'] = tags.contains(defaultOutboundTag)
                ? defaultOutboundTag
                : tags.firstOrNull ?? currentOutbound;
          }
          return current.copyWith(
            config: nextConfig,
            formVersion: current.formVersion + 1,
          );
        });
      }
    } catch (error) {
      _reportError('Sing-box config selection failed', error);
    }
  }

  Future<void> openSessionFile() async {
    try {
      final path = await ref
          .read(fileSelectionGatewayProvider)
          .pickSessionJsonFile();
      if (path != null && path.trim().isNotEmpty) {
        await loadSessionFromPath(path);
      }
    } catch (error) {
      _reportError('Session file selection failed', error);
    }
  }

  Future<void> loadSessionFromPath(String path) async {
    try {
      final loaded = await _loadSessionState(path);
      if (!ref.mounted) {
        return;
      }
      state = loaded;
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      _reportError('Session restore failed', error);
    }
  }

  Future<void> continueSessionFromPath(String path) async {
    try {
      final loaded = await _loadSessionState(path);
      if (!ref.mounted) {
        return;
      }
      state = loaded;
      await _startWorkflow(WorkflowStartMode.continueRestored);
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      _reportError('Session continue failed', error);
    }
  }

  Future<void> checkCandidatesFromPath(String path) async {
    try {
      final loaded = await _loadSessionState(path);
      if (!ref.mounted) {
        return;
      }
      state = loaded;
      await _startCandidateConnect();
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      _reportError('Candidate check failed', error);
    }
  }

  Future<DashboardState> _loadSessionState(String path) async {
    final loaded = await loadSessionFromFile(state, path);
    final sessions = await discoverSessionSummaries(loaded);
    return loaded.copyWith(sessions: sessions, activeError: null);
  }

  Future<void> refreshSessions() async {
    try {
      final sessions = await discoverSessionSummaries(state);
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        sessions: sessions,
        status: sessions.isEmpty
            ? 'No saved sessions found'
            : 'Loaded ${sessions.length} sessions',
        activeError: null,
      );
    } catch (error) {
      _reportError('Session refresh failed', error);
    }
  }

  Future<void> revealSessionFile(String path) async {
    try {
      await ref.read(platformFileRevealerProvider).revealFile(path);
    } catch (error) {
      _reportError('Could not reveal session file', error);
    }
  }

  Future<void> openUsableCsv() async {
    try {
      final current = state;
      final file = sessionArtifactFile(buildConfig(current), 'usable.csv');
      if (file.existsSync()) {
        await ref.read(platformFileRevealerProvider).revealFile(file.path);
        state = state.copyWith(activeError: null);
        return;
      }
      _reportUserError(
        'Usable CSV not found',
        'Run a workflow successfully before opening the usable CSV.',
        details: file.path,
      );
    } catch (error) {
      _reportError('Could not open usable CSV', error);
    }
  }

  Future<void> revealSessionFolder() async {
    try {
      final current = state;
      final file = File(
        normalizeConfigPath(
          current.workspaceRoot,
          current.text('session_path'),
        ),
      );
      if (file.parent.existsSync()) {
        await ref
            .read(platformFileRevealerProvider)
            .revealDirectory(file.parent.path);
        state = state.copyWith(activeError: null);
        return;
      }
      _reportUserError(
        'Session folder not found',
        'The configured session folder does not exist.',
        details: file.parent.path,
      );
    } catch (error) {
      _reportError('Could not reveal session folder', error);
    }
  }

  Future<void> startWorkflow() async {
    try {
      await _startWorkflow(
        state.restoredFromSession
            ? WorkflowStartMode.continueRestored
            : WorkflowStartMode.newSession,
      );
    } catch (error) {
      _reportError('Workflow start failed', error);
    }
  }

  Future<void> continueTimeoutFallback() async {
    try {
      await _startTimeoutFallback();
    } catch (error) {
      _reportError('Timeout fallback failed', error);
    }
  }

  Future<void> checkCandidates() async {
    try {
      if (state.running) {
        _postStopAction = _PostStopAction.checkCandidates;
        stopWorkflow();
        return;
      }
      await _startCandidateConnect();
    } catch (error) {
      _reportError('Candidate check failed', error);
    }
  }

  Future<void> clearCandidateChecks() async {
    try {
      if (state.running) {
        _reportUserError(
          'Workflow is running',
          'Stop the current workflow before clearing Connect results.',
        );
        return;
      }
      final cleared = await clearCandidateArtifacts(state);
      if (!ref.mounted) {
        return;
      }
      state = appendLog(cleared, 'candidate connect artifacts cleared');
      await writeSessionSnapshot(
        state,
        statusOverride: state.status,
        savedAt: ref.read(appClockProvider).now(),
      );
      await _refreshSessionsSilently();
    } catch (error) {
      _reportError('Candidate cleanup failed', error);
    }
  }

  Future<void> _startWorkflow(WorkflowStartMode mode) async {
    final current = state;
    if (current.running) {
      return;
    }

    if (!await _ensureWorkflowReady(current)) {
      return;
    }

    final backend = current.coreBinaryPath.trim();
    _cancellation = RunCancellation();
    _lastArtifactRefreshAt = null;
    final now = ref.read(appClockProvider).now();
    final prepared = mode == WorkflowStartMode.newSession
        ? _prepareNewSession(current, now)
        : current.copyWith(
            runOrigin: current.restoredFromSession
                ? WorkflowRunOrigin.restored
                : WorkflowRunOrigin.fresh,
          );

    final startingState = prepared.copyWith(
      running: true,
      stopping: false,
      bootstrapping: false,
      status: 'Running',
      activeError: null,
      sessionStartedAt: now,
      runOrigin: mode == WorkflowStartMode.newSession
          ? WorkflowRunOrigin.fresh
          : prepared.runOrigin,
      restoredSessionPath: mode == WorkflowStartMode.newSession
          ? null
          : prepared.restoredSessionPath,
      metrics: mode == WorkflowStartMode.newSession
          ? const <String, dynamic>{}
          : prepared.metrics,
      usableResults: mode == WorkflowStartMode.newSession
          ? const <Map<String, dynamic>>[]
          : prepared.usableResults,
      urltestResults: mode == WorkflowStartMode.newSession
          ? const <Map<String, dynamic>>[]
          : prepared.urltestResults,
      logs: const <String>[],
    );
    state = startingState;
    await writeSessionSnapshot(
      startingState,
      statusOverride: 'Starting',
      savedAt: now,
    );

    final runner = ref
        .read(coreProbeRunnerFactoryProvider)
        .create(
          backend,
          workingDirectory: current.workspaceRoot,
          cancellation: _cancellation!,
        );

    try {
      final outcome = await runner.scan(
        buildConfig(startingState),
        const <Map<String, dynamic>>[],
        onProgress: handleProgress,
        resume: mode == WorkflowStartMode.continueRestored,
      );
      _flushProgress();
      if (!ref.mounted) {
        return;
      }

      final latest = state;
      final pickedResults = pickedScanResults(outcome.results);
      final updatedMetrics = Map<String, dynamic>.from(outcome.metrics)
        ..['usable_count'] = pickedResults.length
        ..['sing_box_ok_count'] = outcome.urltests
            .where((result) => result['ok'] == true)
            .length;

      final finished = latest.copyWith(
        metrics: updatedMetrics,
        urltestResults: outcome.urltests,
        status: 'Finished',
        running: false,
        stopping: false,
        sessionStartedAt: null,
        runOrigin: WorkflowRunOrigin.fresh,
        restoredSessionPath: null,
      );
      state = finished;
      await refreshArtifacts();
      await writeSessionSnapshot(
        state,
        savedAt: ref.read(appClockProvider).now(),
      );
      await _refreshSessionsSilently();
    } catch (error) {
      _flushProgress();
      if (!ref.mounted) {
        return;
      }

      final latest = state;
      if (isWorkflowCancelled(error)) {
        state = appendLog(
          latest.copyWith(
            status: 'Stopped',
            running: false,
            stopping: false,
            sessionStartedAt: null,
            activeError: null,
          ),
          'Stopped',
        );
      } else {
        state = _attachError(
          latest.copyWith(
            status: 'Failed',
            running: false,
            stopping: false,
            sessionStartedAt: null,
          ),
          _dashboardError('Workflow failed', error),
          status: 'Failed',
        );
      }

      await refreshArtifacts();
      await writeSessionSnapshot(
        state,
        statusOverride: state.status,
        savedAt: ref.read(appClockProvider).now(),
      );
      await _refreshSessionsSilently();
    } finally {
      _progressFlushTimer?.cancel();
      _progressFlushTimer = null;
      _pendingProgressLines.clear();
      _cancellation = null;
      await _runPostStopAction();
    }
  }

  Future<void> _startCandidateConnect() async {
    final current = state;
    if (current.running) {
      return;
    }
    if (!await _ensureWorkflowReady(current)) {
      return;
    }

    final backend = current.coreBinaryPath.trim();
    _cancellation = RunCancellation();
    _lastArtifactRefreshAt = null;
    final now = ref.read(appClockProvider).now();
    state = appendLog(
      current.copyWith(
        running: true,
        stopping: false,
        bootstrapping: false,
        status: 'Candidate Connect',
        activeError: null,
        sessionStartedAt: now,
      ),
      'candidate connect requested',
    );
    await writeSessionSnapshot(
      state,
      statusOverride: 'Candidate Connect',
      savedAt: now,
    );

    final runner = ref
        .read(coreProbeRunnerFactoryProvider)
        .create(
          backend,
          workingDirectory: current.workspaceRoot,
          cancellation: _cancellation!,
        );

    try {
      final outcome = await runner.connectCandidates(
        buildConfig(state),
        onProgress: handleProgress,
      );
      _flushProgress();
      if (!ref.mounted) {
        return;
      }

      await refreshArtifacts(recomputeFromFiles: true);
      if (!ref.mounted) {
        return;
      }

      final latest = state;
      final metrics = Map<String, dynamic>.from(latest.metrics)
        ..['candidate_connect_candidate_count'] = outcome.candidateCount
        ..['candidate_connect_tested_count'] = outcome.testedCount
        ..['candidate_connect_ok_count'] = outcome.successfulCount
        ..['candidate_connect_pending_count'] = outcome.remainingCount;
      final status = outcome.testedCount == 0
          ? 'No pending candidates'
          : 'Finished';
      state = appendLog(
        latest.copyWith(
          metrics: metrics,
          status: status,
          running: false,
          stopping: false,
          sessionStartedAt: null,
          activeError: null,
        ),
        'candidate connect finished tested=${outcome.testedCount} '
        'ok=${outcome.successfulCount} remaining=${outcome.remainingCount}',
      );
      await writeSessionSnapshot(
        state,
        statusOverride: state.status,
        savedAt: ref.read(appClockProvider).now(),
      );
      await _refreshSessionsSilently();
    } catch (error) {
      _flushProgress();
      if (!ref.mounted) {
        return;
      }

      final latest = state;
      if (isWorkflowCancelled(error)) {
        state = appendLog(
          latest.copyWith(
            status: 'Stopped',
            running: false,
            stopping: false,
            sessionStartedAt: null,
            activeError: null,
          ),
          'candidate connect stopped',
        );
      } else {
        state = _attachError(
          latest.copyWith(
            status: 'Failed',
            running: false,
            stopping: false,
            sessionStartedAt: null,
          ),
          _dashboardError('Candidate check failed', error),
          status: 'Failed',
        );
      }

      await refreshArtifacts(recomputeFromFiles: true);
      await writeSessionSnapshot(
        state,
        statusOverride: state.status,
        savedAt: ref.read(appClockProvider).now(),
      );
      await _refreshSessionsSilently();
    } finally {
      _progressFlushTimer?.cancel();
      _progressFlushTimer = null;
      _pendingProgressLines.clear();
      _cancellation = null;
      await _runPostStopAction();
    }
  }

  Future<void> _startTimeoutFallback() async {
    final current = state;
    if (current.running) {
      return;
    }
    if (!await _ensureWorkflowReady(current)) {
      return;
    }

    final backend = current.coreBinaryPath.trim();
    _cancellation = RunCancellation();
    _lastArtifactRefreshAt = null;
    final now = ref.read(appClockProvider).now();
    state = appendLog(
      current.copyWith(
        running: true,
        stopping: false,
        bootstrapping: false,
        status: 'Timeout fallback',
        activeError: null,
        sessionStartedAt: now,
      ),
      'timeout fallback requested',
    );
    await writeSessionSnapshot(
      state,
      statusOverride: 'Timeout fallback',
      savedAt: now,
    );

    final runner = ref
        .read(coreProbeRunnerFactoryProvider)
        .create(
          backend,
          workingDirectory: current.workspaceRoot,
          cancellation: _cancellation!,
        );

    try {
      final outcome = await runner.timeoutFallback(
        buildConfig(state),
        onProgress: handleProgress,
      );
      _flushProgress();
      if (!ref.mounted) {
        return;
      }

      await refreshArtifacts(recomputeFromFiles: true);
      if (!ref.mounted) {
        return;
      }

      final latest = state;
      final metrics = Map<String, dynamic>.from(latest.metrics)
        ..['timeout_fallback_candidate_count'] = outcome.candidateCount
        ..['timeout_fallback_tested_count'] = outcome.testedCount
        ..['timeout_fallback_ok_count'] = outcome.successfulCount
        ..['timeout_fallback_pending_count'] = outcome.remainingCount;
      final status = outcome.testedCount == 0
          ? 'No timeout fallback candidates'
          : 'Finished';
      state = appendLog(
        latest.copyWith(
          metrics: metrics,
          status: status,
          running: false,
          stopping: false,
          sessionStartedAt: null,
          activeError: null,
        ),
        'timeout fallback finished tested=${outcome.testedCount} '
        'ok=${outcome.successfulCount} remaining=${outcome.remainingCount}',
      );
      await writeSessionSnapshot(
        state,
        statusOverride: state.status,
        savedAt: ref.read(appClockProvider).now(),
      );
      await _refreshSessionsSilently();
    } catch (error) {
      _flushProgress();
      if (!ref.mounted) {
        return;
      }

      final latest = state;
      if (isWorkflowCancelled(error)) {
        state = appendLog(
          latest.copyWith(
            status: 'Stopped',
            running: false,
            stopping: false,
            sessionStartedAt: null,
            activeError: null,
          ),
          'timeout fallback stopped',
        );
      } else {
        state = _attachError(
          latest.copyWith(
            status: 'Failed',
            running: false,
            stopping: false,
            sessionStartedAt: null,
          ),
          _dashboardError('Timeout fallback failed', error),
          status: 'Failed',
        );
      }

      await refreshArtifacts(recomputeFromFiles: true);
      await writeSessionSnapshot(
        state,
        statusOverride: state.status,
        savedAt: ref.read(appClockProvider).now(),
      );
      await _refreshSessionsSilently();
    } finally {
      _progressFlushTimer?.cancel();
      _progressFlushTimer = null;
      _pendingProgressLines.clear();
      _cancellation = null;
      await _runPostStopAction();
    }
  }

  Future<void> _runPostStopAction() async {
    final action = _postStopAction;
    _postStopAction = null;
    if (!ref.mounted || action == null) {
      return;
    }

    switch (action) {
      case _PostStopAction.checkCandidates:
        await _startCandidateConnect();
    }
  }

  void stopWorkflow() {
    final current = state;
    if (!current.running || current.stopping) {
      return;
    }
    _cancellation?.cancel();
    state = appendLog(
      current.copyWith(stopping: true, status: 'Stopping...'),
      'stop requested',
    );
  }

  Future<void> refreshArtifacts({bool recomputeFromFiles = false}) async {
    try {
      final current = state;
      final snapshot = await readArtifacts(
        current,
        recomputeFromFiles: recomputeFromFiles,
      );
      if (!ref.mounted) {
        return;
      }
      state = applyArtifacts(state, snapshot);
    } catch (error) {
      _reportError('Artifact refresh failed', error);
    }
  }

  void handleProgress(String line) {
    if (!ref.mounted) {
      return;
    }

    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _pendingProgressLines.add(trimmed);

    if (_pendingProgressLines.length >= _maxBufferedProgressLines) {
      _flushProgress();
      return;
    }

    _progressFlushTimer ??= Timer(_progressFlushInterval, _flushProgress);
  }

  void _flushProgress() {
    _progressFlushTimer?.cancel();
    _progressFlushTimer = null;

    if (_pendingProgressLines.isEmpty || !ref.mounted) {
      return;
    }

    final lines = List<String>.of(_pendingProgressLines);
    _pendingProgressLines.clear();

    var next = state;
    var shouldRefresh = false;
    for (final line in lines) {
      next = appendLog(next, line);
      next = ingestProgressLine(next, line);
      if (isStatusLine(line)) {
        next = next.copyWith(status: line);
      }
      shouldRefresh = shouldRefresh || shouldRefreshArtifacts(line);
    }
    state = next;

    if (shouldRefresh) {
      final now = ref.read(appClockProvider).now();
      if (_lastArtifactRefreshAt == null ||
          now.difference(_lastArtifactRefreshAt!) >=
              AppDurations.artifactRefresh) {
        _lastArtifactRefreshAt = now;
        unawaited(refreshArtifacts());
      }
    }
  }

  Future<void> _bootstrap(DashboardState initial) async {
    try {
      final restored = await restoreSession(initial);
      if (!ref.mounted) {
        return;
      }
      final sessions = await discoverSessionSummaries(restored);
      if (!ref.mounted) {
        return;
      }
      if (!_canApplyBootstrap(initial)) {
        return;
      }
      state = restored.copyWith(sessions: sessions, activeError: null);
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      if (!_canApplyBootstrap(initial)) {
        return;
      }
      state = _attachError(
        initial.copyWith(bootstrapping: false),
        _dashboardError('Session restore skipped', error),
        status: 'Ready',
      );
    }
  }

  void clearError() {
    _patch((current) => current.copyWith(activeError: null));
  }

  bool _canApplyBootstrap(DashboardState initial) {
    final current = state;
    return !current.running &&
        !current.stopping &&
        current.activeError == null &&
        current.formVersion == initial.formVersion &&
        current.status == initial.status &&
        current.logs.isEmpty;
  }

  void _patch(DashboardState Function(DashboardState current) transform) {
    state = transform(state);
  }

  Future<bool> _ensureWorkflowReady(DashboardState current) async {
    final backend = current.coreBinaryPath.trim();
    if (backend.isEmpty) {
      _reportUserError(
        'Core binary path is empty',
        'Choose a valid anycast-scout binary before starting.',
        status: 'Core binary path is empty',
      );
      return false;
    }

    if (!await ref.read(backendAvailabilityProvider).isAvailable(backend)) {
      _reportUserError(
        'Core binary not found',
        'The configured anycast-scout binary could not be found.',
        details: backend,
        status: 'Core binary not found',
      );
      return false;
    }

    final singBoxConfig = current.text('sing_box_config').trim();
    if (singBoxConfig.isEmpty || singBoxConfig == selectJsonConfigFile) {
      _reportUserError(
        'Select JSON config file',
        'Choose a sing-box JSON config before running Connect checks.',
        status: 'Select JSON config file',
      );
      return false;
    }

    return true;
  }

  Future<void> _refreshSessionsSilently() async {
    try {
      final sessions = await discoverSessionSummaries(state);
      if (ref.mounted) {
        state = state.copyWith(sessions: sessions);
      }
    } catch (error) {
      _reportError('Session refresh failed', error);
    }
  }

  void _reportError(String title, Object error, {String? status}) {
    if (!ref.mounted) {
      return;
    }
    state = _attachError(state, _dashboardError(title, error), status: status);
  }

  void _reportUserError(
    String title,
    String message, {
    String? details,
    String? status,
  }) {
    state = _attachError(
      state,
      DashboardError(title: title, message: message, details: details),
      status: status ?? title,
    );
  }

  DashboardState _attachError(
    DashboardState current,
    DashboardError error, {
    String? status,
  }) {
    final details = error.details?.trim();
    final logLine = details == null || details.isEmpty
        ? '${error.title}: ${error.message}'
        : '${error.title}: ${error.message} [$details]';
    return appendLog(
      current.copyWith(status: status ?? error.title, activeError: error),
      logLine,
    );
  }
}

DashboardError _dashboardError(String title, Object error) {
  return DashboardError(
    title: title,
    message: userFacingErrorMessage(error),
    details: technicalErrorDetails(error),
  );
}

String userFacingErrorMessage(Object error) {
  if (error is FileSystemException) {
    return error.message;
  }
  if (error is FormatException) {
    return error.message;
  }
  if (error is ProcessException) {
    final message = error.message.trim();
    return message.isEmpty
        ? 'Process exited with code ${error.errorCode}.'
        : message;
  }
  if (error is StateError) {
    return error.message;
  }
  final text = error.toString().trim();
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  return text.isEmpty ? 'Unexpected error.' : text;
}

String? technicalErrorDetails(Object error) {
  if (error is FileSystemException) {
    final path = error.path;
    return path == null || path.isEmpty ? null : path;
  }
  if (error is ProcessException) {
    final args = error.arguments.join(' ');
    final command = args.isEmpty
        ? error.executable
        : '${error.executable} $args';
    return '$command exited ${error.errorCode}';
  }
  if (error is FormatException) {
    final source = error.source?.toString();
    return source == null || source.isEmpty ? null : source;
  }
  return null;
}

DashboardState _prepareNewSession(DashboardState current, DateTime now) {
  final sessionPath = normalizeConfigPath(
    current.workspaceRoot,
    current.text('session_path'),
  );
  final sessionFile = File(
    sessionPath.isEmpty
        ? '${current.workspaceRoot}/anycast-scout-session.json'
        : sessionPath,
  );
  final directory = sessionFile.parent.path.isEmpty
      ? current.workspaceRoot
      : sessionFile.parent.path;
  final stem = '${_sessionStem(sessionFile.path)}-${_timestamp(now)}';
  final nextConfig = Map<String, dynamic>.from(current.config)
    ..['session_path'] = '$directory/$stem.json'
    ..['targets_output'] = '$directory/$stem.targets.csv'
    ..['scan_output'] = '$directory/$stem.selected.csv'
    ..['urltest_output'] = '$directory/$stem.urltests.jsonl';

  return current.copyWith(
    config: normalizeConfigValues(current.workspaceRoot, nextConfig),
    formVersion: current.formVersion + 1,
    runOrigin: WorkflowRunOrigin.fresh,
    restoredSessionPath: null,
    metrics: const <String, dynamic>{},
    usableResults: const <Map<String, dynamic>>[],
    urltestResults: const <Map<String, dynamic>>[],
  );
}

String _sessionStem(String path) {
  final parts = path.split(RegExp(r'[\\/]'));
  final fileName = parts.isEmpty ? 'anycast-scout-session.json' : parts.last;
  return fileName.toLowerCase().endsWith('.json')
      ? fileName.substring(0, fileName.length - 5)
      : fileName;
}

String _timestamp(DateTime value) {
  final local = value.toLocal();
  return '${local.year}${_pad(local.month)}${_pad(local.day)}-'
      '${_pad(local.hour)}${_pad(local.minute)}${_pad(local.second)}';
}

String _pad(int value) => value.toString().padLeft(2, '0');
