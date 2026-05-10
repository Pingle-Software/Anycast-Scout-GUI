import 'dart:convert';
import 'dart:io';

const selectJsonConfigFile = 'Select JSON config file';

class ScoutConfig {
  ScoutConfig(Map<String, dynamic> values) : values = Map.of(values);

  factory ScoutConfig.fromJson(Map<String, dynamic> json) {
    final values = {...defaults, ...json};
    final launchCwd = values['launch_cwd']?.toString() ?? '';
    if (launchCwd.trim().isEmpty) {
      values['launch_cwd'] = Directory.current.path;
    }
    return ScoutConfig(values);
  }

  static const defaults = <String, dynamic>{
    'launch_cwd': '',
    'session_path': 'anycast-scout-session.json',
    'input_path': '',
    'manual_targets': '',
    'asn_list': 'AS13335,AS209242,AS14789,AS395747,AS394536',
    'discovery_scope': 'OriginAndAsPath',
    'all_hosts': true,
    'limit_targets': false,
    'max_targets': '',
    'port': '443',
    'concurrency': '16',
    'timeout_ms': '2500',
    'request_interval_ms': '250',
    'max_valid': '',
    'speed_url': 'https://speed.cloudflare.com/__down?bytes=10000000',
    'speed_seconds': '3',
    'download_url': 'https://speed.cloudflare.com/__down?bytes=20480',
    'min_download_bytes': '20480',
    'download_timeout_ms': '5000',
    'timeout_fallback_budget': '500',
    'targets_output': 'cf-edge-targets.csv',
    'scan_output': 'cf-edge-selected.csv',
    'sing_box_config': selectJsonConfigFile,
    'outbound_tag': '🇩🇪 Germany CDN 1',
    'urltest_concurrency': '4',
    'sing_box_bin': 'auto',
    'urltest_output': 'cf-edge-urltests.jsonl',
  };

  final Map<String, dynamic> values;

  String text(String key) => values[key]?.toString() ?? '';

  bool flag(String key) => values[key] == true;

  String get sessionPath => text('session_path');

  String get launchCwd => text('launch_cwd');

  Map<String, dynamic> toSessionConfigJson() {
    final json = Map<String, dynamic>.of(values);
    json.remove('launch_cwd');
    return json;
  }

  String resolvePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || isAbsolutePath(trimmed)) {
      return trimmed;
    }
    final base = launchCwd.trim();
    if (base.isEmpty || base == '.') {
      return trimmed;
    }
    return '$base/$trimmed';
  }
}

class ScanOutcome {
  const ScanOutcome({
    required this.targets,
    required this.results,
    required this.urltests,
    required this.logs,
    required this.metrics,
  });

  final List<Map<String, dynamic>> targets;
  final List<Map<String, dynamic>> results;
  final List<Map<String, dynamic>> urltests;
  final List<String> logs;
  final Map<String, dynamic> metrics;
}

class TimeoutFallbackOutcome {
  const TimeoutFallbackOutcome({
    required this.candidateCount,
    required this.testedCount,
    required this.successfulCount,
    required this.remainingCount,
  });

  final int candidateCount;
  final int testedCount;
  final int successfulCount;
  final int remainingCount;
}

class CandidateConnectOutcome {
  const CandidateConnectOutcome({
    required this.candidateCount,
    required this.testedCount,
    required this.successfulCount,
    required this.remainingCount,
  });

  final int candidateCount;
  final int testedCount;
  final int successfulCount;
  final int remainingCount;
}

class WorkflowCancelled implements Exception {
  const WorkflowCancelled();

  @override
  String toString() => 'Workflow cancelled';
}

bool isWorkflowCancelled(Object error) => error is WorkflowCancelled;

class RunCancellation {
  bool _cancelRequested = false;
  final Set<Process> _activeProcesses = Set<Process>.identity();

  bool get isCancelled => _cancelRequested;

  void attachProcess(Process process) {
    _activeProcesses.add(process);
    if (_cancelRequested) {
      process.kill(ProcessSignal.sigterm);
    }
  }

  void detachProcess(Process process) {
    _activeProcesses.remove(process);
  }

  void cancel() {
    _cancelRequested = true;
    for (final process in _activeProcesses.toList(growable: false)) {
      process.kill(ProcessSignal.sigterm);
    }
  }
}

class CoreProbeRunner {
  CoreProbeRunner(
    this.coreBin, {
    required this.workingDirectory,
    required this.cancellation,
  });

  final String coreBin;
  final String workingDirectory;
  final RunCancellation cancellation;

  Future<ScanOutcome> scan(
    ScoutConfig config,
    List<Map<String, dynamic>> targets, {
    void Function(String line)? onProgress,
    bool resume = false,
  }) async {
    throwIfCancelled();
    final scanInputs = <String>[];
    final resolvedTargets = <Map<String, dynamic>>[];
    final logs = <String>[];
    final metrics = <String, dynamic>{};
    Directory? tempDir;
    final asnConfigured = splitValues(config.text('asn_list')).isNotEmpty;
    final rawScanOutput = sessionArtifactFile(config, 'raw-scan.csv');

    final useLastTargets = targets.isNotEmpty && !asnConfigured;
    if (useLastTargets) {
      final targetArtifact = config.text('targets_output').trim();
      if (targetArtifact.isNotEmpty) {
        final targetFile = File(config.resolvePath(targetArtifact));
        if (targetFile.existsSync()) {
          scanInputs.add(targetFile.path);
        }
      }
      if (scanInputs.isEmpty && targets.isNotEmpty) {
        tempDir = await Directory.systemTemp.createTemp('anycast-scout-gui-');
        final targetFile = File('${tempDir.path}/targets.json');
        await targetFile.writeAsString('${jsonEncode(targets)}\n');
        scanInputs.add(targetFile.path);
        resolvedTargets.addAll(targets);
      }
    } else {
      final inputPath = config.text('input_path').trim();
      if (inputPath.isNotEmpty) {
        scanInputs.add(config.resolvePath(inputPath));
      }
      final manual = splitManualTargets(config.text('manual_targets'));
      if (manual.isNotEmpty) {
        tempDir = await Directory.systemTemp.createTemp('anycast-scout-gui-');
        final manualFile = File('${tempDir.path}/manual-targets.txt');
        await manualFile.writeAsString('${manual.join('\n')}\n');
        scanInputs.add(manualFile.path);
      }
    }

    if (scanInputs.isEmpty && !asnConfigured) {
      throw StateError(
        'set targets, Input File, Manual Targets, or ASN List before scanning',
      );
    }

    final targetOutputPath = config.text('targets_output').trim();
    final targetOutput = targetOutputPath.isEmpty
        ? null
        : File(config.resolvePath(targetOutputPath));
    final targetArtifactExists = targetOutput?.existsSync() ?? false;
    final rawScanArtifactExists = rawScanOutput.existsSync();
    if (shouldRunDiscoveryForTargets(
      asnConfigured: asnConfigured,
      targetOutputConfigured: targetOutput != null,
      targetArtifactExists: targetArtifactExists,
      rawScanArtifactExists: rawScanArtifactExists,
    )) {
      throwIfCancelled();
      final discoverWatch = Stopwatch()..start();
      final discoverArgs = buildDiscoverArgs(config, targetOutput!.path);
      final discoverRun = await runCore(discoverArgs, onProgress: onProgress);
      discoverWatch.stop();
      logs.addAll(compactLogs('discover', discoverArgs, discoverRun));
      scanInputs.add(targetOutput.path);
      metrics['discover_elapsed_ms'] = discoverWatch.elapsedMilliseconds;
      metrics['target_artifact'] = targetOutput.path;
      metrics['target_count'] = requiredDiscoveredTargetCount(discoverRun);
      resolvedTargets.addAll(readTargetsArtifactPreview(targetOutput));
    } else if (targetOutput != null && targetArtifactExists) {
      if (asnConfigured) {
        scanInputs.add(targetOutput.path);
      }
      metrics['target_artifact'] = targetOutput.path;
      metrics['target_count'] = countTargetsArtifact(targetOutput);
      resolvedTargets.addAll(readTargetsArtifactPreview(targetOutput));
    }

    if (resolvedTargets.isNotEmpty && !asnConfigured) {
      await writeTargetsArtifact(config, resolvedTargets);
    }

    await ensureParent(rawScanOutput);
    final scanWatch = Stopwatch()..start();
    final args = buildScanArgs(
      config,
      rawScanOutput.path,
      scanInputs,
      includeDiscovery: asnConfigured && scanInputs.isEmpty,
      resume: resume,
    );
    final run = await runCore(args, onProgress: onProgress);
    scanWatch.stop();
    logs.addAll(compactLogs('scan', args, run));

    final scanCounts = countScanResultsArtifact(rawScanOutput);
    metrics['raw_scan_artifact'] = rawScanOutput.path;
    metrics['scan_elapsed_ms'] = scanWatch.elapsedMilliseconds;
    metrics['scanned_count'] = scanCounts['scanned'] ?? 0;
    metrics['scan_valid_count'] = scanCounts['valid'] ?? 0;
    metrics['usable_artifact'] = sessionArtifactFile(config, 'usable.csv').path;
    metrics['urltest_artifact'] = urltestArtifactFile(config).path;

    final allResults = readScanResultsArtifact(rawScanOutput);
    final results = allResults
        .where((result) => result['valid'] == true)
        .toList(growable: false);
    final urltests = <Map<String, dynamic>>[];
    final existingUrltests = readUrltestArtifact(config);
    await ensureUrltestArtifactAppendable(config);
    final testedIps = existingUrltests
        .map((item) => (item['candidate_ip'] ?? item['ip'])?.toString() ?? '')
        .where((ip) => ip.isNotEmpty)
        .toSet();
    metrics['timeout_fallback_pending_count'] =
        timeoutFallbackCandidatesFromResults(
          allResults,
          testedIps: testedIps,
        ).length;
    urltests.addAll(existingUrltests);
    for (final result in results.where((result) => result['valid'] == true)) {
      final ip = result['ip']?.toString() ?? '';
      if (ip.isEmpty) {
        continue;
      }
      final existing = existingUrltests
          .where(
            (item) => (item['candidate_ip'] ?? item['ip'])?.toString() == ip,
          )
          .cast<Map<String, dynamic>>()
          .toList();
      if (existing.isNotEmpty) {
        mergeUrltest(result, existing.first);
      }
    }

    for (final warning in urltestPreflightWarnings(config)) {
      logs.add(warning);
      onProgress?.call(warning);
    }

    final urltestWatch = Stopwatch()..start();
    final pendingResults = results
        .where(
          (result) =>
              result['valid'] == true &&
              !testedIps.contains(result['ip']?.toString() ?? ''),
        )
        .toList();
    final urltestConcurrency = positiveInt(
      config.text('urltest_concurrency'),
      4,
    );
    for (
      var index = 0;
      index < pendingResults.length;
      index += urltestConcurrency
    ) {
      throwIfCancelled();
      final batch = pendingResults
          .skip(index)
          .take(urltestConcurrency)
          .toList(growable: false);
      onProgress?.call(
        'sing-box batch start=${index + 1} size=${batch.length} '
        'scan-valid=${metrics['scan_valid_count']} '
        'sing-box-ok=${countSuccessfulUrltests(urltests)} '
        'usable=${pickedScanResults(results).length}',
      );
      final batchResults = await Future.wait(
        batch.map(
          (result) =>
              runUrltestForScanResult(config, result, onProgress: onProgress),
        ),
      );
      throwIfCancelled();
      for (var batchIndex = 0; batchIndex < batch.length; batchIndex++) {
        final result = batch[batchIndex];
        final urltest = batchResults[batchIndex];
        final ip = result['ip']?.toString() ?? '';
        urltests.add(urltest);
        if (ip.isNotEmpty) {
          testedIps.add(ip);
        }
        mergeUrltest(result, urltest);
        logs.add(
          'sing-box urltest ${result['ip']}: '
          '${urltest['ok'] == true ? 'ok' : 'failed'} '
          'delay=${urltest['delay_ms'] ?? '-'}',
        );
      }
      metrics['urltest_count'] = urltests.length;
      metrics['sing_box_ok_count'] = countSuccessfulUrltests(urltests);
      metrics['usable_count'] = pickedScanResults(results).length;
      final pickedBatch = pickedScanResults(batch);
      await appendUrltestArtifact(config, batchResults);
      await appendScanArtifact(config, pickedBatch);
      await appendUsableArtifact(config, pickedBatch);
    }
    urltestWatch.stop();
    sortPickedResults(results);
    await writeScanArtifact(config, pickedScanResults(results));
    await writeUsableArtifact(config, pickedScanResults(results));
    metrics['urltest_elapsed_ms'] = urltestWatch.elapsedMilliseconds;
    metrics['urltest_count'] = urltests.length;
    metrics['sing_box_ok_count'] = countSuccessfulUrltests(urltests);
    metrics['usable_count'] = pickedScanResults(results).length;
    metrics['total_elapsed_ms'] =
        (metrics['discover_elapsed_ms'] as int? ?? 0) +
        (metrics['scan_elapsed_ms'] as int? ?? 0) +
        (metrics['urltest_elapsed_ms'] as int? ?? 0);

    return ScanOutcome(
      targets: resolvedTargets,
      results: results,
      urltests: urltests,
      logs: logs,
      metrics: metrics,
    );
  }

  Future<CandidateConnectOutcome> connectCandidates(
    ScoutConfig config, {
    void Function(String line)? onProgress,
  }) async {
    throwIfCancelled();
    final rawScanOutput = sessionArtifactFile(config, 'raw-scan.csv');
    if (!rawScanOutput.existsSync()) {
      throw StateError(
        'raw scan artifact is missing; run or restore a scan before checking candidates',
      );
    }

    final allResults = readScanResultsArtifact(rawScanOutput);
    final existingUrltests = readUrltestArtifact(config);
    await ensureUrltestArtifactAppendable(config);
    final testedIps = existingUrltests
        .map((item) => (item['candidate_ip'] ?? item['ip'])?.toString() ?? '')
        .where((ip) => ip.isNotEmpty)
        .toSet();
    final candidateCount = scanValidCandidatesFromResults(allResults).length;
    final pendingResults = scanValidCandidatesFromResults(
      allResults,
      testedIps: testedIps,
    );
    final existingOkCount = countSuccessfulUrltests(existingUrltests);

    onProgress?.call(
      'candidate-connect candidates=$candidateCount '
      'tested=0 ok=$existingOkCount remaining=${pendingResults.length}',
    );

    if (pendingResults.isEmpty) {
      return CandidateConnectOutcome(
        candidateCount: candidateCount,
        testedCount: 0,
        successfulCount: 0,
        remainingCount: 0,
      );
    }

    final urltestConcurrency = positiveInt(
      config.text('urltest_concurrency'),
      4,
    );
    var successfulCount = 0;
    for (
      var index = 0;
      index < pendingResults.length;
      index += urltestConcurrency
    ) {
      throwIfCancelled();
      final batch = pendingResults
          .skip(index)
          .take(urltestConcurrency)
          .toList(growable: false);
      onProgress?.call(
        'candidate-connect batch start=${index + 1} size=${batch.length} '
        'candidates=$candidateCount tested=$index '
        'ok=${existingOkCount + successfulCount} '
        'remaining=${pendingResults.length - index}',
      );
      final batchResults = await Future.wait(
        batch.map(
          (result) =>
              runUrltestForScanResult(config, result, onProgress: onProgress),
        ),
      );
      throwIfCancelled();
      for (var batchIndex = 0; batchIndex < batch.length; batchIndex++) {
        mergeUrltest(batch[batchIndex], batchResults[batchIndex]);
      }
      final pickedBatch = pickedScanResults(batch);
      successfulCount += pickedBatch.length;
      await appendUrltestArtifact(config, batchResults);
      await appendScanArtifact(config, pickedBatch);
      await appendUsableArtifact(config, pickedBatch);
      onProgress?.call(
        'candidate-connect candidates=$candidateCount '
        'tested=${index + batch.length} '
        'ok=${existingOkCount + successfulCount} '
        'remaining=${pendingResults.length - index - batch.length}',
      );
    }

    return CandidateConnectOutcome(
      candidateCount: candidateCount,
      testedCount: pendingResults.length,
      successfulCount: successfulCount,
      remainingCount: 0,
    );
  }

  Future<TimeoutFallbackOutcome> timeoutFallback(
    ScoutConfig config, {
    void Function(String line)? onProgress,
  }) async {
    throwIfCancelled();
    final rawScanOutput = sessionArtifactFile(config, 'raw-scan.csv');
    if (!rawScanOutput.existsSync()) {
      throw StateError(
        'raw scan artifact is missing; run the primary scan before timeout fallback',
      );
    }

    final allResults = readScanResultsArtifact(rawScanOutput);
    final existingUrltests = readUrltestArtifact(config);
    await ensureUrltestArtifactAppendable(config);
    final testedIps = existingUrltests
        .map((item) => (item['candidate_ip'] ?? item['ip'])?.toString() ?? '')
        .where((ip) => ip.isNotEmpty)
        .toSet();
    final candidateCount = timeoutFallbackCandidatesFromResults(
      allResults,
      testedIps: testedIps,
    ).length;
    final budget = positiveInt(config.text('timeout_fallback_budget'), 500);
    final pendingResults = timeoutFallbackCandidatesFromResults(
      allResults,
      testedIps: testedIps,
      limit: budget,
    );
    onProgress?.call(
      'timeout-fallback candidates=$candidateCount budget=$budget '
      'selected=${pendingResults.length}',
    );
    if (pendingResults.isEmpty) {
      return const TimeoutFallbackOutcome(
        candidateCount: 0,
        testedCount: 0,
        successfulCount: 0,
        remainingCount: 0,
      );
    }

    final urltestConcurrency = positiveInt(
      config.text('urltest_concurrency'),
      4,
    );
    var successfulCount = 0;
    for (
      var index = 0;
      index < pendingResults.length;
      index += urltestConcurrency
    ) {
      throwIfCancelled();
      final batch = pendingResults
          .skip(index)
          .take(urltestConcurrency)
          .toList(growable: false);
      onProgress?.call(
        'timeout-fallback batch start=${index + 1} size=${batch.length} '
        'pending=$candidateCount tested=$index ok=$successfulCount '
        'remaining=${candidateCount - index}',
      );
      final batchResults = await Future.wait(
        batch.map(
          (result) =>
              runUrltestForScanResult(config, result, onProgress: onProgress),
        ),
      );
      throwIfCancelled();
      for (var batchIndex = 0; batchIndex < batch.length; batchIndex++) {
        mergeUrltest(batch[batchIndex], batchResults[batchIndex]);
      }
      final pickedBatch = pickedTimeoutFallbackResults(batch);
      successfulCount += pickedBatch.length;
      await appendUrltestArtifact(config, batchResults);
      await appendScanArtifact(config, pickedBatch);
      await appendUsableArtifact(config, pickedBatch);
      onProgress?.call(
        'timeout-fallback candidates=$candidateCount budget=$budget '
        'tested=${index + batch.length} ok=$successfulCount '
        'remaining=${candidateCount - index - batch.length}',
      );
    }

    return TimeoutFallbackOutcome(
      candidateCount: candidateCount,
      testedCount: pendingResults.length,
      successfulCount: successfulCount,
      remainingCount: candidateCount - pendingResults.length,
    );
  }

  Future<Map<String, dynamic>> runUrltestForScanResult(
    ScoutConfig config,
    Map<String, dynamic> scanResult, {
    void Function(String line)? onProgress,
  }) async {
    throwIfCancelled();
    final ip = scanResult['ip']?.toString() ?? '';
    final output = await outputFile(config, '', 'urltest-result');
    final args = buildUrltestArgs(config, output.path, ip);
    try {
      final run = await runCore(args, onProgress: onProgress);
      final result = readJsonObject(output);
      result['ip'] = ip;
      result['asn'] = scanResult['asn'];
      result['org'] = scanResult['org'] ?? scanResult['name'];
      result['latency_ms'] = scanResult['latency_ms'];
      result['speed_mbps'] = scanResult['speed_mbps'];
      result['download_bytes'] =
          result['download_bytes'] ?? scanResult['download_bytes'];
      result['logs'] = compactLogs('urltest', args, run);
      return result;
    } catch (error) {
      if (isWorkflowCancelled(error)) {
        rethrow;
      }
      return {
        'ip': ip,
        'candidate_ip': ip,
        'asn': scanResult['asn'],
        'org': scanResult['org'] ?? scanResult['name'],
        'latency_ms': scanResult['latency_ms'],
        'speed_mbps': scanResult['speed_mbps'],
        'download_bytes': scanResult['download_bytes'],
        'delay_ms': null,
        'ok': false,
        'message': error.toString(),
      };
    }
  }

  Future<ProcessResult> runCore(
    List<String> args, {
    void Function(String line)? onProgress,
  }) async {
    throwIfCancelled();
    final process = await Process.start(
      coreBin,
      args,
      workingDirectory: workingDirectory,
    );
    cancellation.attachProcess(process);
    try {
      final stdoutLines = <String>[];
      final stderrLines = <String>[];

      final stdoutDone = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            stdoutLines.add(line);
            onProgress?.call(line);
          })
          .asFuture<void>();
      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            stderrLines.add(line);
            onProgress?.call(line);
          })
          .asFuture<void>();

      final exitCode = await process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      if (cancellation.isCancelled) {
        throw const WorkflowCancelled();
      }
      final stdout = stdoutLines.join('\n');
      final stderr = stderrLines.join('\n');
      final result = ProcessResult(process.pid, exitCode, stdout, stderr);
      if (exitCode != 0) {
        throw ProcessException(
          coreBin,
          args,
          '$stdout$stderr'.trim(),
          exitCode,
        );
      }
      return result;
    } finally {
      cancellation.detachProcess(process);
    }
  }

  void throwIfCancelled() {
    if (cancellation.isCancelled) {
      throw const WorkflowCancelled();
    }
  }
}

List<String> buildDiscoverArgs(ScoutConfig config, String outputPath) {
  return [
    'discover',
    '--output',
    outputPath,
    ...discoveryArgs(config),
    ...targetExpansionArgs(config),
  ];
}

List<String> buildScanArgs(
  ScoutConfig config,
  String outputPath,
  List<String> inputPaths, {
  bool includeDiscovery = true,
  bool resume = false,
}) {
  final edgeValidation = _scanEdgeValidationHints(config);
  return [
    'scan',
    '--output',
    outputPath,
    if (resume) '--resume',
    '--concurrency',
    nonEmpty(config.text('concurrency'), '16'),
    '--timeout-ms',
    nonEmpty(config.text('timeout_ms'), '2500'),
    '--request-interval-ms',
    nonEmpty(config.text('request_interval_ms'), '250'),
    if (config.text('max_valid').trim().isNotEmpty) ...[
      '--max-valid',
      config.text('max_valid').trim(),
    ],
    if (config.text('speed_url').trim().isNotEmpty) ...[
      '--speed-url',
      config.text('speed_url').trim(),
    ],
    '--speed-seconds',
    nonEmpty(config.text('speed_seconds'), '0'),
    if (config.text('download_url').trim().isNotEmpty) ...[
      '--download-url',
      config.text('download_url').trim(),
    ],
    '--min-download-bytes',
    nonEmpty(config.text('min_download_bytes'), '20480'),
    '--download-timeout-ms',
    nonEmpty(config.text('download_timeout_ms'), '5000'),
    if (edgeValidation != null) ...[
      '--edge-hostname',
      edgeValidation.hostname,
      '--edge-path',
      edgeValidation.path,
    ],
    ...targetExpansionArgs(config),
    if (includeDiscovery) ...discoveryArgs(config),
    for (final input in inputPaths) ...['--input', input],
  ];
}

class _EdgeValidationHints {
  const _EdgeValidationHints({required this.hostname, required this.path});

  final String hostname;
  final String path;
}

_EdgeValidationHints? _scanEdgeValidationHints(ScoutConfig config) {
  final source = config.text('sing_box_config').trim();
  if (source.isEmpty ||
      source == selectJsonConfigFile ||
      source.startsWith('http://') ||
      source.startsWith('https://')) {
    return null;
  }

  final file = File(config.resolvePath(source));
  if (!file.existsSync()) {
    return null;
  }

  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) {
      return null;
    }
    final outbounds = decoded['outbounds'];
    if (outbounds is! List) {
      return null;
    }
    final tag = config.text('outbound_tag').trim();
    final outbound = outbounds.whereType<Map>().cast<Map>().firstWhere(
      (candidate) => candidate['tag']?.toString().trim() == tag,
      orElse: () => const {},
    );
    if (outbound.isEmpty) {
      return null;
    }

    final tls = outbound['tls'];
    final String tlsServerName = tls is Map
        ? tls['server_name']?.toString().trim() ?? ''
        : '';
    final transport = outbound['transport'];
    final headers = transport is Map ? transport['headers'] : null;
    final String transportHost = headers is Map
        ? headers['Host']?.toString().trim() ?? ''
        : '';
    final server = outbound['server']?.toString().trim() ?? '';
    final hostname = <String>[
      tlsServerName,
      transportHost,
      if (!_looksLikeIpLiteral(server)) server,
    ].firstWhere((candidate) => candidate.isNotEmpty, orElse: () => '');
    if (hostname.isEmpty) {
      return null;
    }

    final rawPath = transport is Map
        ? transport['path']?.toString().trim() ?? ''
        : '';
    final path = rawPath.isEmpty
        ? '/'
        : rawPath.startsWith('/')
        ? rawPath
        : '/$rawPath';
    return _EdgeValidationHints(hostname: hostname, path: path);
  } catch (_) {
    return null;
  }
}

bool _looksLikeIpLiteral(String value) {
  final trimmed = value.trim();
  return trimmed.isNotEmpty && InternetAddress.tryParse(trimmed) != null;
}

bool shouldRunDiscoveryForTargets({
  required bool asnConfigured,
  required bool targetOutputConfigured,
  required bool targetArtifactExists,
  required bool rawScanArtifactExists,
}) {
  return asnConfigured &&
      targetOutputConfigured &&
      !targetArtifactExists &&
      !rawScanArtifactExists;
}

List<String> buildUrltestArgs(
  ScoutConfig config,
  String outputPath,
  String candidateIp,
) {
  return [
    'sing-box-urltest',
    '--config',
    config.text('sing_box_config'),
    '--candidate-ip',
    candidateIp,
    '--outbound-tag',
    config.text('outbound_tag'),
    '--min-download-bytes',
    nonEmpty(config.text('min_download_bytes'), '20480'),
    '--sing-box-bin',
    nonEmpty(config.text('sing_box_bin'), 'auto'),
    '--output',
    outputPath,
  ];
}

List<String> targetExpansionArgs(ScoutConfig config) {
  final maxTargets = config.text('max_targets').trim();
  return [
    '--port',
    nonEmpty(config.text('port'), '443'),
    '--max-targets',
    maxTargets.isEmpty ? '0' : maxTargets,
    if (config.flag('all_hosts')) '--all-hosts',
  ];
}

List<String> discoveryArgs(ScoutConfig config) {
  final asns = splitValues(config.text('asn_list'));
  return [
    for (final asn in asns) ...['--asn', asn],
    '--discovery-scope',
    cliDiscoveryScope(config.text('discovery_scope')),
  ];
}

String cliDiscoveryScope(String scope) {
  return switch (scope) {
    'AsPath' => 'as-path',
    'OriginAndAsPath' => 'origin-and-as-path',
    _ => 'origin',
  };
}

int positiveInt(String value, int fallback) {
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed <= 0) {
    return fallback;
  }
  return parsed;
}

String nonEmpty(String value, String fallback) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

bool isAbsolutePath(String path) {
  return path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);
}

List<String> splitValues(String value) {
  return value
      .split(RegExp(r'[\s,]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

List<String> splitManualTargets(String value) {
  final result = <String>[];
  for (final line in value.split('\n')) {
    final content = line.split('#').first;
    result.addAll(splitValues(content));
  }
  return result;
}

Future<File> outputFile(
  ScoutConfig config,
  String configuredPath,
  String stem, {
  String preferredExtension = 'json',
}) async {
  final trimmed = configuredPath.trim();
  if (trimmed.isNotEmpty) {
    final file = File(config.resolvePath(trimmed));
    await ensureParent(file);
    return file;
  }

  final dir = await Directory.systemTemp.createTemp('anycast-scout-gui-');
  return File('${dir.path}/$stem.$preferredExtension');
}

File sessionArtifactFile(ScoutConfig config, String suffix) {
  final session = config.sessionPath.trim().isEmpty
      ? 'anycast-scout-session.json'
      : config.sessionPath.trim();
  final resolved = config.resolvePath(session);
  final base = resolved.endsWith('.json')
      ? resolved.substring(0, resolved.length - '.json'.length)
      : resolved;
  return File('$base.$suffix');
}

File urltestArtifactFile(ScoutConfig config) {
  final configured = config.text('urltest_output').trim();
  if (configured.isNotEmpty) {
    return File(config.resolvePath(configured));
  }
  return sessionArtifactFile(config, 'urltests.jsonl');
}

Future<void> writeTargetsArtifact(
  ScoutConfig config,
  List<Map<String, dynamic>> targets,
) async {
  final path = config.text('targets_output').trim();
  if (path.isEmpty) {
    return;
  }
  final file = File(config.resolvePath(path));
  await ensureParent(file);
  await file.writeAsString(encodeCsvTargets(targets));
}

Future<void> writeScanArtifact(
  ScoutConfig config,
  List<Map<String, dynamic>> results,
) async {
  final path = config.text('scan_output').trim();
  if (path.isEmpty) {
    return;
  }
  final file = File(config.resolvePath(path));
  await ensureParent(file);
  await file.writeAsString(encodePickedScanCsv(results));
}

Future<void> appendScanArtifact(
  ScoutConfig config,
  List<Map<String, dynamic>> results,
) async {
  final path = config.text('scan_output').trim();
  if (path.isEmpty) {
    return;
  }
  await appendPickedScanRows(File(config.resolvePath(path)), results);
}

Future<void> writeUsableArtifact(
  ScoutConfig config,
  List<Map<String, dynamic>> results,
) async {
  final file = sessionArtifactFile(config, 'usable.csv');
  await ensureParent(file);
  await file.writeAsString(encodePickedScanCsv(results));
}

Future<void> appendUsableArtifact(
  ScoutConfig config,
  List<Map<String, dynamic>> results,
) async {
  await appendPickedScanRows(
    sessionArtifactFile(config, 'usable.csv'),
    results,
  );
}

Future<void> appendPickedScanRows(
  File file,
  List<Map<String, dynamic>> results,
) async {
  if (results.isEmpty) {
    return;
  }
  await ensureParent(file);
  final writeHeader = !file.existsSync() || file.lengthSync() == 0;
  final sink = file.openWrite(mode: FileMode.append);
  try {
    if (writeHeader) {
      sink.write(pickedScanCsvHeader);
    }
    for (final result in results.map(normalizeScanResult)) {
      sink.writeln(encodePickedScanCsvRow(result));
    }
  } finally {
    await sink.flush();
    await sink.close();
  }
}

Future<void> writeUrltestArtifact(
  ScoutConfig config,
  List<Map<String, dynamic>> results,
) async {
  final file = urltestArtifactFile(config);
  await ensureParent(file);
  await file.writeAsString(encodeJsonLines(results));
}

Future<void> appendUrltestArtifact(
  ScoutConfig config,
  List<Map<String, dynamic>> results,
) async {
  if (results.isEmpty) {
    return;
  }
  final file = urltestArtifactFile(config);
  await ensureParent(file);
  final sink = file.openWrite(mode: FileMode.append);
  try {
    for (final result in results) {
      sink.writeln(jsonEncode(result));
    }
  } finally {
    await sink.flush();
    await sink.close();
  }
}

Future<void> ensureUrltestArtifactAppendable(ScoutConfig config) async {
  final file = urltestArtifactFile(config);
  if (!file.existsSync()) {
    await ensureParent(file);
  }
}

List<Map<String, dynamic>> pickedScanResults(
  List<Map<String, dynamic>> results,
) {
  return results
      .where(
        (result) => result['valid'] == true && result['urltest_ok'] == true,
      )
      .map(normalizeScanResult)
      .toList();
}

List<Map<String, dynamic>> scanValidCandidatesFromResults(
  List<Map<String, dynamic>> results, {
  Set<String> testedIps = const <String>{},
}) {
  final candidates = <Map<String, dynamic>>[];
  for (final result in results) {
    final ip = result['ip']?.toString() ?? '';
    if (ip.isEmpty || testedIps.contains(ip) || result['valid'] != true) {
      continue;
    }
    candidates.add(Map<String, dynamic>.from(result));
  }
  sortPickedResults(candidates);
  return candidates;
}

List<Map<String, dynamic>> timeoutFallbackCandidatesFromResults(
  List<Map<String, dynamic>> results, {
  Set<String> testedIps = const <String>{},
  int? limit,
}) {
  final candidates = <Map<String, dynamic>>[];
  for (final result in results) {
    final ip = result['ip']?.toString() ?? '';
    if (ip.isEmpty ||
        testedIps.contains(ip) ||
        !isTimeoutFallbackCandidate(result)) {
      continue;
    }
    candidates.add(Map<String, dynamic>.from(result));
    if (limit != null && candidates.length >= limit) {
      break;
    }
  }
  return candidates;
}

bool isTimeoutFallbackCandidate(Map<String, dynamic> result) {
  if (result['valid'] == true) {
    return false;
  }
  final ip = result['ip']?.toString().trim() ?? '';
  if (ip.isEmpty) {
    return false;
  }
  final reason = result['reason']?.toString().trim().toLowerCase() ?? '';
  if (!reason.startsWith('request failed:')) {
    return false;
  }
  return reason.contains('(http://$ip/)');
}

List<Map<String, dynamic>> pickedTimeoutFallbackResults(
  List<Map<String, dynamic>> results,
) {
  return results
      .where((result) => result['urltest_ok'] == true)
      .map((result) {
        final normalized = normalizeScanResult(result);
        normalized['valid'] = true;
        normalized['download_bytes'] =
            normalized['download_bytes'] ??
            normalized['urltest_download_bytes'];
        normalized['reason'] = appendReason(
          normalized['reason']?.toString(),
          'timeout-fallback via sing-box',
        );
        return normalized;
      })
      .toList(growable: false);
}

String appendReason(String? current, String extra) {
  final trimmed = current?.trim() ?? '';
  if (trimmed.isEmpty) {
    return extra;
  }
  if (trimmed.contains(extra)) {
    return trimmed;
  }
  return '$trimmed; $extra';
}

Map<String, dynamic> normalizeScanResult(Map<String, dynamic> result) {
  final normalized = Map<String, dynamic>.from(result);
  normalized['org'] = normalized['org'] ?? normalized['name'];
  return normalized;
}

void mergeUrltest(Map<String, dynamic> result, Map<String, dynamic> urltest) {
  result['urltest_ok'] = urltest['ok'];
  result['urltest_delay_ms'] = urltest['delay_ms'];
  result['urltest_message'] = urltest['message'];
  result['urltest_download_bytes'] = urltest['download_bytes'];
  result['sing_box_version'] = urltest['sing_box_version'];
}

int countSuccessfulUrltests(List<Map<String, dynamic>> results) {
  return results.where((result) => result['ok'] == true).length;
}

void sortPickedResults(List<Map<String, dynamic>> results) {
  results.sort((left, right) {
    final valid = compareBoolDesc(left['valid'], right['valid']);
    if (valid != 0) return valid;
    final urltest = compareBoolDesc(left['urltest_ok'], right['urltest_ok']);
    if (urltest != 0) return urltest;
    final speed = compareNumDesc(left['speed_mbps'], right['speed_mbps']);
    if (speed != 0) return speed;
    final delay = compareNumAsc(
      left['urltest_delay_ms'],
      right['urltest_delay_ms'],
    );
    if (delay != 0) return delay;
    final latency = compareNumAsc(left['latency_ms'], right['latency_ms']);
    if (latency != 0) return latency;
    return (left['ip']?.toString() ?? '').compareTo(
      right['ip']?.toString() ?? '',
    );
  });
}

int compareBoolDesc(Object? left, Object? right) {
  final leftValue = left == true ? 1 : 0;
  final rightValue = right == true ? 1 : 0;
  return rightValue.compareTo(leftValue);
}

int compareNumDesc(Object? left, Object? right) {
  final leftValue = asNum(left);
  final rightValue = asNum(right);
  if (leftValue == null && rightValue == null) return 0;
  if (leftValue == null) return 1;
  if (rightValue == null) return -1;
  return rightValue.compareTo(leftValue);
}

int compareNumAsc(Object? left, Object? right) {
  final leftValue = asNum(left);
  final rightValue = asNum(right);
  if (leftValue == null && rightValue == null) return 0;
  if (leftValue == null) return 1;
  if (rightValue == null) return -1;
  return leftValue.compareTo(rightValue);
}

num? asNum(Object? value) {
  if (value is num) {
    return value;
  }
  if (value == null) {
    return null;
  }
  return num.tryParse(value.toString());
}

List<Map<String, dynamic>> readScanResultsArtifact(
  File file, {
  bool validOnly = false,
}) {
  if (!file.existsSync()) {
    return [];
  }
  final rows = readCsvRows(file).map(normalizeScanCsvRow).toList();
  return rows
      .map(normalizeScanResult)
      .where((row) => !validOnly || row['valid'] == true)
      .toList();
}

List<Map<String, dynamic>> readPickedScanResultsArtifact(File file) {
  return readScanResultsArtifact(file)
      .where((row) => row['valid'] == true && row['urltest_ok'] == true)
      .map((row) {
        final normalized = Map<String, dynamic>.from(row);
        normalized['valid'] = true;
        return normalized;
      })
      .toList(growable: false);
}

List<Map<String, dynamic>> readPickedScanResultsArtifactPath(String path) {
  return readPickedScanResultsArtifact(File(path));
}

Map<String, int> readCandidateArtifactMetrics(Map<String, String> paths) {
  final rawScanPath = paths['raw_scan'] ?? '';
  final urltestPath = paths['urltest'] ?? '';
  final rawRows = rawScanPath.isEmpty
      ? const <Map<String, dynamic>>[]
      : readScanResultsArtifact(File(rawScanPath));
  final candidateIps = rawRows
      .where((row) => row['valid'] == true)
      .map((row) => row['ip']?.toString() ?? '')
      .where((ip) => ip.isNotEmpty)
      .toSet();
  final urltestRows = urltestPath.isEmpty || !File(urltestPath).existsSync()
      ? const <Map<String, dynamic>>[]
      : readJsonRows(File(urltestPath));
  final testedCandidateIps = <String>{};
  final verifiedCandidateIps = <String>{};

  for (final row in urltestRows) {
    final ip = (row['candidate_ip'] ?? row['ip'])?.toString() ?? '';
    if (ip.isEmpty || !candidateIps.contains(ip)) {
      continue;
    }
    testedCandidateIps.add(ip);
    if (row['ok'] == true) {
      verifiedCandidateIps.add(ip);
    }
  }

  return {
    'scanned_count': rawRows.length,
    'scan_valid_count': candidateIps.length,
    'candidate_connect_tested_count': testedCandidateIps.length,
    'candidate_connect_ok_count': verifiedCandidateIps.length,
    'candidate_connect_pending_count':
        candidateIps.length - testedCandidateIps.length,
  };
}

List<Map<String, dynamic>> readCsvRows(File file) {
  final lines = file.readAsLinesSync();
  if (lines.isEmpty) {
    return [];
  }
  final headers = parseCsvLine(lines.first);
  final rows = <Map<String, dynamic>>[];
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) {
      continue;
    }
    final row = <String, dynamic>{};
    final values = parseCsvLine(line);
    for (
      var index = 0;
      index < headers.length && index < values.length;
      index++
    ) {
      row[headers[index]] = values[index].isEmpty ? null : values[index];
    }
    rows.add(row);
  }
  return rows;
}

Map<String, dynamic> normalizeScanCsvRow(Map<String, dynamic> row) {
  final normalized = Map<String, dynamic>.from(row);
  for (final key in [
    'port',
    'asn',
    'status',
    'download_bytes',
    'urltest_download_bytes',
  ]) {
    normalized[key] = int.tryParse(normalized[key]?.toString() ?? '');
  }
  for (final key in ['latency_ms', 'speed_mbps', 'urltest_delay_ms']) {
    normalized[key] = num.tryParse(normalized[key]?.toString() ?? '');
  }
  normalized['valid'] = normalized['valid']?.toString().toLowerCase() == 'true';
  normalized['urltest_ok'] =
      normalized['urltest_ok']?.toString().toLowerCase() == 'true';
  return normalized;
}

Map<String, int> countScanResultsArtifact(File file) {
  final counts = {'scanned': 0, 'valid': 0};
  if (!file.existsSync()) {
    return counts;
  }
  for (final row in readScanResultsArtifact(file)) {
    counts['scanned'] = counts['scanned']! + 1;
    if (row['valid'] == true) {
      counts['valid'] = counts['valid']! + 1;
    }
  }
  return counts;
}

int countTargetsArtifact(File file) {
  var lines = 0;
  var sawAny = false;
  var lastByte = -1;
  final buffer = List<int>.filled(1024 * 1024, 0);
  final handle = file.openSync();
  try {
    while (true) {
      final bytesRead = handle.readIntoSync(buffer);
      if (bytesRead == 0) break;
      sawAny = true;
      for (var index = 0; index < bytesRead; index++) {
        final byte = buffer[index];
        lastByte = byte;
        if (byte == 10) lines++;
      }
    }
    if (sawAny && lastByte != 10) lines++;
  } finally {
    handle.closeSync();
  }
  return lines == 0 ? 0 : lines - 1;
}

int requiredDiscoveredTargetCount(ProcessResult run) {
  final matches = RegExp(
    r'(?:discovery targets written|discovered targets)=(\d+)',
  ).allMatches(run.stderr.toString());
  final last = matches.lastOrNull;
  if (last == null) {
    throw FormatException(
      'core discovery output did not include discovered target count',
    );
  }
  return int.parse(last.group(1)!);
}

Future<void> ensureParent(File file) async {
  final parent = file.parent;
  if (parent.path.isNotEmpty && parent.path != '.') {
    await parent.create(recursive: true);
  }
}

List<Map<String, dynamic>> readUrltestArtifact(ScoutConfig config) {
  final file = urltestArtifactFile(config);
  if (!file.existsSync()) {
    return [];
  }
  return readJsonRows(file);
}

List<Map<String, dynamic>> readJsonRows(File file) {
  final content = file.readAsStringSync().trim();
  if (content.isEmpty) {
    return [];
  }

  final rows = <Map<String, dynamic>>[];
  final lines = const LineSplitter().convert(content);
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index].trim();
    if (line.isEmpty) {
      continue;
    }
    final decoded = jsonDecode(line);
    if (decoded is! Map) {
      throw FormatException(
        '${file.path} line ${index + 1} did not contain a JSON object',
      );
    }
    rows.add(Map<String, dynamic>.from(decoded));
  }
  return rows;
}

String encodeJsonLines(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) {
    return '';
  }
  final buffer = StringBuffer();
  for (final row in rows) {
    buffer.writeln(jsonEncode(row));
  }
  return buffer.toString();
}

Map<String, dynamic> readJsonObject(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) {
    throw FormatException('${file.path} did not contain a JSON object');
  }
  return Map<String, dynamic>.from(decoded);
}

List<Map<String, dynamic>> readTargetsArtifactPreview(
  File file, {
  int maxRows = 1000,
}) {
  return readCsvTargetsPreview(file, maxRows);
}

List<Map<String, dynamic>> readCsvTargetsPreview(File file, int maxRows) {
  final handle = file.openSync();
  final rows = <Map<String, dynamic>>[];
  var headerRead = false;
  var headers = <String>[];
  var lineBytes = <int>[];

  try {
    while (rows.length < maxRows) {
      final byte = handle.readByteSync();
      if (byte == -1) {
        if (lineBytes.isNotEmpty) {
          final line = utf8.decode(lineBytes);
          if (!headerRead) {
            headers = parseCsvLine(line);
          } else if (line.trim().isNotEmpty) {
            rows.add(csvTargetRow(headers, parseCsvLine(line)));
          }
        }
        break;
      }

      if (byte == 10) {
        final line = utf8.decode(lineBytes);
        lineBytes = <int>[];
        if (!headerRead) {
          headers = parseCsvLine(line);
          headerRead = true;
          continue;
        }
        if (line.trim().isEmpty) {
          continue;
        }
        rows.add(csvTargetRow(headers, parseCsvLine(line)));
      } else if (byte != 13) {
        lineBytes.add(byte);
      }
    }
  } finally {
    handle.closeSync();
  }

  return rows;
}

Map<String, dynamic> csvTargetRow(List<String> headers, List<String> values) {
  final row = <String, dynamic>{};
  for (
    var index = 0;
    index < headers.length && index < values.length;
    index++
  ) {
    final key = headers[index];
    final value = values[index];
    if (value.isEmpty) {
      row[key] = null;
    } else if (key == 'port' || key == 'asn') {
      row[key] = int.tryParse(value);
    } else {
      row[key] = value;
    }
  }
  return row;
}

List<String> parseCsvLine(String line) {
  final values = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var index = 0; index < line.length; index++) {
    final char = line[index];
    if (quoted &&
        char == '"' &&
        index + 1 < line.length &&
        line[index + 1] == '"') {
      buffer.write('"');
      index++;
    } else if (char == '"') {
      quoted = !quoted;
    } else if (!quoted && char == ',') {
      values.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  values.add(buffer.toString());
  return values;
}

String encodeCsvTargets(List<Map<String, dynamic>> targets) {
  final buffer = StringBuffer('ip,port,source,asn,name,prefix\n');
  for (final target in targets) {
    buffer.writeln(
      [
        target['ip'],
        target['port'],
        target['source'],
        target['asn'],
        target['name'],
        target['prefix'],
      ].map(csvCell).join(','),
    );
  }
  return buffer.toString();
}

String encodePickedScanCsv(List<Map<String, dynamic>> results) {
  final buffer = StringBuffer(pickedScanCsvHeader);
  for (final result in results.map(normalizeScanResult)) {
    buffer.writeln(encodePickedScanCsvRow(result));
  }
  return buffer.toString();
}

const pickedScanCsvHeader =
    'ip,port,valid,asn,org,latency_ms,speed_mbps,download_bytes,urltest_ok,urltest_delay_ms,urltest_download_bytes,colo,source,prefix,reason\n';

String encodePickedScanCsvRow(Map<String, dynamic> result) {
  return [
    result['ip'],
    result['port'],
    result['valid'],
    result['asn'],
    result['org'],
    result['latency_ms'],
    result['speed_mbps'],
    result['download_bytes'],
    result['urltest_ok'],
    result['urltest_delay_ms'],
    result['urltest_download_bytes'],
    result['colo'],
    result['source'],
    result['prefix'],
    result['reason'],
  ].map(csvCell).join(',');
}

String csvCell(Object? value) {
  final text = value?.toString() ?? '';
  if (text.contains(',') || text.contains('"') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

List<String> urltestPreflightWarnings(ScoutConfig config) => const [];

List<String> compactLogs(String action, List<String> args, ProcessResult run) {
  final logs = <String>['$action command: anycast-scout ${args.join(' ')}'];
  final stdout = run.stdout.toString().trim();
  final stderr = run.stderr.toString().trim();
  if (stdout.isNotEmpty) {
    logs.addAll(stdout.split('\n').where((line) => line.trim().isNotEmpty));
  }
  if (stderr.isNotEmpty) {
    logs.addAll(stderr.split('\n').where((line) => line.trim().isNotEmpty));
  }
  return logs;
}
