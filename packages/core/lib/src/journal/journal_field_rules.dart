import '../database/tables.dart';

/// Field limits shared by the thread wizard and [createOpenThread].
/// They match the checks declared on `OpenThreads`.
class JournalFieldRules {
  const JournalFieldRules._();

  static const int titleMax = 280;
  static const int anchorMax = 1000;
  static const int passphraseMin = 8;

  static String? titleError(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) {
      return 'Name the moment.';
    }
    if (value.length > titleMax) {
      return 'Keep the name to $titleMax characters.';
    }
    return null;
  }

  static String? anchorError(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) {
      return 'Write a physical anchor.';
    }
    if (value.length > anchorMax) {
      return 'Keep the anchor to $anchorMax characters.';
    }
    return null;
  }

  static String? worryError(String raw) {
    if (raw.trim().isEmpty) {
      return 'Write the worry in your own words.';
    }
    return null;
  }

  static String? fearError(int value) {
    if (value < 1 || value > 10) {
      return 'Fear is a whole number from 1 to 10.';
    }
    return null;
  }

  static String? passphraseError(String passphrase, String confirmation) {
    if (passphrase.length < passphraseMin) {
      return 'Use at least $passphraseMin characters.';
    }
    if (passphrase != confirmation) {
      return 'The two passphrases do not match.';
    }
    return null;
  }

  /// Drops blank worries and renumbers the rest as `01`, `02`, ...
  static List<UnraveledWorryItem> normalizeWorries(
    List<UnraveledWorryItem> worries,
  ) {
    final List<UnraveledWorryItem> kept = worries
        .where((UnraveledWorryItem item) => item.worryText.trim().isNotEmpty)
        .toList(growable: false);
    if (kept.isEmpty) {
      throw ArgumentError('Write at least one worry.');
    }
    return <UnraveledWorryItem>[
      for (int i = 0; i < kept.length; i++)
        UnraveledWorryItem(
          indexNumber: (i + 1).toString().padLeft(2, '0'),
          worryText: kept[i].worryText.trim(),
          controlScope: kept[i].controlScope,
          actionOrGrounding: kept[i].actionOrGrounding.trim(),
        ),
    ];
  }
}
