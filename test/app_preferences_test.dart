import 'dart:convert';
import 'dart:io';

import 'package:anycast_scout_gui/src/app/settings/app_preferences.dart';
import 'package:anycast_scout_gui/src/app/theme/app_theme_preference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme preference maps to Flutter theme modes', () {
    expect(AppThemePreference.system.themeMode, ThemeMode.system);
    expect(AppThemePreference.light.themeMode, ThemeMode.light);
    expect(AppThemePreference.dark.themeMode, ThemeMode.dark);
  });

  test('theme preference is saved and loaded from preferences file', () async {
    final temp = Directory.systemTemp.createTempSync(
      'anycast-scout-gui-preferences-test-',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    final preferences = AppPreferences(configDirectory: temp.path);

    expect(await preferences.loadThemePreference(), AppThemePreference.system);

    await preferences.saveThemePreference(AppThemePreference.dark);

    expect(await preferences.loadThemePreference(), AppThemePreference.dark);
    expect(
      jsonDecode(await File('${temp.path}/preferences.json').readAsString()),
      {'theme': 'dark'},
    );
  });

  test('invalid theme preference falls back to system mode', () async {
    final temp = Directory.systemTemp.createTempSync(
      'anycast-scout-gui-preferences-test-',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    File(
      '${temp.path}/preferences.json',
    ).writeAsStringSync('{"theme":"unexpected"}');

    final preferences = AppPreferences(configDirectory: temp.path);

    expect(await preferences.loadThemePreference(), AppThemePreference.system);
  });
}
