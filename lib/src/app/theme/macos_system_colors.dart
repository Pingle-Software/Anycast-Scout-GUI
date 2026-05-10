import 'package:anycast_scout_gui/src/shared/config/ui_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _systemColorsChannel = MethodChannel('anycast_scout_gui/system_colors');

Future<AppPalette?> loadMacOSDarkPalette() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
    return null;
  }

  try {
    final colors = await _systemColorsChannel.invokeMapMethod<String, int>(
      'resolvedDarkColors',
    );
    if (colors == null) {
      return null;
    }

    final windowBackground = _color(colors, 'windowBackground');
    final controlBackground = _color(colors, 'controlBackground');
    final separator = _color(colors, 'separator');
    final grid = _color(colors, 'grid');
    final label = _color(colors, 'label');
    final secondaryLabel = _color(colors, 'secondaryLabel');
    final tertiaryLabel = _color(colors, 'tertiaryLabel');
    final accent = _color(colors, 'controlAccent');
    final selectedContentBackground = _color(
      colors,
      'selectedContentBackground',
    );
    final systemRed = _color(colors, 'systemRed');

    return AppPalette(
      frame: windowBackground,
      sidebar: windowBackground,
      surface: windowBackground,
      muted: controlBackground,
      border: separator,
      borderStrong: grid,
      text: label,
      textMuted: secondaryLabel,
      textSubtle: tertiaryLabel,
      primary: accent,
      primaryDark: accent,
      primarySoft: selectedContentBackground,
      error: systemRed,
      errorSoft: systemRed.withValues(alpha: 0.16),
    );
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

Color _color(Map<String, int> colors, String key) {
  final value = colors[key];
  if (value == null) {
    throw StateError('Missing macOS system color: $key');
  }

  return Color(value);
}
