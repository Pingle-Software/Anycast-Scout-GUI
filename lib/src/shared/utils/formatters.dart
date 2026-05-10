String formatMs(Object? value) {
  if (value == null) {
    return '-';
  }
  final parsed = num.tryParse(value.toString());
  if (parsed == null) {
    return value.toString();
  }
  return '${parsed.toStringAsFixed(parsed >= 10 ? 0 : 1)} ms';
}

String formatMbps(Object? value) {
  if (value == null) {
    return '-';
  }
  final parsed = num.tryParse(value.toString());
  if (parsed == null) {
    return value.toString();
  }
  return '${parsed.toStringAsFixed(parsed >= 10 ? 0 : 1)} Mbps';
}

String formatBytes(Object? value) {
  if (value == null) {
    return '-';
  }
  final parsed = num.tryParse(value.toString());
  if (parsed == null) {
    return value.toString();
  }
  if (parsed >= 1024 * 1024) {
    final mib = parsed / (1024 * 1024);
    return '${mib.toStringAsFixed(mib >= 10 ? 0 : 1)} MiB';
  }
  if (parsed >= 1024) {
    final kib = parsed / 1024;
    return '${kib.toStringAsFixed(kib >= 10 ? 0 : 1)} KiB';
  }
  return '${parsed.toStringAsFixed(0)} B';
}

String formatRating(double value) {
  return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
}
