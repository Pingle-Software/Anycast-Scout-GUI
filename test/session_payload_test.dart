import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/session_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session payload restores only scan-valid sing-box verified rows', () {
    final payload = SessionPayload.fromJson({
      'version': 1,
      'saved_at_unix': 1777982400,
      'config': const <String, dynamic>{},
      'last_scan_results': [
        {'ip': '1.1.1.1', 'valid': true, 'urltest_ok': true, 'latency_ms': 10},
        {'ip': '1.0.0.1', 'valid': true, 'urltest_ok': false, 'latency_ms': 5},
        {'ip': '8.8.8.8', 'valid': false, 'urltest_ok': true, 'latency_ms': 1},
      ],
      'last_urltest_results': const <Map<String, dynamic>>[],
      'workflow_metrics': const <String, dynamic>{},
      'gui': const <String, dynamic>{},
    });

    expect(payload.scanValidCount, 2);
    expect(payload.usableResults, hasLength(1));
    expect(payload.usableResults.single['ip'], '1.1.1.1');
  });
}
