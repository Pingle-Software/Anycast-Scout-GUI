import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color frame = Color(0xFFFFFFFF);
  static const Color sidebar = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFF3F4F6);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderStrong = Color(0xFFD1D5DB);
  static const Color text = Color(0xFF181D18);
  static const Color textMuted = Color(0xFF404940);
  static const Color textSubtle = Color(0xFF6B7280);
  static const Color primary = Color(0xFF166534);
  static const Color primaryDark = Color(0xFF004C22);
  static const Color primarySoft = Color(0xFFE7F5EA);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorSoft = Color(0xFFFFDAD6);
}

/// Semantic dashboard colors resolved through the active Flutter theme.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.frame,
    required this.sidebar,
    required this.surface,
    required this.muted,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.error,
    required this.errorSoft,
  });

  static const light = AppPalette(
    frame: AppColors.frame,
    sidebar: AppColors.sidebar,
    surface: AppColors.surface,
    muted: AppColors.muted,
    border: AppColors.border,
    borderStrong: AppColors.borderStrong,
    text: AppColors.text,
    textMuted: AppColors.textMuted,
    textSubtle: AppColors.textSubtle,
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    primarySoft: AppColors.primarySoft,
    error: AppColors.error,
    errorSoft: AppColors.errorSoft,
  );

  static const dark = AppPalette(
    frame: Color(0xFF18181B),
    sidebar: Color(0xFF1D1D21),
    surface: Color(0xFF232329),
    muted: Color(0xFF2D2E35),
    border: Color(0xFF3A3B44),
    borderStrong: Color(0xFF4B4D58),
    text: Color(0xFFECECF2),
    textMuted: Color(0xFFC7C7D1),
    textSubtle: Color(0xFF90919C),
    primary: Color(0xFFC6B6F3),
    primaryDark: Color(0xFFE3D8FF),
    primarySoft: Color(0xFF352F46),
    error: Color(0xFFF38BA8),
    errorSoft: Color(0xFF3D2630),
  );

  final Color frame;
  final Color sidebar;
  final Color surface;
  final Color muted;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color error;
  final Color errorSoft;

  @override
  AppPalette copyWith({
    Color? frame,
    Color? sidebar,
    Color? surface,
    Color? muted,
    Color? border,
    Color? borderStrong,
    Color? text,
    Color? textMuted,
    Color? textSubtle,
    Color? primary,
    Color? primaryDark,
    Color? primarySoft,
    Color? error,
    Color? errorSoft,
  }) {
    return AppPalette(
      frame: frame ?? this.frame,
      sidebar: sidebar ?? this.sidebar,
      surface: surface ?? this.surface,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primarySoft: primarySoft ?? this.primarySoft,
      error: error ?? this.error,
      errorSoft: errorSoft ?? this.errorSoft,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }
    return AppPalette(
      frame: Color.lerp(frame, other.frame, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorSoft: Color.lerp(errorSoft, other.errorSoft, t)!,
    );
  }
}

/// Convenience access to the active [AppPalette].
extension AppPaletteLookup on BuildContext {
  AppPalette get appPalette {
    return Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
  }
}

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double settingsSection = 28;
}

class AppRadii {
  const AppRadii._();

  static const double xs = 4;
  static const double sm = 4;
  static const double md = 8;
  static const double pill = 999;
}

class AppSizes {
  const AppSizes._();

  static const double appMinWidth = 700;
  static const double appMinHeight = 480;
  static const double titleBarHeight = 32;
  static const double contentToolbarHeight = 36;
  static const double workflowBarHeight = 56;
  static const double sidebarWidth = 184;
  static const double resultsMinWidth = 580;
  static const double logPanelHeight = 178;
  static const double metricWidth = 112;
  static const double metricTextWidth = 136;
  static const double iconFrame = 32;
  static const double iconGlyph = 18;
  static const double iconButton = iconFrame;
  static const double navButtonHeight = 36;
  static const double controlHeight = 40;
  static const double compactControlHeight = controlHeight;
  static const double icon = 18;
  static const double compactIcon = 16;
  static const double twoLineTextHeight = iconFrame;
  static const double twoLinePrimaryFontSize = 13;
  static const double twoLinePrimaryLineHeight = 15;
  static const double twoLineSecondaryFontSize = 12;
  static const double twoLineSecondaryLineHeight = 16;
  static const double twoLineGap = 2;
  static const double statusLabelWidth = 82;
  static const double dialogWidth = 760;
  static const double dialogMaxHeight = 680;
}

class AppDurations {
  const AppDurations._();

  static const Duration artifactRefresh = Duration(seconds: 1);
  static const Duration clockTick = Duration(seconds: 1);
}

class AppInsets {
  const AppInsets._();

  static const page = EdgeInsets.all(AppSpacing.lg);
  static const panel = EdgeInsets.all(AppSpacing.lg);
  static const compactPanel = EdgeInsets.all(AppSpacing.md);
  static const chip = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );
}
