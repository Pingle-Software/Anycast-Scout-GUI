import 'dart:io';

import 'package:anycast_scout_gui/src/features/probe_session/domain/dashboard_state.dart';
import 'package:anycast_scout_gui/src/features/probe_session/domain/session_summary.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/artifact_repository.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/session_payload.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/workflow_config.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/workspace_locator.dart';

Future<List<SessionSummary>> discoverSessionSummaries(
  DashboardState current,
) async {
  final found = <String, SessionSummary>{};
  final configured = current.text('session_path').trim();
  final configuredPath = configured.isEmpty
      ? ''
      : normalizeConfigPath(current.workspaceRoot, configured);

  void addFile(String path) {
    final summary = readSessionSummary(path);
    if (summary != null) {
      found[path] = summary;
    }
  }

  void scanDirectory(String path) {
    final directory = Directory(path);
    if (!directory.existsSync()) {
      return;
    }
    try {
      for (final entity in directory.listSync()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
          addFile(entity.path);
        }
      }
    } catch (_) {
      // Discovery should never fail the dashboard because of one directory.
    }
  }

  if (configuredPath.isNotEmpty) {
    addFile(configuredPath);
    scanDirectory(File(configuredPath).parent.path);
  }
  scanDirectory(current.workspaceRoot);

  final sessions = found.values.toList(growable: false);
  sessions.sort((left, right) {
    final saved = right.savedAtUnix.compareTo(left.savedAtUnix);
    return saved == 0 ? left.path.compareTo(right.path) : saved;
  });
  return sessions;
}

SessionSummary? readSessionSummary(String path) {
  try {
    final payload = SessionPayload.read(path);

    return SessionSummary(
      path: path,
      savedAtUnix: payload.savedAtUnix,
      status: payload.status,
      targets: payload.targetsCount,
      scanResults: payload.scanResultsCount,
      scanValid: payload.scanValidCount,
      usable: payload.usableCount,
      urltests: payload.urltestCount,
      connectOk: payload.connectOkCount,
    );
  } catch (_) {
    return null;
  }
}

Future<DashboardState> loadSessionFromFile(
  DashboardState current,
  String path,
) async {
  final payload = SessionPayload.read(path);
  final loadedConfig = Map<String, dynamic>.from(current.config)
    ..addAll(payload.config)
    ..['session_path'] = path;

  var next = applyLoadedConfig(current, loadedConfig);
  final savedMetrics = payload.metricsWithDerivedCounts();
  final sessionUsableResults = payload.usableResults;
  final sessionUrltests = payload.urltestResults;

  next = next.copyWith(
    coreBinaryPath: payload.coreBinaryPath ?? next.coreBinaryPath,
    status: 'Restored session',
    runOrigin: WorkflowRunOrigin.restored,
    restoredSessionPath: path,
    metrics: savedMetrics,
    usableResults: sessionUsableResults,
    urltestResults: sessionUrltests,
    logs: const <String>[],
    bootstrapping: false,
  );

  final artifacts = await readArtifacts(next, recomputeFromFiles: false);
  final restored = applyArtifacts(next, artifacts);
  return restored.copyWith(
    usableResults: restored.usableResults.isNotEmpty
        ? restored.usableResults
        : sessionUsableResults,
    urltestResults: restored.urltestResults.isNotEmpty
        ? restored.urltestResults
        : sessionUrltests,
  );
}
