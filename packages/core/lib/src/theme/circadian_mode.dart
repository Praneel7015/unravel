import 'package:meta/meta.dart';

/// The 4 nature-derived Circadian surface palettes in Unravel.
enum CircadianPalette {
  /// 06:00–11:00 — Warm Birch Paper Light
  morningMist(
    id: 'morning_mist',
    displayName: 'Morning Mist',
    subtitle: 'Birch Paper Light · 06:00–11:00',
    sunPillPrefix: 'Dawn',
    isDark: false,
  ),

  /// 11:00–17:30 — Raw Limestone Neutral
  highSun(
    id: 'high_sun',
    displayName: 'High Sun',
    subtitle: 'Raw Limestone Neutral · 11:00–17:30',
    sunPillPrefix: 'Midday',
    isDark: false,
  ),

  /// 17:30–23:00 — Evening Nature Dark (Primary Default Canvas)
  duskPine(
    id: 'dusk_pine',
    displayName: 'Dusk Pine',
    subtitle: 'Evening Nature Dark · 17:30–23:00',
    sunPillPrefix: 'Dusk',
    isDark: true,
  ),

  /// 23:00–06:00 — Pure Pitch Black OLED
  midnightStarlight(
    id: 'midnight_starlight',
    displayName: 'Midnight Starlight',
    subtitle: 'Pure OLED Black · 23:00–06:00',
    sunPillPrefix: 'Starlight',
    isDark: true,
  );

  const CircadianPalette({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.sunPillPrefix,
    required this.isDark,
  });

  final String id;
  final String displayName;
  final String subtitle;
  final String sunPillPrefix;
  final bool isDark;
}

/// User-selectable theme mode in Sanctuary settings.
/// Supports automatic time-of-day shifting ("Circadian Rhythm Mode")
/// as well as manual overrides for any of the 4 palettes.
enum CircadianThemePreference {
  circadianAuto('circadian_auto', 'Circadian Rhythm Mode'),
  morningMist('morning_mist', 'Morning Mist'),
  highSun('high_sun', 'High Sun'),
  duskPine('dusk_pine', 'Dusk Pine'),
  midnightStarlight('midnight_starlight', 'Midnight Starlight');

  const CircadianThemePreference(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static CircadianThemePreference fromStorageKey(String? key) {
    for (final value in CircadianThemePreference.values) {
      if (value.storageKey == key) {
        return value;
      }
    }
    return CircadianThemePreference.circadianAuto;
  }
}

/// Pure, deterministic time-of-day resolver for Unravel's Circadian Theme Engine.
@immutable
abstract final class CircadianResolver {
  // Minute-of-day boundaries:
  // 06:00 = 360
  // 11:00 = 660
  // 17:30 = 1050
  // 23:00 = 1380
  static const int _morningStartMinutes = 6 * 60; // 360 (06:00)
  static const int _highSunStartMinutes = 11 * 60; // 660 (11:00)
  static const int _duskPineStartMinutes = 17 * 60 + 30; // 1050 (17:30)
  static const int _midnightStartMinutes = 23 * 60; // 1380 (23:00)

  /// Resolves the active [CircadianPalette] given user [preference] and local [now].
  static CircadianPalette resolvePalette({
    required CircadianThemePreference preference,
    DateTime? now,
  }) {
    switch (preference) {
      case CircadianThemePreference.morningMist:
        return CircadianPalette.morningMist;
      case CircadianThemePreference.highSun:
        return CircadianPalette.highSun;
      case CircadianThemePreference.duskPine:
        return CircadianPalette.duskPine;
      case CircadianThemePreference.midnightStarlight:
        return CircadianPalette.midnightStarlight;
      case CircadianThemePreference.circadianAuto:
        return resolveForTime(now ?? DateTime.now());
    }
  }

  /// Resolves the [CircadianPalette] strictly from the local time of day:
  /// - 06:00–11:00 -> Morning Mist
  /// - 11:00–17:30 -> High Sun
  /// - 17:30–23:00 -> Dusk Pine
  /// - 23:00–06:00 -> Midnight Starlight (OLED)
  static CircadianPalette resolveForTime(DateTime localTime) {
    final int minutesFromMidnight = localTime.hour * 60 + localTime.minute;

    if (minutesFromMidnight >= _morningStartMinutes &&
        minutesFromMidnight < _highSunStartMinutes) {
      return CircadianPalette.morningMist;
    }
    if (minutesFromMidnight >= _highSunStartMinutes &&
        minutesFromMidnight < _duskPineStartMinutes) {
      return CircadianPalette.highSun;
    }
    if (minutesFromMidnight >= _duskPineStartMinutes &&
        minutesFromMidnight < _midnightStartMinutes) {
      return CircadianPalette.duskPine;
    }
    return CircadianPalette.midnightStarlight;
  }

  /// Computes the exact next [DateTime] when the Circadian palette will shift,
  /// allowing a single timer to schedule the next transition without polling.
  static DateTime nextTransitionTime(DateTime localTime) {
    final int minutesFromMidnight = localTime.hour * 60 + localTime.minute;
    final DateTime startOfToday = DateTime(
      localTime.year,
      localTime.month,
      localTime.day,
    );

    if (minutesFromMidnight < _morningStartMinutes) {
      return startOfToday.add(const Duration(minutes: _morningStartMinutes));
    }
    if (minutesFromMidnight < _highSunStartMinutes) {
      return startOfToday.add(const Duration(minutes: _highSunStartMinutes));
    }
    if (minutesFromMidnight < _duskPineStartMinutes) {
      return startOfToday.add(const Duration(minutes: _duskPineStartMinutes));
    }
    if (minutesFromMidnight < _midnightStartMinutes) {
      return startOfToday.add(const Duration(minutes: _midnightStartMinutes));
    }
    // Past 23:00: next transition is 06:00 tomorrow morning.
    final DateTime startOfTomorrow = DateTime(
      localTime.year,
      localTime.month,
      localTime.day + 1,
    );
    return startOfTomorrow.add(const Duration(minutes: _morningStartMinutes));
  }

  /// Formats the single lower Circadian sun pill label on the Home Journal
  /// (e.g., `Dawn · 7:15 AM` or `Dusk · 6:45 PM`).
  /// Note: Never render a second clock pill in the top-right app bar.
  static String formatSunPillLabel(DateTime localTime) {
    final CircadianPalette palette = resolveForTime(localTime);
    final int hour12 = localTime.hour % 12 == 0 ? 12 : localTime.hour % 12;
    final String minutePadded = localTime.minute.toString().padLeft(2, '0');
    final String period = localTime.hour >= 12 ? 'PM' : 'AM';
    return '${palette.sunPillPrefix} · $hour12:$minutePadded $period';
  }
}
