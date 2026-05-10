import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

final platformFileRevealerProvider = Provider<PlatformFileRevealer>(
  (ref) => const ProcessPlatformFileRevealer(),
);

class RevealCommand {
  const RevealCommand(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;
}

abstract interface class PlatformFileRevealer {
  Future<void> revealFile(String path);

  Future<void> revealDirectory(String path);
}

class ProcessPlatformFileRevealer implements PlatformFileRevealer {
  const ProcessPlatformFileRevealer({ProcessRunner processRunner = Process.run})
    : _processRunner = processRunner;

  final ProcessRunner _processRunner;

  @override
  Future<void> revealFile(String path) async {
    await _run(revealFileCommand(path));
  }

  @override
  Future<void> revealDirectory(String path) async {
    await _run(revealDirectoryCommand(path));
  }

  Future<void> _run(RevealCommand command) async {
    final result = await _processRunner(command.executable, command.arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        command.executable,
        command.arguments,
        result.stderr.toString().trim(),
        result.exitCode,
      );
    }
  }
}

RevealCommand revealFileCommand(
  String path, {
  bool? macOS,
  bool? windows,
  bool? linux,
}) {
  if (windows ?? Platform.isWindows) {
    return RevealCommand('explorer.exe', ['/select,$path']);
  }
  if (linux ?? Platform.isLinux) {
    return RevealCommand('xdg-open', [File(path).absolute.parent.path]);
  }
  if (macOS ?? Platform.isMacOS) {
    return RevealCommand('open', ['-R', path]);
  }
  return RevealCommand('open', ['-R', path]);
}

RevealCommand revealDirectoryCommand(
  String path, {
  bool? macOS,
  bool? windows,
  bool? linux,
}) {
  if (windows ?? Platform.isWindows) {
    return RevealCommand('explorer.exe', [path]);
  }
  if (linux ?? Platform.isLinux) {
    return RevealCommand('xdg-open', [path]);
  }
  return RevealCommand('open', [path]);
}
