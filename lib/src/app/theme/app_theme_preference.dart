import 'package:flutter/material.dart';

enum AppThemePreference {
  system,
  light,
  dark;

  static AppThemePreference fromName(String? value) {
    for (final preference in values) {
      if (preference.name == value) {
        return preference;
      }
    }
    return system;
  }

  ThemeMode get themeMode {
    return switch (this) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };
  }
}
