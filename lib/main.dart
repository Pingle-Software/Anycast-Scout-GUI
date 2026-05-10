import 'package:anycast_scout_gui/src/app/anycast_scout_app.dart';
import 'package:anycast_scout_gui/src/app/theme/app_theme.dart';
import 'package:anycast_scout_gui/src/app/theme/macos_system_colors.dart';
import 'package:anycast_scout_gui/src/app/window_manager_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:anycast_scout_gui/src/app/anycast_scout_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDesktopWindowManager();
  AppTheme.setPlatformDarkPalette(await loadMacOSDarkPalette());

  runApp(const ProviderScope(child: AnycastScoutGuiApp()));
}
