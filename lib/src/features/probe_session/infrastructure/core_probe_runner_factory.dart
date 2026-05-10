import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/core_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final coreProbeRunnerFactoryProvider = Provider<CoreProbeRunnerFactory>(
  (ref) => const DefaultCoreProbeRunnerFactory(),
);

abstract interface class CoreProbeRunnerFactory {
  CoreProbeRunner create(
    String backend, {
    required String workingDirectory,
    required RunCancellation cancellation,
  });
}

class DefaultCoreProbeRunnerFactory implements CoreProbeRunnerFactory {
  const DefaultCoreProbeRunnerFactory();

  @override
  CoreProbeRunner create(
    String backend, {
    required String workingDirectory,
    required RunCancellation cancellation,
  }) {
    return CoreProbeRunner(
      backend,
      workingDirectory: workingDirectory,
      cancellation: cancellation,
    );
  }
}
