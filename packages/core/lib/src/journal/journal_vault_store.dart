import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../crypto/envelope_encryption_service.dart';

/// On-device record that the setup wizard has wrapped the master key.
class JournalVaultRecord {
  const JournalVaultRecord({
    required this.setupComplete,
    required this.wrappedKey,
  });

  final bool setupComplete;
  final WrappedMasterKeyBundle? wrappedKey;

  Map<String, Object?> toJson() => <String, Object?>{
        'setupComplete': setupComplete,
        'wrappedKey': wrappedKey?.toJson(),
      };

  factory JournalVaultRecord.fromJson(Map<String, Object?> json) {
    final Object? key = json['wrappedKey'];
    return JournalVaultRecord(
      setupComplete: json['setupComplete'] == true,
      wrappedKey: key is Map
          ? WrappedMasterKeyBundle.fromJson(
              key.map(
                (dynamic entryKey, dynamic value) =>
                    MapEntry(entryKey.toString(), value as Object?),
              ),
            )
          : null,
    );
  }
}

/// Where the wrapped master key and the setup flag live.
abstract class JournalVaultStore {
  Future<JournalVaultRecord?> read();
  Future<void> write(JournalVaultRecord record);
  Future<void> clear();
}

/// In-memory vault used by tests.
class MemoryJournalVaultStore implements JournalVaultStore {
  JournalVaultRecord? record;

  @override
  Future<JournalVaultRecord?> read() async => record;

  @override
  Future<void> write(JournalVaultRecord record) async {
    this.record = record;
  }

  @override
  Future<void> clear() async {
    record = null;
  }
}

/// File vault for a real install. The passphrase is never written.
class FileJournalVaultStore implements JournalVaultStore {
  Future<File> _file() async {
    final Directory dir = await getApplicationSupportDirectory();
    return File('${dir.path}/unravel_vault.json');
  }

  @override
  Future<JournalVaultRecord?> read() async {
    final File file = await _file();
    if (!file.existsSync()) {
      return null;
    }
    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      return null;
    }
    return JournalVaultRecord.fromJson(
      decoded.map(
        (dynamic key, dynamic value) =>
            MapEntry(key.toString(), value as Object?),
      ),
    );
  }

  @override
  Future<void> write(JournalVaultRecord record) async {
    final File file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(record.toJson()));
  }

  @override
  Future<void> clear() async {
    final File file = await _file();
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
