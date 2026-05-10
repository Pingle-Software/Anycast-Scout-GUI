class ProbeArtifactMatrix {
  const ProbeArtifactMatrix({
    required this.targets,
    required this.scanned,
    required this.candidates,
    required this.tested,
    required this.verified,
    required this.pending,
  });

  factory ProbeArtifactMatrix.fromMetrics(Map<String, dynamic> metrics) {
    final candidates = _metricInt(metrics, 'scan_valid_count');
    final tested = _metricInt(metrics, 'candidate_connect_tested_count');
    final verified = _metricInt(metrics, 'usable_count');
    final explicitPending = _metricInt(
      metrics,
      'candidate_connect_pending_count',
    );
    final pending = explicitPending > 0
        ? explicitPending
        : (candidates - tested).clamp(0, candidates);

    return ProbeArtifactMatrix(
      targets: _metricInt(metrics, 'target_count'),
      scanned: _metricInt(metrics, 'scanned_count'),
      candidates: candidates,
      tested: tested,
      verified: verified,
      pending: pending,
    );
  }

  final int targets;
  final int scanned;
  final int candidates;
  final int tested;
  final int verified;
  final int pending;

  bool get hasData =>
      targets > 0 ||
      scanned > 0 ||
      candidates > 0 ||
      tested > 0 ||
      verified > 0;
}

int _metricInt(Map<String, dynamic> metrics, String key) {
  final value = metrics[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
