import 'dart:convert';
import 'dart:io';

import 'package:anycast_scout_gui/src/features/probe_session/domain/artifact_snapshot.dart';
import 'package:anycast_scout_gui/src/features/probe_session/domain/dashboard_state.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/core_runner.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/session_payload.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/workflow_config.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/workspace_locator.dart';
import 'package:flutter/foundation.dart';

const _maxVisibleLogs = 2000;

Future<DashboardState> restoreSession(DashboardState current) async {
  var next = current;
  var restored = false;
  var sessionUsableResults = const <Map<String, dynamic>>[];
  var sessionUrltestResults = const <Map<String, dynamic>>[];
  final configFile = File(
    normalizeConfigPath(current.workspaceRoot, current.text('session_path')),
  );
  if (configFile.existsSync()) {
    try {
      final decoded = jsonDecode(await configFile.readAsString());
      if (decoded is Map) {
        final payload = SessionPayload.fromJson(
          Map<String, dynamic>.from(decoded),
          configFile.path,
        );
        restored = true;
        if (payload.config.isNotEmpty) {
          next = applyLoadedConfig(next, payload.config);
        }

        sessionUsableResults = payload.usableResults;
        sessionUrltestResults = payload.urltestResults;

        final savedMetrics = payload.metricsWithDerivedCounts();
        if (savedMetrics.isNotEmpty ||
            sessionUsableResults.isNotEmpty ||
            sessionUrltestResults.isNotEmpty) {
          next = next.copyWith(metrics: savedMetrics);
        }

        next = next.copyWith(
          usableResults: sessionUsableResults,
          urltestResults: sessionUrltestResults,
        );

        final coreBinaryPath = payload.coreBinaryPath;
        if (coreBinaryPath != null) {
          next = next.copyWith(coreBinaryPath: coreBinaryPath);
        }
      }
    } catch (_) {
      next = appendLog(next, 'session parse skipped: ${configFile.path}');
    }
  }

  final artifacts = await readArtifacts(next, recomputeFromFiles: false);
  final withArtifacts = applyArtifacts(next, artifacts);
  final usableResults = withArtifacts.usableResults.isNotEmpty
      ? withArtifacts.usableResults
      : sessionUsableResults;
  final urltestResults = withArtifacts.urltestResults.isNotEmpty
      ? withArtifacts.urltestResults
      : sessionUrltestResults;
  final restoredData =
      restored ||
      usableResults.isNotEmpty ||
      urltestResults.isNotEmpty ||
      withArtifacts.metricInt('target_count') > 0 ||
      withArtifacts.metricInt('scanned_count') > 0 ||
      withArtifacts.metricInt('scan_valid_count') > 0;

  return withArtifacts.copyWith(
    bootstrapping: false,
    runOrigin: restoredData
        ? WorkflowRunOrigin.restored
        : WorkflowRunOrigin.fresh,
    restoredSessionPath: restoredData ? configFile.path : null,
    usableResults: usableResults,
    urltestResults: urltestResults,
  );
}

Future<void> writeSessionSnapshot(
  DashboardState current, {
  String? statusOverride,
  DateTime? savedAt,
}) async {
  final file = File(
    normalizeConfigPath(current.workspaceRoot, current.text('session_path')),
  );
  await file.parent.create(recursive: true);
  final payload = {
    'version': sessionPayloadVersion,
    'saved_at_unix': (savedAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000,
    'config': buildConfig(current).toSessionConfigJson(),
    'last_targets': const <Map<String, dynamic>>[],
    'last_targets_label': 'Targets',
    'last_scan_results': current.usableResults,
    'last_urltest_results': current.urltestResults
        .take(32)
        .toList(growable: false),
    'last_urltest_count':
        current.metrics['urltest_count'] ?? current.urltestResults.length,
    'workflow_metrics': current.metrics,
    'gui': {
      'core_binary': current.coreBinaryPath.trim(),
      'status': statusOverride ?? current.status,
    },
  };
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
  );
}

Future<ArtifactSnapshot> readArtifacts(
  DashboardState current, {
  bool recomputeFromFiles = false,
}) async {
  final config = buildConfig(current);
  final rawScanFile = sessionArtifactFile(config, 'raw-scan.csv');
  final usableFile = sessionArtifactFile(config, 'usable.csv');
  final urltestFile = urltestArtifactFile(config);
  final targetsPath = config.text('targets_output').trim();
  final targetsFile = targetsPath.isEmpty
      ? null
      : File(config.resolvePath(targetsPath));

  final nextMetrics = Map<String, dynamic>.from(current.metrics);
  if (recomputeFromFiles && targetsFile != null && targetsFile.existsSync()) {
    nextMetrics['target_count'] = countTargetsArtifact(targetsFile);
  }

  if (recomputeFromFiles && rawScanFile.existsSync()) {
    nextMetrics.addAll(
      await compute(readCandidateArtifactMetrics, {
        'raw_scan': rawScanFile.path,
        'urltest': urltestFile.path,
      }),
    );
  }

  final usableResults = usableFile.existsSync()
      ? await compute(readPickedScanResultsArtifactPath, usableFile.path)
      : const <Map<String, dynamic>>[];
  nextMetrics['usable_count'] = usableResults.length;
  nextMetrics['usable_artifact'] = usableFile.path;
  nextMetrics['urltest_artifact'] = urltestFile.path;

  List<Map<String, dynamic>>? restoredUrltests;
  if (recomputeFromFiles) {
    if (urltestFile.existsSync()) {
      restoredUrltests = readUrltestArtifact(config);
      nextMetrics['urltest_count'] = restoredUrltests.length;
      nextMetrics['sing_box_ok_count'] = restoredUrltests
          .where((result) => result['ok'] == true)
          .length;
    }
  }

  return ArtifactSnapshot(
    metrics: nextMetrics,
    usableResults: usableResults,
    urltestResults: restoredUrltests,
  );
}

Future<DashboardState> clearCandidateArtifacts(DashboardState current) async {
  final config = buildConfig(current);
  final files = <File>[
    if (config.text('scan_output').trim().isNotEmpty)
      File(config.resolvePath(config.text('scan_output'))),
    sessionArtifactFile(config, 'usable.csv'),
    urltestArtifactFile(config),
  ];

  for (final file in files) {
    if (file.existsSync()) {
      await file.delete();
    }
  }

  final nextMetrics = Map<String, dynamic>.from(current.metrics)
    ..['usable_count'] = 0
    ..['urltest_count'] = 0
    ..['sing_box_ok_count'] = 0
    ..['candidate_connect_tested_count'] = 0
    ..['candidate_connect_ok_count'] = 0
    ..['candidate_connect_pending_count'] = current.metricInt(
      'scan_valid_count',
    );

  return current.copyWith(
    metrics: nextMetrics,
    usableResults: const <Map<String, dynamic>>[],
    urltestResults: const <Map<String, dynamic>>[],
    activeError: null,
  );
}

DashboardState applyArtifacts(
  DashboardState current,
  ArtifactSnapshot snapshot,
) {
  return current.copyWith(
    metrics: snapshot.metrics,
    usableResults: snapshot.usableResults,
    urltestResults: snapshot.urltestResults ?? current.urltestResults,
  );
}

DashboardState appendLog(DashboardState current, String line) {
  final nextLogs = <String>[...current.logs, line];
  if (nextLogs.length > _maxVisibleLogs) {
    nextLogs.removeRange(0, nextLogs.length - _maxVisibleLogs);
  }
  return current.copyWith(logs: nextLogs);
}

DashboardState ingestProgressLine(DashboardState current, String line) {
  final nextMetrics = Map<String, dynamic>.from(current.metrics);

  final scannedMatch = RegExp(r'scanned=(\d+)\s+valid=(\d+)').firstMatch(line);
  if (scannedMatch != null) {
    nextMetrics['scanned_count'] = int.parse(scannedMatch.group(1)!);
    nextMetrics['scan_valid_count'] = int.parse(scannedMatch.group(2)!);
  }

  final targetMatch = RegExp(
    r'(?:discovery targets written|discovered targets)=(\d+)',
  ).firstMatch(line);
  if (targetMatch != null) {
    nextMetrics['target_count'] = int.parse(targetMatch.group(1)!);
  }

  final urltestMatch = RegExp(
    r'sing-box batch start=\d+ size=\d+ scan-valid=(\d+) sing-box-ok=(\d+) usable=(\d+)',
  ).firstMatch(line);
  if (urltestMatch != null) {
    nextMetrics['scan_valid_count'] = int.parse(urltestMatch.group(1)!);
    nextMetrics['sing_box_ok_count'] = int.parse(urltestMatch.group(2)!);
    nextMetrics['usable_count'] = int.parse(urltestMatch.group(3)!);
  }

  final candidateConnectMatch = RegExp(
    r'candidate-connect candidates=(\d+) tested=(\d+) ok=(\d+) remaining=(\d+)',
  ).firstMatch(line);
  if (candidateConnectMatch != null) {
    nextMetrics['scan_valid_count'] = int.parse(
      candidateConnectMatch.group(1)!,
    );
    nextMetrics['candidate_connect_tested_count'] = int.parse(
      candidateConnectMatch.group(2)!,
    );
    nextMetrics['sing_box_ok_count'] = int.parse(
      candidateConnectMatch.group(3)!,
    );
    nextMetrics['candidate_connect_pending_count'] = int.parse(
      candidateConnectMatch.group(4)!,
    );
  }

  final timeoutFallbackMatch = RegExp(
    r'timeout-fallback candidates=(\d+) budget=\d+ tested=(\d+) ok=(\d+) remaining=(\d+)',
  ).firstMatch(line);
  if (timeoutFallbackMatch != null) {
    nextMetrics['timeout_fallback_candidate_count'] = int.parse(
      timeoutFallbackMatch.group(1)!,
    );
    nextMetrics['timeout_fallback_tested_count'] = int.parse(
      timeoutFallbackMatch.group(2)!,
    );
    nextMetrics['timeout_fallback_ok_count'] = int.parse(
      timeoutFallbackMatch.group(3)!,
    );
    nextMetrics['timeout_fallback_pending_count'] = int.parse(
      timeoutFallbackMatch.group(4)!,
    );
  }

  if (mapEquals(nextMetrics, current.metrics)) {
    return current;
  }
  return current.copyWith(metrics: nextMetrics);
}

bool isStatusLine(String line) {
  return line.startsWith('scan batch') ||
      line.startsWith('sing-box batch') ||
      line.startsWith('candidate-connect') ||
      line.startsWith('timeout-fallback') ||
      line.startsWith('scanned=') ||
      line.startsWith('warning:') ||
      line.startsWith('discovery targets written=') ||
      line.startsWith('discovered targets=');
}

bool shouldRefreshArtifacts(String line) {
  return isStatusLine(line) && !line.startsWith('scanned=');
}
