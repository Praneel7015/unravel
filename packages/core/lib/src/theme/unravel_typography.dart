import 'package:flutter/material.dart';

import 'unravel_theme_extension.dart';

/// Typography shared by the FOSS app, the store app, and the website.
///
/// - Editorial serif (`IBM Plex Serif`): screen headers, event titles, italic quotes, spoken transcripts.
/// - Humanist sans (`IBM Plex Sans`): body copy, card descriptions, pill buttons.
/// - Technical monospace (`IBM Plex Mono`): circadian time pills, worry indices (`01`, `02`), audio timers.
@immutable
class UnravelTypography {
  const UnravelTypography({
    required this.displaySerif,
    required this.eventTitleSerif,
    required this.quoteSerifItalic,
    required this.transcriptSerifItalic,
    required this.headlineSans,
    required this.settingTitleSans,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.pillButton,
    required this.metaMono,
    required this.worryIndexMono,
    required this.audioTimerMono,
  });

  static const String serifFamily = 'IBM Plex Serif';
  static const String sansFamily = 'IBM Plex Sans';
  static const String monoFamily = 'IBM Plex Mono';

  /// Screen headers (`IBM Plex Serif`, 34px / 40px line-height, -0.02em tracking).
  final TextStyle displaySerif;

  /// Active life event headings (`IBM Plex Serif`, 22px / 28px line-height).
  final TextStyle eventTitleSerif;

  /// Daily Stoic / nature quote (`IBM Plex Serif` italic, 19px / 28px line-height).
  final TextStyle quoteSerifItalic;

  /// Spoken voice transcript quote (`IBM Plex Serif` italic, 16px / 24px line-height).
  final TextStyle transcriptSerifItalic;

  /// Section/card headline (`IBM Plex Sans`, 20px / 26px line-height, w600, -0.015em).
  final TextStyle headlineSans;

  /// Sanctuary setting row title (`IBM Plex Sans`, 16px / 22px, w600).
  final TextStyle settingTitleSans;

  /// Primary body copy (`IBM Plex Sans`, 16px / 24px line-height, w400).
  final TextStyle bodyLarge;

  /// Secondary body / card description (`IBM Plex Sans`, 14px / 20px line-height, w400).
  final TextStyle bodyMedium;

  /// Primary pill button label (`IBM Plex Sans`, 15px / 20px, w600).
  final TextStyle pillButton;

  /// Circadian sun pill and metadata (`IBM Plex Mono`, 11px / 16px line-height, +0.04em).
  final TextStyle metaMono;

  /// Numbered worry indices `01`, `02` (`IBM Plex Mono`, 12px / 16px, w500).
  final TextStyle worryIndexMono;

  /// Voice reflection timer `0:42 / 1:00` (`IBM Plex Mono`, 13px / 18px, w500).
  final TextStyle audioTimerMono;

  /// Builds the full [UnravelTypography] suite bound to the active [UnravelThemeExtension].
  factory UnravelTypography.fromExtension(UnravelThemeExtension ext) {
    final Color primary = ext.textPrimary;
    final Color muted = ext.textMuted;

    return UnravelTypography(
      displaySerif: _serif(
        fontSize: 34,
        height: 40 / 34,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.02 * 34,
        color: primary,
      ),
      eventTitleSerif: _serif(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.015 * 22,
        color: primary,
      ),
      quoteSerifItalic: _serif(
        fontSize: 19,
        height: 28 / 19,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: primary,
      ),
      transcriptSerifItalic: _serif(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: primary,
      ),
      headlineSans: _sans(
        fontSize: 20,
        height: 26 / 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.015 * 20,
        color: primary,
      ),
      settingTitleSans: _sans(
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: _sans(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: _sans(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      pillButton: _sans(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: FontWeight.w600,
        color: ext.onPrimaryAccent,
      ),
      metaMono: _mono(
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.04 * 11,
        color: muted,
      ),
      worryIndexMono: _mono(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.04 * 12,
        color: ext.secondaryAccent,
      ),
      audioTimerMono: _mono(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.04 * 13,
        color: primary,
      ),
    );
  }

  static TextStyle _serif({
    required double fontSize,
    required double height,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle _sans({
    required double fontSize,
    required double height,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: sansFamily,
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle _mono({
    required double fontSize,
    required double height,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  /// Converts to Flutter's standard [TextTheme] for seamless Material widget integration.
  TextTheme toMaterialTextTheme() {
    return TextTheme(
      displayLarge: displaySerif,
      displayMedium: eventTitleSerif,
      headlineMedium: headlineSans,
      titleLarge: eventTitleSerif,
      titleMedium: settingTitleSans,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      labelLarge: pillButton,
      labelSmall: metaMono,
    );
  }
}
