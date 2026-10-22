import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'unravel_theme_extension.dart';

/// Typography system for Unravel's Botanical & Circadian Field Journal:
/// - Editorial Serif (`Newsreader`): Screen headers, event titles, italic quotes, spoken transcripts.
/// - Humanist Sans (`Plus Jakarta Sans`): Body copy, card descriptions, pill buttons.
/// - Technical Monospace (`JetBrains Mono`): Circadian time pills, numbered worry indices (`01`, `02`), audio timers (`0:42 / 1:00`).
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

  /// Screen headers (`Newsreader`, 34px / 40px line-height, -0.02em tracking).
  final TextStyle displaySerif;

  /// Active life event headings (`Newsreader`, 22px / 28px line-height).
  final TextStyle eventTitleSerif;

  /// Daily Stoic / Nature quote (`Newsreader` italic, 19px / 28px line-height).
  final TextStyle quoteSerifItalic;

  /// Spoken voice transcript quote (`Newsreader` italic, 16px / 24px line-height).
  final TextStyle transcriptSerifItalic;

  /// Section/card headline (`Plus Jakarta Sans`, 20px / 26px line-height, w600, -0.015em).
  final TextStyle headlineSans;

  /// Sanctuary setting row title (`Plus Jakarta Sans`, 16px / 22px, w600) —
  /// designed to wrap cleanly without `...` truncation.
  final TextStyle settingTitleSans;

  /// Primary body copy (`Plus Jakarta Sans`, 16px / 24px line-height, w400).
  final TextStyle bodyLarge;

  /// Secondary body / card description (`Plus Jakarta Sans`, 14px / 20px line-height, w400).
  final TextStyle bodyMedium;

  /// Primary pill button label (`Plus Jakarta Sans`, 15px / 20px, w600).
  final TextStyle pillButton;

  /// Circadian sun pill & metadata (`JetBrains Mono`, 11px / 16px line-height, +0.04em).
  final TextStyle metaMono;

  /// Numbered worry indices `01`, `02` (`JetBrains Mono`, 12px / 16px, w500).
  final TextStyle worryIndexMono;

  /// Voice reflection timer `0:42 / 1:00` (`JetBrains Mono`, 13px / 18px, w500).
  final TextStyle audioTimerMono;

  /// Enforces air-gapped F-Droid compliance by disabling runtime HTTP font
  /// fetching from `fonts.gstatic.com`. Call once in `main()` before `runApp`.
  static void enforceAirGappedFonts() {
    GoogleFonts.config.allowRuntimeFetching = false;
  }

  /// Builds the full [UnravelTypography] suite bound to the active [UnravelThemeExtension].
  factory UnravelTypography.fromExtension(UnravelThemeExtension ext) {
    final Color primary = ext.textPrimary;
    final Color muted = ext.textMuted;

    return UnravelTypography(
      displaySerif: GoogleFonts.newsreader(
        fontSize: 34,
        height: 40 / 34,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.02 * 34,
        color: primary,
      ),
      eventTitleSerif: GoogleFonts.newsreader(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.015 * 22,
        color: primary,
      ),
      quoteSerifItalic: GoogleFonts.newsreader(
        fontSize: 19,
        height: 28 / 19,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: primary,
      ),
      transcriptSerifItalic: GoogleFonts.newsreader(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: primary,
      ),
      headlineSans: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        height: 26 / 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.015 * 20,
        color: primary,
      ),
      settingTitleSans: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      pillButton: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: FontWeight.w600,
        color: ext.onPrimaryAccent,
      ),
      metaMono: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.04 * 11,
        color: muted,
      ),
      worryIndexMono: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.04 * 12,
        color: ext.secondaryAccent,
      ),
      audioTimerMono: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.04 * 13,
        color: primary,
      ),
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
