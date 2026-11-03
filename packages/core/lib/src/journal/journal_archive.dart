import 'dart:convert';
import 'dart:typed_data';

import '../crypto/envelope_encryption_service.dart';

/// A journal file that can move from the open-source app into the store app.
/// A file marked `store` is refused by the open-source app before it is decrypted.
class JournalArchive {
  const JournalArchive({
    required this.edition,
    required this.wrappedKey,
    required this.encryptedPayload,
  });

  static const String magic = 'UNRAVEL';
  static const int schemaVersion = 1;
  static const String fossEdition = 'foss';
  static const String storeEdition = 'store';

  final String edition;
  final WrappedMasterKeyBundle wrappedKey;
  final String encryptedPayload;

  static Uint8List encode(JournalArchive archive) {
    final String encoded = jsonEncode(<String, Object?>{
      'magic': magic,
      'schema': schemaVersion,
      'edition': archive.edition,
      'wrappedKey': archive.wrappedKey.toJson(),
      'archive': archive.encryptedPayload,
    });
    final Uint8List bytes = Uint8List.fromList(utf8.encode(encoded));
    if (bytes.length > kMaxJournalArchiveBytes) {
      throw const JournalTransferException(
        'This journal is too large to export.',
      );
    }
    return bytes;
  }

  /// Reads the edition without decrypting the journal.
  static JournalArchive peek(Uint8List bytes) {
    if (bytes.length > kMaxJournalArchiveBytes) {
      throw const JournalTransferException(
        'This journal file is too large to open.',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const JournalTransferException(
        'This file is not an Unravel journal.',
      );
    }
    if (decoded is! Map) {
      throw const JournalTransferException(
        'This file is not an Unravel journal.',
      );
    }
    final Map<String, Object?> json = decoded.map(
      (dynamic key, dynamic value) =>
          MapEntry(key.toString(), value as Object?),
    );
    if (json['magic'] != magic || json['schema'] != schemaVersion) {
      throw const JournalTransferException(
        'This journal file is from a newer Unravel.',
      );
    }
    final String? edition = json['edition'] as String?;
    final Object? key = json['wrappedKey'];
    final String? archive = json['archive'] as String?;
    if ((edition != fossEdition && edition != storeEdition) ||
        key is! Map ||
        archive == null ||
        archive.isEmpty) {
      throw const JournalTransferException(
        'This file is not an Unravel journal.',
      );
    }
    return JournalArchive(
      edition: edition!,
      wrappedKey: WrappedMasterKeyBundle.fromJson(
        key.map(
          (dynamic entryKey, dynamic value) =>
              MapEntry(entryKey.toString(), value as Object?),
        ),
      ),
      encryptedPayload: archive,
    );
  }

  /// The open-source app only opens a file it exported itself.
  static void assertImportable({
    required String edition,
    required bool isFossBuild,
  }) {
    if (isFossBuild && edition != fossEdition) {
      throw const JournalTransferException(
        'A store journal cannot be opened in the open-source app.',
      );
    }
    if (edition != fossEdition && edition != storeEdition) {
      throw const JournalTransferException(
        'This file is not an Unravel journal.',
      );
    }
  }
}

class JournalTransferException implements Exception {
  const JournalTransferException(this.message);
  final String message;

  @override
  String toString() => message;
}
