import 'dart:async';

import 'package:anycast_scout_gui/src/shared/config/ui_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clockProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());
  final timer = Timer.periodic(AppDurations.clockTick, (_) {
    if (!controller.isClosed) {
      controller.add(DateTime.now());
    }
  });
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

String elapsedText(DateTime now, DateTime? startedAt, int savedMs) {
  var totalMs = savedMs;
  if (startedAt != null) {
    totalMs += now.difference(startedAt).inMilliseconds;
  }
  if (totalMs <= 0) {
    return '0s';
  }
  final duration = Duration(milliseconds: totalMs);
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
  }
  return '${duration.inSeconds}s';
}
