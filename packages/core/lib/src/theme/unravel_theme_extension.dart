import 'package:flutter/material.dart';

import 'circadian_mode.dart';

/// Immutable `ThemeExtension` implementing Unravel's 4 Circadian Botanical palettes.
///
/// Strictly uses muted earth pigments (Lichen Green, River Moss, Warm Amber,
/// Morning Clay, Terracotta, Birch Paper, Raw Limestone, Dusk Pine, OLED Pitch Black)
/// with 1px solid borders and zero neon drop-shadows.
@immutable
class UnravelThemeExtension extends ThemeExtension<UnravelThemeExtension> {
  const UnravelThemeExtension({
    required this.palette,
    required this.isDark,
    required this.canvas,
    required this.surfaceLow,
    required this.card,
    required this.groundingContainer,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textMuted,
    required this.primaryAccent,
    required this.onPrimaryAccent,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondaryAccent,
    required this.onSecondaryAccent,
    required this.terracottaAccent,
    required this.fearPredictedLine,
    required this.lifeUnfoldedLine,
  });

  final CircadianPalette palette;
  final bool isDark;

  /// Primary screen background canvas.
  final Color canvas;

  /// Subtle intermediate surface container.
  final Color surfaceLow;

  /// Standard card surface (`#EFECE6` Morning Mist, `#E0DDD5` High Sun,
  /// `#1C221E` Dusk Pine, `#0B0C0B` Midnight Starlight).
  final Color card;

  /// Highlighted box inside Open Thread cards for the Grounding Anchor
  /// (`#242B26` in Dusk Pine).
  final Color groundingContainer;

  /// Crisp 1px solid border (`#DCD8CE` Morning Mist, `#CCC8BE` High Sun,
  /// `#2A332D` Dusk Pine, `#222623` Midnight Starlight).
  final Color border;

  /// Subtle divider border (`#1F2621` in Dusk Pine).
  final Color borderSubtle;

  /// High-contrast botanical ink or warm parchment text.
  final Color textPrimary;

  /// Muted secondary caption/metadata text.
  final Color textMuted;

  /// Primary botanical accent (`#3B5944` River Moss / Wild Sage,
  /// `#84A98C` Lichen Green, `#749C82` Moonlit Fern).
  final Color primaryAccent;

  /// Foreground text/icon color on top of [primaryAccent] pills.
  final Color onPrimaryAccent;

  /// Soft container fill for active badges/chips.
  final Color primaryContainer;

  /// Foreground color on top of [primaryContainer].
  final Color onPrimaryContainer;

  /// Secondary warm pigment (`#C87D55` Morning Clay, `#C98A3A` Ochre Sun,
  /// `#D49A59` Warm Amber, `#C97054` Terracotta).
  final Color secondaryAccent;

  /// Foreground color on top of [secondaryAccent].
  final Color onSecondaryAccent;

  /// Terracotta earth pigment (`#C97054`).
  final Color terracottaAccent;

  /// Dashed line color for "What My Fear Predicted" on the Perspective Curve.
  final Color fearPredictedLine;

  /// Solid spline color for "How Life Actually Unfolded" on the Perspective Curve.
  final Color lifeUnfoldedLine;

  /// 1. Morning Mist (06:00–11:00 — Warm Birch Paper Light)
  /// Canvas `#F6F5F0`, Card `#EFECE6`, Border `#DCD8CE`, Text `#1C1E1B`,
  /// Muted `#60645D`, Primary Accent `#3B5944` (River Moss), Secondary `#C87D55` (Morning Clay).
  static const UnravelThemeExtension morningMist = UnravelThemeExtension(
    palette: CircadianPalette.morningMist,
    isDark: false,
    canvas: Color(0xFFF6F5F0),
    surfaceLow: Color(0xFFF2EFE9),
    card: Color(0xFFEFECE6),
    groundingContainer: Color(0xFFE5E1D8),
    border: Color(0xFFDCD8CE),
    borderSubtle: Color(0xFFE6E2D9),
    textPrimary: Color(0xFF1C1E1B),
    textMuted: Color(0xFF60645D),
    primaryAccent: Color(0xFF3B5944),
    onPrimaryAccent: Color(0xFFF6F5F0),
    primaryContainer: Color(0xFFDCE6DE),
    onPrimaryContainer: Color(0xFF1C2D21),
    secondaryAccent: Color(0xFFC87D55),
    onSecondaryAccent: Color(0xFFFDFBF7),
    terracottaAccent: Color(0xFFC97054),
    fearPredictedLine: Color(0xFFC97054),
    lifeUnfoldedLine: Color(0xFF4A6B53),
  );

  /// 2. High Sun (11:00–17:30 — Raw Limestone Neutral)
  /// Canvas `#EAE8E1`, Card `#E0DDD5`, Border `#CCC8BE`, Text `#181A18`,
  /// Primary Accent `#3B5944` (Wild Sage), Secondary `#C98A3A` (Ochre Sun).
  static const UnravelThemeExtension highSun = UnravelThemeExtension(
    palette: CircadianPalette.highSun,
    isDark: false,
    canvas: Color(0xFFEAE8E1),
    surfaceLow: Color(0xFFE5E2DA),
    card: Color(0xFFE0DDD5),
    groundingContainer: Color(0xFFD6D2C8),
    border: Color(0xFFCCC8BE),
    borderSubtle: Color(0xFFD8D4CA),
    textPrimary: Color(0xFF181A18),
    textMuted: Color(0xFF5A5E58),
    primaryAccent: Color(0xFF3B5944),
    onPrimaryAccent: Color(0xFFF6F5F0),
    primaryContainer: Color(0xFFD2DDD4),
    onPrimaryContainer: Color(0xFF18261C),
    secondaryAccent: Color(0xFFC98A3A),
    onSecondaryAccent: Color(0xFF1F1405),
    terracottaAccent: Color(0xFFC97054),
    fearPredictedLine: Color(0xFFC97054),
    lifeUnfoldedLine: Color(0xFF3B5944),
  );

  /// 3. Dusk Pine (17:30–23:00 — Evening Nature Dark)
  /// Canvas `#141815`, Card `#1C221E`, Border `#2A332D`, Text `#E8E6DF`,
  /// Muted `#959E97`, Primary Accent `#84A98C` (Lichen Green), Secondary `#D49A59` (Warm Amber).
  static const UnravelThemeExtension duskPine = UnravelThemeExtension(
    palette: CircadianPalette.duskPine,
    isDark: true,
    canvas: Color(0xFF141815),
    surfaceLow: Color(0xFF181D19),
    card: Color(0xFF1C221E),
    groundingContainer: Color(0xFF242B26),
    border: Color(0xFF2A332D),
    borderSubtle: Color(0xFF1F2621),
    textPrimary: Color(0xFFE8E6DF),
    textMuted: Color(0xFF959E97),
    primaryAccent: Color(0xFF84A98C),
    onPrimaryAccent: Color(0xFF111C15),
    primaryContainer: Color(0xFF2D4233),
    onPrimaryContainer: Color(0xFFD8E8DC),
    secondaryAccent: Color(0xFFD49A59),
    onSecondaryAccent: Color(0xFF2B1B06),
    terracottaAccent: Color(0xFFC97054),
    fearPredictedLine: Color(0xFFC97054),
    lifeUnfoldedLine: Color(0xFF84A98C),
  );

  /// 4. Midnight Starlight (23:00–06:00 — Pure OLED Black)
  /// Canvas `#000000`, Card `#0B0C0B`, Crisp 1px Border `#222623`, Text `#F2F0E8`,
  /// Muted `#8E948F`, Primary Accent `#749C82` (Moonlit Fern), Secondary `#C97054` (Terracotta).
  static const UnravelThemeExtension midnightStarlight = UnravelThemeExtension(
    palette: CircadianPalette.midnightStarlight,
    isDark: true,
    canvas: Color(0xFF000000),
    surfaceLow: Color(0xFF060706),
    card: Color(0xFF0B0C0B),
    groundingContainer: Color(0xFF131614),
    border: Color(0xFF222623),
    borderSubtle: Color(0xFF161917),
    textPrimary: Color(0xFFF2F0E8),
    textMuted: Color(0xFF8E948F),
    primaryAccent: Color(0xFF749C82),
    onPrimaryAccent: Color(0xFF0B140E),
    primaryContainer: Color(0xFF1E2E24),
    onPrimaryContainer: Color(0xFFD6E6DC),
    secondaryAccent: Color(0xFFC97054),
    onSecondaryAccent: Color(0xFF240E07),
    terracottaAccent: Color(0xFFC97054),
    fearPredictedLine: Color(0xFFC97054),
    lifeUnfoldedLine: Color(0xFF749C82),
  );

  /// Resolves the corresponding [UnravelThemeExtension] for any [CircadianPalette].
  static UnravelThemeExtension fromPalette(CircadianPalette palette) {
    switch (palette) {
      case CircadianPalette.morningMist:
        return morningMist;
      case CircadianPalette.highSun:
        return highSun;
      case CircadianPalette.duskPine:
        return duskPine;
      case CircadianPalette.midnightStarlight:
        return midnightStarlight;
    }
  }

  @override
  UnravelThemeExtension copyWith({
    CircadianPalette? palette,
    bool? isDark,
    Color? canvas,
    Color? surfaceLow,
    Color? card,
    Color? groundingContainer,
    Color? border,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textMuted,
    Color? primaryAccent,
    Color? onPrimaryAccent,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondaryAccent,
    Color? onSecondaryAccent,
    Color? terracottaAccent,
    Color? fearPredictedLine,
    Color? lifeUnfoldedLine,
  }) {
    return UnravelThemeExtension(
      palette: palette ?? this.palette,
      isDark: isDark ?? this.isDark,
      canvas: canvas ?? this.canvas,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      card: card ?? this.card,
      groundingContainer: groundingContainer ?? this.groundingContainer,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      primaryAccent: primaryAccent ?? this.primaryAccent,
      onPrimaryAccent: onPrimaryAccent ?? this.onPrimaryAccent,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      onSecondaryAccent: onSecondaryAccent ?? this.onSecondaryAccent,
      terracottaAccent: terracottaAccent ?? this.terracottaAccent,
      fearPredictedLine: fearPredictedLine ?? this.fearPredictedLine,
      lifeUnfoldedLine: lifeUnfoldedLine ?? this.lifeUnfoldedLine,
    );
  }

  @override
  UnravelThemeExtension lerp(
    covariant ThemeExtension<UnravelThemeExtension>? other,
    double t,
  ) {
    if (other is! UnravelThemeExtension) {
      return this;
    }
    return UnravelThemeExtension(
      palette: t < 0.5 ? palette : other.palette,
      isDark: t < 0.5 ? isDark : other.isDark,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      card: Color.lerp(card, other.card, t)!,
      groundingContainer:
          Color.lerp(groundingContainer, other.groundingContainer, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primaryAccent: Color.lerp(primaryAccent, other.primaryAccent, t)!,
      onPrimaryAccent: Color.lerp(onPrimaryAccent, other.onPrimaryAccent, t)!,
      primaryContainer:
          Color.lerp(primaryContainer, other.primaryContainer, t)!,
      onPrimaryContainer:
          Color.lerp(onPrimaryContainer, other.onPrimaryContainer, t)!,
      secondaryAccent: Color.lerp(secondaryAccent, other.secondaryAccent, t)!,
      onSecondaryAccent:
          Color.lerp(onSecondaryAccent, other.onSecondaryAccent, t)!,
      terracottaAccent:
          Color.lerp(terracottaAccent, other.terracottaAccent, t)!,
      fearPredictedLine:
          Color.lerp(fearPredictedLine, other.fearPredictedLine, t)!,
      lifeUnfoldedLine:
          Color.lerp(lifeUnfoldedLine, other.lifeUnfoldedLine, t)!,
    );
  }
}

/// Ergonomic lookup for [UnravelThemeExtension] on [BuildContext].
extension UnravelThemeContextExtension on BuildContext {
  UnravelThemeExtension get unravelTheme =>
      Theme.of(this).extension<UnravelThemeExtension>() ??
      UnravelThemeExtension.duskPine;
}
