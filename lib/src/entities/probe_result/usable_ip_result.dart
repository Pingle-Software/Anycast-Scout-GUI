class UsableIpResult {
  const UsableIpResult({
    required this.ip,
    required this.latencyMs,
    required this.speedMbps,
    required this.delayMs,
    required this.downloadBytes,
    required this.asn,
    required this.prefix,
    required this.rating,
  });

  factory UsableIpResult.fromJson(
    Map<String, dynamic> json, {
    double rating = 0,
  }) {
    return UsableIpResult(
      ip: json['ip']?.toString() ?? '-',
      latencyMs: json['latency_ms'],
      speedMbps: json['speed_mbps'],
      delayMs: json['urltest_delay_ms'],
      downloadBytes:
          json['urltest_download_bytes'] ?? json['download_bytes'] ?? '-',
      asn: json['asn']?.toString() ?? '-',
      prefix: json['prefix']?.toString() ?? json['source']?.toString() ?? '-',
      rating: rating,
    );
  }

  static List<UsableIpResult> rankedFromRows(List<Map<String, dynamic>> rows) {
    final results = rows
        .where(isVerifiedUsableResultRow)
        .map(UsableIpResult.fromJson)
        .where((result) => result.ip.trim().isNotEmpty && result.ip != '-')
        .toList(growable: false);
    if (results.isEmpty) {
      return const <UsableIpResult>[];
    }

    final latencyRange = _MetricRange.fromValues(
      results.map((result) => result.effectiveLatencyMs),
    );
    final speedRange = _MetricRange.fromValues(
      results.map((result) => result.speedMbpsValue),
    );
    final ranked = results
        .map(
          (result) =>
              result._withRating(_ratingFor(result, latencyRange, speedRange)),
        )
        .toList(growable: false);

    ranked.sort((left, right) {
      final rating = right.rating.compareTo(left.rating);
      if (rating != 0) {
        return rating;
      }
      final speed = _compareNumDesc(left.speedMbpsValue, right.speedMbpsValue);
      if (speed != 0) {
        return speed;
      }
      final latency = _compareNumAsc(
        left.effectiveLatencyMs,
        right.effectiveLatencyMs,
      );
      if (latency != 0) {
        return latency;
      }
      return left.ip.compareTo(right.ip);
    });

    return List<UsableIpResult>.unmodifiable(ranked);
  }

  final String ip;
  final Object? latencyMs;
  final Object? speedMbps;
  final Object? delayMs;
  final Object? downloadBytes;
  final String asn;
  final String prefix;
  final double rating;

  double? get latencyMsValue => _asDouble(latencyMs);

  double? get speedMbpsValue => _asDouble(speedMbps);

  double? get delayMsValue => _asDouble(delayMs);

  double? get effectiveLatencyMs => latencyMsValue ?? delayMsValue;

  UsableIpResult _withRating(double value) {
    return UsableIpResult(
      ip: ip,
      latencyMs: latencyMs,
      speedMbps: speedMbps,
      delayMs: delayMs,
      downloadBytes: downloadBytes,
      asn: asn,
      prefix: prefix,
      rating: value,
    );
  }
}

bool isVerifiedUsableResultRow(Map<String, dynamic> row) {
  return _asBool(row['valid']) && _asBool(row['urltest_ok']);
}

double _ratingFor(
  UsableIpResult result,
  _MetricRange latencyRange,
  _MetricRange speedRange,
) {
  var weighted = 0.0;
  var weights = 0.0;

  final latencyScore = latencyRange.lowerIsBetter(result.effectiveLatencyMs);
  if (latencyScore != null) {
    weighted += latencyScore;
    weights += 1;
  }

  final speedScore = speedRange.higherIsBetter(result.speedMbpsValue);
  if (speedScore != null) {
    weighted += speedScore;
    weights += 1;
  }

  if (weights == 0) {
    return 0;
  }

  final rating = (weighted / weights) * 10;
  return (rating.clamp(0, 10) * 10).roundToDouble() / 10;
}

class _MetricRange {
  const _MetricRange({required this.min, required this.max});

  factory _MetricRange.fromValues(Iterable<double?> values) {
    double? min;
    double? max;
    for (final value in values) {
      if (value == null) {
        continue;
      }
      min = min == null || value < min ? value : min;
      max = max == null || value > max ? value : max;
    }
    return _MetricRange(min: min, max: max);
  }

  final double? min;
  final double? max;

  double? higherIsBetter(double? value) {
    final min = this.min;
    final max = this.max;
    if (value == null || min == null || max == null) {
      return null;
    }
    if (max == min) {
      return 1;
    }
    return (value - min) / (max - min);
  }

  double? lowerIsBetter(double? value) {
    final higher = higherIsBetter(value);
    return higher == null ? null : 1 - higher;
  }
}

bool _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  return value?.toString().toLowerCase() == 'true';
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value == null) {
    return null;
  }
  return double.tryParse(value.toString());
}

int _compareNumDesc(num? left, num? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return right.compareTo(left);
}

int _compareNumAsc(num? left, num? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return left.compareTo(right);
}
