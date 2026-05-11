import 'dart:convert';
import 'dart:io';

import 'package:anycast_scout_gui/src/app/theme/app_theme_preference.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appPreferencesProvider = Provider<AppPreferences>((ref) {
  return const AppPreferences();
});

class AppPreferences {
  const AppPreferences({String? configDirectory})
    : _configDirectory = configDirectory;

  final String? _configDirectory;

  Future<AppThemePreference> loadThemePreference() async {
    final file = _preferencesFile();
    if (!await file.exists()) {
      return AppThemePreference.system;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return AppThemePreference.system;
      }
      return AppThemePreference.fromName(decoded['theme']?.toString());
    } on FormatException {
      return AppThemePreference.system;
    } on FileSystemException {
      return AppThemePreference.system;
    }
  }

  Future<void> saveThemePreference(AppThemePreference preference) async {
    final file = _preferencesFile();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      '${encoder.convert({'theme': preference.name})}\n',
      flush: true,
    );
  }

  File _preferencesFile() {
    return File(_join(_resolvedConfigDirectory(), 'preferences.json'));
  }

  String _resolvedConfigDirectory() {
    final configured = _configDirectory;
    if (configured != null && configured.trim().isNotEmpty) {
      return configured;
    }

    if (Platform.isMacOS) {
      return _join(
        _homeDirectory(),
        'Library/Application Support/Anycast Scout by Pingle',
      );
    }

    final configHome =
        Platform.environment['XDG_CONFIG_HOME'] ??
        _join(_homeDirectory(), '.config');
    return _join(configHome, 'anycast-scout-gui');
  }

  String _homeDirectory() {
    return Platform.environment['HOME'] ?? Directory.current.path;
  }

  String _join(String left, String right) {
    final trimmedLeft = left.endsWith(Platform.pathSeparator)
        ? left.substring(0, left.length - 1)
        : left;
    return '$trimmedLeft${Platform.pathSeparator}$right';
  }
}
