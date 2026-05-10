import 'package:anycast_scout_gui/src/entities/probe_result/usable_ip_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ranked results keep only scan-valid and sing-box verified rows', () {
    final ranked = UsableIpResult.rankedFromRows([
      {
        'ip': '203.0.113.10',
        'valid': true,
        'urltest_ok': true,
        'latency_ms': 20,
        'speed_mbps': 40,
      },
      {
        'ip': '203.0.113.11',
        'valid': true,
        'urltest_ok': false,
        'latency_ms': 1,
        'speed_mbps': 1000,
      },
      {
        'ip': '203.0.113.12',
        'valid': false,
        'urltest_ok': true,
        'latency_ms': 1,
        'speed_mbps': 1000,
      },
    ]);

    expect(ranked.map((result) => result.ip), ['203.0.113.10']);
  });

  test('ranked results sort by the 10 point latency speed rating', () {
    final ranked = UsableIpResult.rankedFromRows([
      {
        'ip': '203.0.113.20',
        'valid': true,
        'urltest_ok': true,
        'latency_ms': 80,
        'speed_mbps': 50,
      },
      {
        'ip': '203.0.113.21',
        'valid': true,
        'urltest_ok': true,
        'latency_ms': 10,
        'speed_mbps': 50,
      },
      {
        'ip': '203.0.113.22',
        'valid': true,
        'urltest_ok': true,
        'latency_ms': 80,
        'speed_mbps': 1,
      },
    ]);

    expect(ranked.map((result) => result.ip), [
      '203.0.113.21',
      '203.0.113.20',
      '203.0.113.22',
    ]);
    expect(ranked.first.rating, 10);
    expect(ranked.last.rating, 0);
    for (final result in ranked) {
      expect(result.rating, inInclusiveRange(0, 10));
    }
  });
}
