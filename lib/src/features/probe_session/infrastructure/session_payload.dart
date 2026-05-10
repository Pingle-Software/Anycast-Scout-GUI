import 'dart:convert';
import 'dart:io';

const sessionPayloadVersion = 1;

/// Parsed, version-checked session JSON used by restore and session discovery.
class SessionPayload {
  SessionPayload._({
    required this.path,
    required this.savedAtUnix,
    required this.config,
    required this.metrics,
    required this.gui,
    required this.scanResults,
    required this.usableResults,
    required this.urltestResults,
    required this.targetsCount,
    required this.scanResultsCount,
    required this.scanValidCount,
    required this.usableCount,
    required this.urltestCount,
    required this.connectOkCount,
    required this.status,
  });

  /// Reads a session JSON file and validates the payload version.
  factory SessionPayload.read(String path) {
    final decoded = jsonDecode(File(path).readAsStringSync());
    if (decoded is! Map) {
      throw FormatException('$path did not contain a session object');
    }
    return SessionPayload.fromJson(Map<String, dynamic>.from(decoded), path);
  }

  /// Parses already-decoded session JSON and validates the payload version.
  factory SessionPayload.fromJson(
    Map<String, dynamic> json, [
    String path = '',
  ]) {
    if (json['version'] != sessionPayloadVersion) {
      throw FormatException('unsupported session version ${json['version']}');
    }

    final metrics = sessionMap(json['workflow_metrics']);
    final gui = sessionMap(json['gui']);
    final scanResults = sessionMapList(json['last_scan_results']);
    final usableResults = usableScanRows(scanResults);
    final urltestResults = sessionMapList(json['last_urltest_results']);

    return SessionPayload._(
      path: path,
      savedAtUnix: sessionInt(json['saved_at_unix']),
      config: sessionMap(json['config']),
      metrics: metrics,
      gui: gui,
      scanResults: scanResults,
      usableResults: usableResults,
      urltestResults: urltestResults,
      targetsCount: sessionListLength(
        json['last_targets'],
        metrics['target_count'],
      ),
      scanResultsCount: preferredStoredCount(
        metrics['scanned_count'],
        scanResults.length,
        metrics['scan_valid_count'],
      ),
      scanValidCount: preferredCount(
        countValidScanRows(scanResults),
        metrics['scan_valid_count'],
        usableResults.length,
      ),
      usableCount: preferredCount(
        usableResults.length,
        metrics['usable_count'],
      ),
      urltestCount: preferredCount(
        urltestResults.length,
        json['last_urltest_count'],
        metrics['urltest_count'],
      ),
      connectOkCount: preferredCount(
        countOkRows(urltestResults),
        metrics['sing_box_ok_count'],
      ),
      status: statusLabel(gui['status'] ?? json['status']),
    );
  }

  final String path;
  final int savedAtUnix;
  final Map<String, dynamic> config;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> gui;
  final List<Map<String, dynamic>> scanResults;
  final List<Map<String, dynamic>> usableResults;
  final List<Map<String, dynamic>> urltestResults;
  final int targetsCount;
  final int scanResultsCount;
  final int scanValidCount;
  final int usableCount;
  final int urltestCount;
  final int connectOkCount;
  final String status;

  /// Optional backend path stored by the GUI layer.
  String? get coreBinaryPath {
    final value = gui['core_binary']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Metrics with counters backfilled from persisted result rows.
  Map<String, dynamic> metricsWithDerivedCounts() {
    return Map<String, dynamic>.from(metrics)
      ..['usable_count'] ??= usableResults.length
      ..['urltest_count'] ??= urltestResults.length
      ..['sing_box_ok_count'] ??= countOkRows(urltestResults);
  }
}

/// Converts a decoded JSON value to a string-keyed map.
Map<String, dynamic> sessionMap(Object? value) {
  if (value is! Map) {
    return <String, dynamic>{};
  }
  return Map<String, dynamic>.from(value);
}

/// Converts a decoded JSON value to a list of string-keyed maps.
List<Map<String, dynamic>> sessionMapList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

/// Returns scan rows that passed both scan and Connect validation.
List<Map<String, dynamic>> usableScanRows(List<Map<String, dynamic>> rows) {
  return rows
      .where(
        (row) => sessionBool(row['valid']) && sessionBool(row['urltest_ok']),
      )
      .toList(growable: false);
}

/// Counts result rows whose `ok` field is truthy.
int countOkRows(List<Map<String, dynamic>> rows) =>
    rows.where((row) => sessionBool(row['ok'])).length;

/// Counts scan rows whose `valid` field is truthy.
int countValidScanRows(List<Map<String, dynamic>> rows) =>
    rows.where((row) => sessionBool(row['valid'])).length;

/// Parses loose integer values from session JSON.
int sessionInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// Uses the observed count when present, otherwise falls back to stored metrics.
int preferredCount(int count, Object? firstFallback, [Object? secondFallback]) {
  if (count > 0) {
    return count;
  }
  final first = sessionInt(firstFallback);
  if (first > 0) {
    return first;
  }
  return sessionInt(secondFallback);
}

/// Uses stored metrics first when persisted rows may be only a visible subset.
int preferredStoredCount(Object? first, int observedCount, [Object? second]) {
  final firstCount = sessionInt(first);
  if (firstCount > 0) {
    return firstCount;
  }
  if (observedCount > 0) {
    return observedCount;
  }
  return sessionInt(second);
}

/// Returns a decoded list length or a numeric fallback.
int sessionListLength(Object? value, Object? fallback) {
  if (value is List) {
    return value.length;
  }
  return sessionInt(fallback);
}

/// Parses loose boolean values from session JSON.
bool sessionBool(Object? value) {
  if (value is bool) {
    return value;
  }
  return value?.toString().toLowerCase() == 'true';
}

/// Presents blank session statuses consistently.
String statusLabel(Object? value) {
  final status = value?.toString().trim() ?? '';
  return status.isEmpty ? '-' : status;
}
