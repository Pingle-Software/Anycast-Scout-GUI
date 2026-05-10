import 'package:anycast_scout_gui/src/features/probe_session/domain/discovery_profile.dart';
import 'package:anycast_scout_gui/src/features/probe_session/domain/session_summary.dart';

const _unset = Object();

enum WorkflowRunOrigin { fresh, restored }

class DashboardError {
  const DashboardError({
    required this.title,
    required this.message,
    this.details,
  });

  final String title;
  final String message;
  final String? details;
}

class DashboardState {
  DashboardState({
    required this.workspaceRoot,
    required this.coreBinaryPath,
    required Map<String, dynamic> config,
    required this.formVersion,
    required this.running,
    required this.stopping,
    required this.bootstrapping,
    required this.status,
    required this.sessionStartedAt,
    required this.runOrigin,
    required this.restoredSessionPath,
    required Map<String, dynamic> metrics,
    required List<Map<String, dynamic>> usableResults,
    required List<Map<String, dynamic>> urltestResults,
    required List<SessionSummary> sessions,
    required List<String> logs,
    required this.activeError,
  }) : config = Map<String, dynamic>.unmodifiable(config),
       metrics = Map<String, dynamic>.unmodifiable(metrics),
       usableResults = _immutableRows(usableResults),
       urltestResults = _immutableRows(urltestResults),
       sessions = List<SessionSummary>.unmodifiable(sessions),
       logs = List<String>.unmodifiable(logs);

  const DashboardState._({
    required this.workspaceRoot,
    required this.coreBinaryPath,
    required this.config,
    required this.formVersion,
    required this.running,
    required this.stopping,
    required this.bootstrapping,
    required this.status,
    required this.sessionStartedAt,
    required this.runOrigin,
    required this.restoredSessionPath,
    required this.metrics,
    required this.usableResults,
    required this.urltestResults,
    required this.sessions,
    required this.logs,
    required this.activeError,
  });

  factory DashboardState.initial(
    String workspaceRoot,
    String coreBinaryPath,
    Map<String, dynamic> config,
  ) {
    return DashboardState(
      workspaceRoot: workspaceRoot,
      coreBinaryPath: coreBinaryPath,
      config: config,
      formVersion: 0,
      running: false,
      stopping: false,
      bootstrapping: true,
      status: 'Ready',
      sessionStartedAt: null,
      runOrigin: WorkflowRunOrigin.fresh,
      restoredSessionPath: null,
      metrics: const <String, dynamic>{},
      usableResults: const <Map<String, dynamic>>[],
      urltestResults: const <Map<String, dynamic>>[],
      sessions: const <SessionSummary>[],
      logs: const <String>[],
      activeError: null,
    );
  }

  final String workspaceRoot;
  final String coreBinaryPath;
  final Map<String, dynamic> config;
  final int formVersion;
  final bool running;
  final bool stopping;
  final bool bootstrapping;
  final String status;
  final DateTime? sessionStartedAt;
  final WorkflowRunOrigin runOrigin;
  final String? restoredSessionPath;
  final Map<String, dynamic> metrics;
  final List<Map<String, dynamic>> usableResults;
  final List<Map<String, dynamic>> urltestResults;
  final List<SessionSummary> sessions;
  final List<String> logs;
  final DashboardError? activeError;

  bool get restoredFromSession => runOrigin == WorkflowRunOrigin.restored;

  bool get canContinueRestoredSession => restoredFromSession && !running;

  String text(String key) => config[key]?.toString() ?? '';

  bool flag(String key) => config[key] == true;

  DiscoveryProfile get discoveryProfile => DiscoveryProfile.fromConfigValue(
    config[DiscoveryProfile.configKey],
    text('asn_list'),
  );

  int metricInt(String key) {
    final value = metrics[key];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DashboardState copyWith({
    String? coreBinaryPath,
    Map<String, dynamic>? config,
    int? formVersion,
    bool? running,
    bool? stopping,
    bool? bootstrapping,
    String? status,
    Object? sessionStartedAt = _unset,
    WorkflowRunOrigin? runOrigin,
    Object? restoredSessionPath = _unset,
    Map<String, dynamic>? metrics,
    List<Map<String, dynamic>>? usableResults,
    List<Map<String, dynamic>>? urltestResults,
    List<SessionSummary>? sessions,
    List<String>? logs,
    Object? activeError = _unset,
  }) {
    return DashboardState._(
      workspaceRoot: workspaceRoot,
      coreBinaryPath: coreBinaryPath ?? this.coreBinaryPath,
      config: config == null
          ? this.config
          : Map<String, dynamic>.unmodifiable(config),
      formVersion: formVersion ?? this.formVersion,
      running: running ?? this.running,
      stopping: stopping ?? this.stopping,
      bootstrapping: bootstrapping ?? this.bootstrapping,
      status: status ?? this.status,
      sessionStartedAt: identical(sessionStartedAt, _unset)
          ? this.sessionStartedAt
          : sessionStartedAt as DateTime?,
      runOrigin: runOrigin ?? this.runOrigin,
      restoredSessionPath: identical(restoredSessionPath, _unset)
          ? this.restoredSessionPath
          : restoredSessionPath as String?,
      metrics: metrics == null
          ? this.metrics
          : Map<String, dynamic>.unmodifiable(metrics),
      usableResults: usableResults == null
          ? this.usableResults
          : _immutableRows(usableResults),
      urltestResults: urltestResults == null
          ? this.urltestResults
          : _immutableRows(urltestResults),
      sessions: sessions == null
          ? this.sessions
          : List<SessionSummary>.unmodifiable(sessions),
      logs: logs == null ? this.logs : List<String>.unmodifiable(logs),
      activeError: identical(activeError, _unset)
          ? this.activeError
          : activeError as DashboardError?,
    );
  }
}

List<Map<String, dynamic>> _immutableRows(List<Map<String, dynamic>> rows) {
  return List<Map<String, dynamic>>.unmodifiable(
    rows.map((row) => Map<String, dynamic>.unmodifiable(row)),
  );
}
