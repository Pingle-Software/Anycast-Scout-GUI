import 'dart:convert';
import 'dart:io';

import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/core_runner.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/workflow_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default config requires user-selected sing-box JSON config', () {
    final workspaceRoot = Directory.current.path;
    final defaults = defaultConfigValues(workspaceRoot);

    expect(defaults['sing_box_config'], selectJsonConfigFile);
  });

  test('default config uses a persistent urltest artifact', () {
    final workspaceRoot = Directory.current.path;
    final defaults = defaultConfigValues(workspaceRoot);

    expect(defaults['urltest_output'], '$workspaceRoot/cf-edge-urltests.jsonl');
  });

  test('default config enables bounded timeout fallback', () {
    final workspaceRoot = Directory.current.path;
    final defaults = defaultConfigValues(workspaceRoot);

    expect(defaults['timeout_fallback_budget'], '500');
  });

  test('default config keeps uncapped target expansion', () {
    final workspaceRoot = Directory.current.path;
    final defaults = defaultConfigValues(workspaceRoot);

    expect(defaults['max_targets'], '');
    expect(defaults['limit_targets'], isFalse);
  });

  test('blank max targets remain uncapped', () {
    final workspaceRoot = Directory.current.path;
    final config = normalizeConfigValues(workspaceRoot, {
      'max_targets': '',
      'limit_targets': false,
    });

    expect(config['max_targets'], '');
    expect(config['limit_targets'], isFalse);
  });

  test('blank target expansion args request no cap', () {
    final config = ScoutConfig.fromJson({
      'launch_cwd': Directory.current.path,
      'max_targets': '',
    });

    expect(
      targetExpansionArgs(config),
      containsAllInOrder(['--max-targets', '0']),
    );
  });

  test('target expansion args use configured target cap', () {
    final config = ScoutConfig.fromJson({
      'launch_cwd': Directory.current.path,
      'max_targets': '250',
    });

    expect(
      targetExpansionArgs(config),
      containsAllInOrder(['--max-targets', '250']),
    );
  });

  test('zero target cap remains explicit no-limit mode', () {
    final config = ScoutConfig.fromJson({
      'launch_cwd': Directory.current.path,
      'max_targets': '0',
    });

    expect(
      targetExpansionArgs(config),
      containsAllInOrder(['--max-targets', '0']),
    );
  });

  test('discovered target count is required from process stderr', () {
    final run = ProcessResult(
      1,
      0,
      '',
      'discovery targets written=8192\ndiscovered targets=6595198\n',
    );

    expect(requiredDiscoveredTargetCount(run), 6595198);
  });

  test('missing discovered target count is a protocol error', () {
    final run = ProcessResult(1, 0, '', '');

    expect(
      () => requiredDiscoveredTargetCount(run),
      throwsA(isA<FormatException>()),
    );
  });

  test('scan args consume discovered target artifact without rediscovery', () {
    final config = ScoutConfig.fromJson({
      'launch_cwd': Directory.current.path,
      'asn_list': 'AS13335',
    });

    final args = buildScanArgs(config, '/tmp/raw-scan.csv', [
      '/tmp/cf-edge-targets.csv',
    ], includeDiscovery: false);

    expect(args, containsAllInOrder(['--input', '/tmp/cf-edge-targets.csv']));
    expect(args, isNot(contains('--asn')));
  });

  test('scan args derive edge validation hints from local sing-box config', () {
    final temp = Directory.systemTemp.createTempSync(
      'anycast-scout-gui-edge-hints-',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });
    final configFile = File('${temp.path}/sing-box.json');
    configFile.writeAsStringSync(
      jsonEncode({
        'outbounds': [
          {
            'tag': '🇩🇪 Germany CDN 1',
            'server': '185.250.73.135',
            'tls': {'server_name': 'edge-de-1.empty-folder.cc'},
            'transport': {'type': 'httpupgrade', 'path': '/api/v1/events'},
          },
        ],
      }),
    );
    final config = ScoutConfig.fromJson({
      'launch_cwd': temp.path,
      'sing_box_config': configFile.path,
      'outbound_tag': '🇩🇪 Germany CDN 1',
    });

    final args = buildScanArgs(config, '/tmp/raw-scan.csv', const []);

    expect(
      args,
      containsAllInOrder([
        '--edge-hostname',
        'edge-de-1.empty-folder.cc',
        '--edge-path',
        '/api/v1/events',
      ]),
    );
  });

  test('scan args include resume only for restored continuation', () {
    final config = ScoutConfig.fromJson({'launch_cwd': Directory.current.path});

    expect(
      buildScanArgs(config, '/tmp/raw-scan.csv', const [], resume: true),
      contains('--resume'),
    );
    expect(
      buildScanArgs(config, '/tmp/raw-scan.csv', const []),
      isNot(contains('--resume')),
    );
  });

  test('scan args include edge validation hints from selected outbound', () {
    final temp = Directory.systemTemp.createTempSync(
      'anycast-scout-gui-edge-hints-',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });
    final configFile = File('${temp.path}/sing-box.json');
    configFile.writeAsStringSync(
      jsonEncode({
        'outbounds': [
          {
            'tag': 'CDN',
            'server': '185.250.73.135',
            'tls': {'server_name': 'edge.example.com'},
            'transport': {'type': 'httpupgrade', 'path': '/api/v1/events'},
          },
        ],
      }),
    );
    final config = ScoutConfig.fromJson({
      'launch_cwd': temp.path,
      'sing_box_config': configFile.path,
      'outbound_tag': 'CDN',
    });

    expect(
      buildScanArgs(config, '/tmp/raw-scan.csv', const []),
      containsAllInOrder([
        '--edge-hostname',
        'edge.example.com',
        '--edge-path',
        '/api/v1/events',
      ]),
    );
  });

  test('blank urltest output falls back to session artifact', () {
    final config = ScoutConfig.fromJson({
      'launch_cwd': '/tmp/workspace',
      'session_path': '/tmp/workspace/saved-session.json',
      'urltest_output': '',
    });

    expect(
      urltestArtifactFile(config).path,
      '/tmp/workspace/saved-session.urltests.jsonl',
    );
  });

  test('urltest artifact appends JSONL rows', () async {
    final temp = Directory.systemTemp.createTempSync(
      'anycast-scout-gui-urltests-',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });
    final config = ScoutConfig.fromJson({
      'launch_cwd': temp.path,
      'session_path': '${temp.path}/session.json',
      'urltest_output': '${temp.path}/urltests.json',
    });
    final file = urltestArtifactFile(config);
    file.writeAsStringSync(
      '${jsonEncode({'candidate_ip': '1.1.1.1', 'ok': true})}\n',
    );

    await ensureUrltestArtifactAppendable(config);
    await appendUrltestArtifact(config, [
      {'candidate_ip': '1.0.0.1', 'ok': false},
    ]);

    expect(readUrltestArtifact(config), [
      {'candidate_ip': '1.1.1.1', 'ok': true},
      {'candidate_ip': '1.0.0.1', 'ok': false},
    ]);
    expect(file.readAsStringSync().trimLeft(), startsWith('{'));
  });

  test('picked scan artifact appends rows without repeated headers', () async {
    final temp = Directory.systemTemp.createTempSync(
      'anycast-scout-gui-picked-',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });
    final config = ScoutConfig.fromJson({
      'launch_cwd': temp.path,
      'scan_output': '${temp.path}/selected.csv',
    });

    await appendScanArtifact(config, [
      {'ip': '1.1.1.1', 'port': 443, 'valid': true, 'urltest_ok': true},
    ]);
    await appendScanArtifact(config, [
      {'ip': '1.0.0.1', 'port': 443, 'valid': true, 'urltest_ok': true},
    ]);

    final lines = File('${temp.path}/selected.csv').readAsLinesSync();
    expect(lines, hasLength(3));
    expect(lines.where((line) => line.startsWith('ip,port,')), hasLength(1));
  });

  test('picked scan artifact reads rows as verified usable results', () async {
    final temp = Directory.systemTemp.createTempSync(
      'anycast-scout-gui-picked-read-',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });
    final config = ScoutConfig.fromJson({
      'launch_cwd': temp.path,
      'scan_output': '${temp.path}/selected.csv',
    });

    await appendScanArtifact(config, [
      {
        'ip': '1.1.1.1',
        'port': 443,
        'valid': true,
        'latency_ms': 12.5,
        'speed_mbps': 40,
        'urltest_ok': true,
        'urltest_delay_ms': 20,
        'urltest_download_bytes': 20480,
      },
    ]);

    final rows = readPickedScanResultsArtifact(
      File('${temp.path}/selected.csv'),
    );

    expect(rows, hasLength(1));
    expect(rows.single['valid'], isTrue);
    expect(rows.single['urltest_ok'], isTrue);
    expect(rows.single['urltest_delay_ms'], 20);
    expect(rows.single['urltest_download_bytes'], 20480);
  });

  test('scan-valid candidates skip already tested IPs', () {
    final candidates = scanValidCandidatesFromResults(
      [
        {
          'ip': '203.0.113.1',
          'valid': true,
          'latency_ms': 20,
          'speed_mbps': 10,
        },
        {
          'ip': '203.0.113.2',
          'valid': true,
          'latency_ms': 10,
          'speed_mbps': 50,
        },
        {
          'ip': '203.0.113.3',
          'valid': false,
          'latency_ms': 1,
          'speed_mbps': 100,
        },
      ],
      testedIps: const {'203.0.113.1'},
    );

    expect(candidates.map((row) => row['ip']), ['203.0.113.2']);
  });

  test('timeout fallback candidates keep only direct http timeouts', () {
    final results = [
      {
        'ip': '8.39.207.1',
        'valid': false,
        'reason':
            'request failed: error sending request for url (http://8.39.207.1/)',
      },
      {
        'ip': '104.16.132.229',
        'valid': false,
        'reason':
            'edge-direct status=403 error=1003 cloudflare=ok; edge-host status=403 error=1034 cloudflare=ok accepted=ok rejected=yes',
      },
      {
        'ip': '8.48.131.1',
        'valid': false,
        'reason':
            'request failed: error sending request for url (http://8.48.131.1/)',
      },
      {
        'ip': '185.250.73.135',
        'valid': true,
        'reason':
            'edge-direct status=403 error=1003 cloudflare=ok; edge-host status=401 error=- cloudflare=ok accepted=ok rejected=no',
      },
    ];

    expect(
      timeoutFallbackCandidatesFromResults(
        results,
      ).map((row) => row['ip']).toList(),
      ['8.39.207.1', '8.48.131.1'],
    );
    expect(
      timeoutFallbackCandidatesFromResults(
        results,
        limit: 1,
      ).map((row) => row['ip']).toList(),
      ['8.39.207.1'],
    );
    expect(
      timeoutFallbackCandidatesFromResults(
        results,
        testedIps: const {'8.39.207.1'},
      ).map((row) => row['ip']).toList(),
      ['8.48.131.1'],
    );
  });

  test('picked timeout fallback results keep only sing-box successes', () {
    final picked = pickedTimeoutFallbackResults([
      {
        'ip': '8.39.207.1',
        'port': 443,
        'valid': false,
        'urltest_ok': true,
        'urltest_download_bytes': 20480,
        'reason':
            'request failed: error sending request for url (http://8.39.207.1/)',
      },
      {
        'ip': '196.3.47.1',
        'port': 443,
        'valid': false,
        'urltest_ok': false,
        'reason':
            'request failed: error sending request for url (http://196.3.47.1/)',
      },
    ]);

    expect(picked, hasLength(1));
    expect(picked.single['ip'], '8.39.207.1');
    expect(picked.single['download_bytes'], 20480);
    expect(picked.single['reason'], contains('timeout-fallback via sing-box'));
  });

  test('existing target artifact prevents rediscovery while continuing', () {
    expect(
      shouldRunDiscoveryForTargets(
        asnConfigured: true,
        targetOutputConfigured: true,
        targetArtifactExists: true,
        rawScanArtifactExists: false,
      ),
      isFalse,
    );
  });

  test(
    'missing target and raw artifacts require discovery for ASN workflow',
    () {
      expect(
        shouldRunDiscoveryForTargets(
          asnConfigured: true,
          targetOutputConfigured: true,
          targetArtifactExists: false,
          rawScanArtifactExists: false,
        ),
        isTrue,
      );
    },
  );
}
