import 'dart:io';

import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/core_runner.dart';

const backendExecutableBaseName = 'anycast-scout';
const bundledBackendDirectoryName = 'backend';

String detectWorkspaceRoot() {
  final candidates = [
    Directory.current,
    File(Platform.resolvedExecutable).parent,
  ];
  for (final candidate in candidates) {
    final root = searchAncestorsForWorkspace(candidate);
    if (root != null) {
      return root;
    }
  }
  final groupedCheckout = searchGroupedCheckoutForWorkspace(Directory.current);
  if (groupedCheckout != null) {
    return groupedCheckout;
  }
  return portableWorkspaceRootForExecutable(Platform.resolvedExecutable);
}

String? searchAncestorsForWorkspace(Directory start) {
  var current = start.absolute;
  for (var depth = 0; depth < 10; depth++) {
    final cargo = File('${current.path}/Cargo.toml');
    final srcMain = File('${current.path}/src/main.rs');
    if (cargo.existsSync() && srcMain.existsSync()) {
      return current.path;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      break;
    }
    current = parent;
  }
  return null;
}

String? searchGroupedCheckoutForWorkspace(Directory start) {
  var current = start.absolute;
  final seen = <String>{};
  for (var depth = 0; depth < 10; depth++) {
    for (final name in const ['backend', 'anycast-scout']) {
      final candidate = Directory('${current.path}/$name').absolute;
      if (!seen.add(candidate.path)) {
        continue;
      }
      final root = searchAncestorsForWorkspace(candidate);
      if (root != null) {
        return root;
      }
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      break;
    }
    current = parent;
  }
  return null;
}

String detectCoreBinary(String workspaceRoot) {
  final bundled = detectBundledCoreBinary();
  if (bundled != null) {
    return bundled;
  }
  final binaryName = backendExecutableName();
  final release = File('$workspaceRoot/target/release/$binaryName');
  if (release.existsSync()) {
    return release.path;
  }
  final debug = File('$workspaceRoot/target/debug/$binaryName');
  if (debug.existsSync()) {
    return debug.path;
  }
  return binaryName;
}

Future<bool> backendAvailable(String path) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  final candidate = File(trimmed);
  if (candidate.existsSync()) {
    return true;
  }
  try {
    final result = await Process.run('which', [trimmed]);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

String normalizeConfigPath(String workspaceRoot, String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty ||
      trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed == selectJsonConfigFile) {
    return trimmed;
  }
  if (trimmed.startsWith('~/')) {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return '$home/${trimmed.substring(2)}';
    }
  }
  if (_isAbsolutePath(trimmed)) {
    return trimmed;
  }
  return '$workspaceRoot/$trimmed';
}

bool _isAbsolutePath(String path) {
  return path.startsWith('/');
}

String backendExecutableName() => backendExecutableBaseName;

String portableWorkspaceRootForExecutable(
  String executablePath, {
  bool? macOS,
}) {
  final executable = File(executablePath).absolute;
  final isMacOS = macOS ?? Platform.isMacOS;
  if (isMacOS) {
    final macOSDirectory = executable.parent;
    final contentsDirectory = macOSDirectory.parent;
    final appBundle = contentsDirectory.parent;
    if (macOSDirectory.path.endsWith('/Contents/MacOS') &&
        contentsDirectory.path.endsWith('/Contents') &&
        appBundle.path.endsWith('.app')) {
      return appBundle.parent.path;
    }
  }
  return executable.parent.path;
}

String? detectBundledCoreBinary() {
  for (final candidate in bundledCoreBinaryCandidates(
    Platform.resolvedExecutable,
  )) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }
  return null;
}

List<String> bundledCoreBinaryCandidates(String executablePath, {bool? macOS}) {
  final executable = File(executablePath).absolute;
  final binaryName = backendExecutableName();
  final candidates = <String>[];
  if (macOS ?? Platform.isMacOS) {
    final contentsDirectory = executable.parent.parent;
    candidates.add(
      '${contentsDirectory.path}/Resources/$bundledBackendDirectoryName/$binaryName',
    );
  }
  candidates.add(
    '${executable.parent.path}/$bundledBackendDirectoryName/$binaryName',
  );
  return candidates;
}
