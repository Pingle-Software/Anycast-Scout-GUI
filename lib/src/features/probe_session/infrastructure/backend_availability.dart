import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/workspace_locator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendAvailabilityProvider = Provider<BackendAvailability>(
  (ref) => const WorkspaceBackendAvailability(),
);

abstract interface class BackendAvailability {
  Future<bool> isAvailable(String path);
}

class WorkspaceBackendAvailability implements BackendAvailability {
  const WorkspaceBackendAvailability();

  @override
  Future<bool> isAvailable(String path) => backendAvailable(path);
}
