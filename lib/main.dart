import 'package:anycast_scout_gui/src/app/anycast_scout_app.dart';
import 'package:anycast_scout_gui/src/app/window_manager_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:anycast_scout_gui/src/app/anycast_scout_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDesktopWindowManager();

  runApp(const ProviderScope(child: AnycastScoutGuiApp()));
}
