import 'dart:async';

import 'package:anycast_scout_gui/src/app/settings/app_preferences.dart';
import 'package:anycast_scout_gui/src/app/theme/app_theme_preference.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appThemePreferenceProvider =
    NotifierProvider<AppThemePreferenceController, AppThemePreference>(
      AppThemePreferenceController.new,
    );

class AppThemePreferenceController extends Notifier<AppThemePreference> {
  bool _loaded = false;

  @override
  AppThemePreference build() {
    if (!_loaded) {
      _loaded = true;
      unawaited(_load());
    }
    return AppThemePreference.system;
  }

  Future<void> setPreference(AppThemePreference preference) async {
    state = preference;
    await ref.read(appPreferencesProvider).saveThemePreference(preference);
  }

  Future<void> _load() async {
    final preference = await ref
        .read(appPreferencesProvider)
        .loadThemePreference();
    if (ref.mounted) {
      state = preference;
    }
  }
}
