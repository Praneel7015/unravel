import 'package:flutter/material.dart';

import 'circadian_mode.dart';
import 'unravel_theme_extension.dart';
import 'unravel_typography.dart';

/// Builds complete Flutter [ThemeData] instances for all 4 Circadian modes.
abstract final class UnravelTheme {
  static const double cardRadius = 16.0;
  static const double cardPadding = 20.0;
  static const double screenMargin = 20.0;
  static const double sectionGap = 28.0;
  static const double borderWidth = 1.0;

  /// Builds a [ThemeData] for the given [CircadianPalette].
  static ThemeData forPalette(CircadianPalette palette) {
    final UnravelThemeExtension ext = UnravelThemeExtension.fromPalette(palette);
    return fromExtension(ext);
  }

  /// Resolves and builds a [ThemeData] from user [preference] and [now].
  static ThemeData resolve({
    required CircadianThemePreference preference,
    DateTime? now,
  }) {
    final CircadianPalette palette = CircadianResolver.resolvePalette(
      preference: preference,
      now: now,
    );
    return forPalette(palette);
  }

  /// Constructs the Material 3 [ThemeData] strictly adhering to `DESIGN.md`:
  /// - 1px solid borders (`#2A332D` Dusk Pine, `#DCD8CE` Morning Mist, etc.)
  /// - Zero drop-shadows (`elevation: 0`, `shadowColor: Colors.transparent`)
  /// - Pill buttons (`StadiumBorder`, padding `14px 24px`)
  /// - Card containers (`border-radius: 16px`, `1px solid` border)
  static ThemeData fromExtension(UnravelThemeExtension ext) {
    final UnravelTypography typography = UnravelTypography.fromExtension(ext);
    final Brightness brightness =
        ext.isDark ? Brightness.dark : Brightness.light;

    final ColorScheme colorScheme = ColorScheme(
      brightness: brightness,
      primary: ext.primaryAccent,
      onPrimary: ext.onPrimaryAccent,
      primaryContainer: ext.primaryContainer,
      onPrimaryContainer: ext.onPrimaryContainer,
      secondary: ext.secondaryAccent,
      onSecondary: ext.onSecondaryAccent,
      tertiary: ext.terracottaAccent,
      onTertiary: ext.onPrimaryAccent,
      error: ext.terracottaAccent,
      onError: ext.onPrimaryAccent,
      surface: ext.canvas,
      onSurface: ext.textPrimary,
      onSurfaceVariant: ext.textMuted,
      outline: ext.border,
      outlineVariant: ext.borderSubtle,
      surfaceContainerLow: ext.surfaceLow,
      surfaceContainer: ext.card,
      surfaceContainerHigh: ext.groundingContainer,
    );

    final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cardRadius),
      side: BorderSide(color: ext.border, width: borderWidth),
    );

    final ButtonStyle primaryPillButtonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.all(ext.primaryAccent),
      foregroundColor: WidgetStateProperty.all(ext.onPrimaryAccent),
      textStyle: WidgetStateProperty.all(typography.pillButton),
      elevation: WidgetStateProperty.all(0),
      shadowColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      shape: WidgetStateProperty.all(const StadiumBorder()),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: ext.canvas,
      canvasColor: ext.canvas,
      colorScheme: colorScheme,
      textTheme: typography.toMaterialTextTheme(),
      dividerColor: ext.border,
      dividerTheme: DividerThemeData(
        color: ext.border,
        thickness: borderWidth,
        space: borderWidth,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ext.canvas,
        foregroundColor: ext.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: typography.displaySerif,
      ),
      cardTheme: CardThemeData(
        color: ext.card,
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ext.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: ext.border, width: borderWidth),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: primaryPillButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: primaryPillButtonStyle,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(ext.textPrimary),
          textStyle: WidgetStateProperty.all(typography.pillButton),
          elevation: WidgetStateProperty.all(0),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          side: WidgetStateProperty.all(
            BorderSide(color: ext.border, width: borderWidth),
          ),
          shape: WidgetStateProperty.all(const StadiumBorder()),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[ext],
    );
  }
}
