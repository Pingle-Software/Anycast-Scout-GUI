import 'package:anycast_scout_gui/src/shared/config/ui_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static AppPalette? _platformDarkPalette;

  static void setPlatformDarkPalette(AppPalette? value) {
    _platformDarkPalette = value;
  }

  static ThemeData get light => _theme(Brightness.light);

  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final baseTextTheme = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true).textTheme
        : ThemeData.light(useMaterial3: true).textTheme;
    final baseAppTextTheme = GoogleFonts.nunitoTextTheme(baseTextTheme);
    final palette = brightness == Brightness.dark
        ? (_platformDarkPalette ?? AppPalette.dark)
        : AppPalette.light;

    TextStyle? compact(
      TextStyle? style,
      double size,
      double height, [
      FontWeight? weight,
    ]) {
      return style?.copyWith(
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: 0,
      );
    }

    final textTheme = baseAppTextTheme.copyWith(
      titleLarge: compact(
        baseAppTextTheme.titleLarge,
        18,
        1.25,
        FontWeight.w700,
      ),
      titleMedium: compact(
        baseAppTextTheme.titleMedium,
        16,
        1.25,
        FontWeight.w700,
      ),
      titleSmall: compact(
        baseAppTextTheme.titleSmall,
        15,
        1.25,
        FontWeight.w800,
      ),
      bodyLarge: compact(baseAppTextTheme.bodyLarge, 16, 1.36),
      bodyMedium: compact(baseAppTextTheme.bodyMedium, 15, 1.38),
      bodySmall: compact(baseAppTextTheme.bodySmall, 14, 1.33),
      labelLarge: compact(
        baseAppTextTheme.labelLarge,
        15,
        1.23,
        FontWeight.w600,
      ),
      labelMedium: compact(
        baseAppTextTheme.labelMedium,
        14,
        1.25,
        FontWeight.w600,
      ),
      labelSmall: compact(
        baseAppTextTheme.labelSmall,
        12,
        1.27,
        FontWeight.w600,
      ),
    );

    final colorScheme = _colorScheme(brightness, palette);
    final compactButtonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
    );
    final compactButtonPadding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
    );
    const compactButtonMinimum = Size(0, AppSizes.controlHeight);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: palette.frame,
      visualDensity: VisualDensity.compact,
    );

    return base.copyWith(
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: palette.frame,
      dividerTheme: DividerThemeData(
        color: palette.border,
        space: 1,
        thickness: 1,
      ),
      extensions: [palette],
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: palette.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        constraints: const BoxConstraints.tightFor(
          height: AppSizes.controlHeight,
        ),
        border: _fieldBorder(palette.border),
        enabledBorder: _fieldBorder(palette.border),
        focusedBorder: _fieldBorder(palette.primary),
        disabledBorder: _fieldBorder(palette.border),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.primary,
        selectionColor: palette.primary.withValues(alpha: 0.22),
        selectionHandleColor: palette.primary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.borderStrong),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: palette.text),
        waitDuration: const Duration(milliseconds: 450),
      ),
      splashFactory: NoSplash.splashFactory,
      hoverColor: palette.muted,
      focusColor: palette.primarySoft,
      highlightColor: Colors.transparent,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          disabledBackgroundColor: palette.border,
          disabledForegroundColor: palette.textSubtle,
          minimumSize: compactButtonMinimum,
          padding: compactButtonPadding,
          shape: compactButtonShape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: textTheme.labelLarge,
          visualDensity: VisualDensity.compact,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.text,
          minimumSize: compactButtonMinimum,
          padding: compactButtonPadding,
          shape: compactButtonShape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: textTheme.labelLarge,
          visualDensity: VisualDensity.compact,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          side: BorderSide(color: palette.border),
          minimumSize: compactButtonMinimum,
          padding: compactButtonPadding,
          shape: compactButtonShape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: textTheme.labelLarge,
          visualDensity: VisualDensity.compact,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? palette.primarySoft
                : palette.muted;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? palette.textSubtle
                : palette.text;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const WidgetStatePropertyAll(
            Size(0, AppSizes.controlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
          shape: WidgetStatePropertyAll(compactButtonShape),
        ),
      ),
      switchTheme: const SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          visualDensity: VisualDensity.compact,
          minimumSize: const Size.square(AppSizes.iconButton),
          fixedSize: const Size.square(AppSizes.iconButton),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: palette.text,
        unselectedLabelColor: palette.textMuted,
        labelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelMedium,
        dividerColor: palette.border,
        indicatorColor: palette.primary,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
    );
  }

  static ColorScheme _colorScheme(Brightness brightness, AppPalette palette) {
    final dark = brightness == Brightness.dark;
    return ColorScheme(
      brightness: brightness,
      primary: palette.primary,
      onPrimary: dark ? const Color(0xFF06210C) : Colors.white,
      primaryContainer: palette.primarySoft,
      onPrimaryContainer: palette.primaryDark,
      secondary: dark ? const Color(0xFFC6C9C4) : const Color(0xFF5C5F60),
      onSecondary: dark ? const Color(0xFF202420) : Colors.white,
      secondaryContainer: dark
          ? const Color(0xFF363B35)
          : const Color(0xFFE1E3E4),
      onSecondaryContainer: dark
          ? const Color(0xFFE2E6DF)
          : const Color(0xFF454748),
      tertiary: dark ? const Color(0xFFFFB2BE) : const Color(0xFF722736),
      onTertiary: dark ? const Color(0xFF45000F) : Colors.white,
      tertiaryContainer: dark
          ? const Color(0xFF5B1725)
          : const Color(0xFFFFD9DD),
      onTertiaryContainer: dark
          ? const Color(0xFFFFD9DD)
          : const Color(0xFF3F0112),
      error: palette.error,
      onError: dark ? const Color(0xFF690005) : Colors.white,
      errorContainer: palette.errorSoft,
      onErrorContainer: dark
          ? const Color(0xFFFFDAD6)
          : const Color(0xFF93000A),
      surface: palette.frame,
      onSurface: palette.text,
      surfaceContainerLowest: palette.surface,
      surfaceContainerLow: palette.sidebar,
      surfaceContainer: palette.muted,
      surfaceContainerHigh: dark
          ? const Color(0xFF2A312A)
          : const Color(0xFFE6E9E2),
      surfaceContainerHighest: dark
          ? const Color(0xFF333B33)
          : const Color(0xFFE0E4DC),
      onSurfaceVariant: palette.textMuted,
      outline: palette.borderStrong,
      outlineVariant: palette.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: dark ? const Color(0xFFE8EEE7) : const Color(0xFF2D322D),
      onInverseSurface: dark
          ? const Color(0xFF202420)
          : const Color(0xFFEEF2EB),
      inversePrimary: dark ? AppColors.primary : const Color(0xFF8BD79B),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: BorderSide(color: color),
    );
  }
}
