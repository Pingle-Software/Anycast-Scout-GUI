class SessionSummary {
  const SessionSummary({
    required this.path,
    required this.savedAtUnix,
    required this.status,
    required this.targets,
    required this.scanResults,
    required this.scanValid,
    required this.usable,
    required this.urltests,
    required this.connectOk,
  });

  final String path;
  final int savedAtUnix;
  final String status;
  final int targets;
  final int scanResults;
  final int scanValid;
  final int usable;
  final int urltests;
  final int connectOk;

  int get pendingCandidateChecks {
    final pending = scanValid - urltests;
    return pending <= 0 ? 0 : pending;
  }

  DateTime? get savedAt => savedAtUnix <= 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(savedAtUnix * 1000);

  String get fileName {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }
}
