class ArtifactSnapshot {
  const ArtifactSnapshot({
    required this.metrics,
    required this.usableResults,
    this.urltestResults,
  });

  final Map<String, dynamic> metrics;
  final List<Map<String, dynamic>> usableResults;
  final List<Map<String, dynamic>>? urltestResults;
}
