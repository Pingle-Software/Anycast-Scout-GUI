import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

bool _isWindowManagerReady = false;

bool get isDesktopWindowManagerReady => _isWindowManagerReady;

bool get isDesktopWindowManagerPlatform {
  if (kIsWeb) {
    return false;
  }

  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

bool get shouldUseWindowCaptionButtons {
  return isDesktopWindowManagerReady &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);
}

const String desktopWindowTitle = 'Anycast Scout by Pingle';
const Size desktopWindowSize = Size(700, 540);

Future<void> initializeDesktopWindowManager() async {
  if (!isDesktopWindowManagerPlatform) {
    return;
  }

  try {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: desktopWindowSize,
        minimumSize: desktopWindowSize,
        maximumSize: desktopWindowSize,
        center: true,
        backgroundColor: Colors.transparent,
        title: desktopWindowTitle,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      ),
      () async {
        await windowManager.setAsFrameless();
        await windowManager.setHasShadow(true);
        await windowManager.setResizable(false);
        await windowManager.show();
        await windowManager.focus();
      },
    );
    _isWindowManagerReady = true;
  } catch (_) {
    _isWindowManagerReady = false;
    // Keep running in widget tests, hot-restart edge cases, and environments
    // where the desktop plugin registrar is unavailable.
  }
}
