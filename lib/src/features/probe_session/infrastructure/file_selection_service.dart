import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fileSelectionGatewayProvider = Provider<FileSelectionGateway>(
  (ref) => const FileSelectionService(),
);

abstract interface class FileSelectionGateway {
  Future<String?> pickExecutable();

  Future<String?> pickJsonFile();

  Future<String?> pickSessionJsonFile();
}

class FileSelectionService implements FileSelectionGateway {
  const FileSelectionService();

  static Future<void>? _macOSEntitlementsCheck;

  @override
  Future<String?> pickExecutable() async {
    await _prepareFilePicker();
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select anycast-scout binary',
      lockParentWindow: true,
    );
    return result?.files.single.path;
  }

  @override
  Future<String?> pickJsonFile() async {
    await _prepareFilePicker();
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select JSON config',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      lockParentWindow: true,
    );
    return result?.files.single.path;
  }

  @override
  Future<String?> pickSessionJsonFile() async {
    await _prepareFilePicker();
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Open session JSON',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      lockParentWindow: true,
    );
    return result?.files.single.path;
  }

  static Future<void> _prepareFilePicker() {
    if (!Platform.isMacOS) {
      return Future<void>.value();
    }

    // This desktop app is intentionally not sandboxed because it launches a
    // user-selected backend binary and reads user-selected config/session files.
    // file_picker 11 verifies sandbox entitlements before opening NSOpenPanel;
    // skip that plugin-side check so macOS can handle file access normally.
    return _macOSEntitlementsCheck ??= FilePicker.skipEntitlementsChecks();
  }
}
