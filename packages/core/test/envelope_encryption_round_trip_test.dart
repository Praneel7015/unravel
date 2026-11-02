import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unravel_core/unravel_core.dart';

/// Flips one bit of the base64 field at [index] in a `v1:<nonce>:<ct>:<mac>`
/// envelope, so the result is still well-formed but no longer authentic.
String _flipBitInField(String envelope, int index) {
  final List<String> parts = envelope.split(':');
  final List<int> bytes = base64Decode(parts[index]);
  bytes[0] ^= 0x01;
  parts[index] = base64Encode(bytes);
  return parts.join(':');
}

void main() {
  group('EnvelopeEncryptionService round-trips', () {
    final EnvelopeEncryptionService service = EnvelopeEncryptionService();

    test('round-trips multi-line and non-ASCII plaintext unchanged', () async {
      final SecretKey mdk = await service.generateMasterDataKey();
      const String cleartext = 'Fear said 9.\nLife said 3.\n'
          'Ἐπίκτητος · 平静 · ñandú · 🌿';

      final String envelope = await service.encryptText(
        plaintext: cleartext,
        masterDataKey: mdk,
        associatedRecordId: 'thread_01:worries',
      );

      expect(envelope, isNot(contains('Fear')));
      expect(
        await service.decryptText(
          encryptedEnvelope: envelope,
          masterDataKey: mdk,
          associatedRecordId: 'thread_01:worries',
        ),
        cleartext,
      );
    });

    test('uses a fresh nonce for every encryption of the same plaintext',
        () async {
      final SecretKey mdk = await service.generateMasterDataKey();
      const String cleartext = 'The same worry, written twice.';

      final String first = await service.encryptText(
        plaintext: cleartext,
        masterDataKey: mdk,
        associatedRecordId: 'log_01:notes',
      );
      final String second = await service.encryptText(
        plaintext: cleartext,
        masterDataKey: mdk,
        associatedRecordId: 'log_01:notes',
      );

      expect(first, isNot(second));
      expect(first.split(':')[1], isNot(second.split(':')[1]));
      for (final String envelope in <String>[first, second]) {
        expect(
          await service.decryptText(
            encryptedEnvelope: envelope,
            masterDataKey: mdk,
            associatedRecordId: 'log_01:notes',
          ),
          cleartext,
        );
      }
    });

    test('rejects decryption with a different master data key', () async {
      final SecretKey mdk = await service.generateMasterDataKey();
      final SecretKey otherKey = await service.generateMasterDataKey();

      final String envelope = await service.encryptText(
        plaintext: 'Only this device can read this.',
        masterDataKey: mdk,
        associatedRecordId: 'log_01:notes',
      );

      await expectLater(
        () => service.decryptText(
          encryptedEnvelope: envelope,
          masterDataKey: otherKey,
          associatedRecordId: 'log_01:notes',
        ),
        throwsA(isA<UnravelCryptoException>()),
      );
    });

    test('rejects a flipped bit in the nonce, ciphertext, or tag', () async {
      final SecretKey mdk = await service.generateMasterDataKey();
      final String envelope = await service.encryptText(
        plaintext: 'Tampering must never decrypt silently.',
        masterDataKey: mdk,
        associatedRecordId: 'log_01:notes',
      );

      for (final int field in <int>[1, 2, 3]) {
        await expectLater(
          () => service.decryptText(
            encryptedEnvelope: _flipBitInField(envelope, field),
            masterDataKey: mdk,
            associatedRecordId: 'log_01:notes',
          ),
          throwsA(isA<UnravelCryptoException>()),
          reason: 'field $field was tampered with',
        );
      }
    });

    test('round-trips a journal archive larger than the sync cap', () async {
      final SecretKey mdk = await service.generateMasterDataKey();
      final String archive = jsonEncode(<String, Object>{
        'threads': List<String>.generate(2000, (int i) => 'thread $i'),
      });
      expect(
          utf8.encode(archive).length, greaterThan(kMaxEncryptedPayloadBytes));

      final String envelope = await service.encryptJournalArchive(
        plaintext: archive,
        masterDataKey: mdk,
      );

      expect(
        await service.decryptJournalArchive(
          encryptedEnvelope: envelope,
          masterDataKey: mdk,
        ),
        archive,
      );
    });

    test('keeps archive and record envelopes from being swapped', () async {
      final SecretKey mdk = await service.generateMasterDataKey();
      final String archiveEnvelope = await service.encryptJournalArchive(
        plaintext: 'archive body',
        masterDataKey: mdk,
      );

      await expectLater(
        () => service.decryptText(
          encryptedEnvelope: archiveEnvelope,
          masterDataKey: mdk,
          associatedRecordId: 'log_01:notes',
        ),
        throwsA(isA<UnravelCryptoException>()),
      );
    });
  });

  group('WrappedMasterKeyBundle', () {
    // A light Argon2id keeps this test fast; the production parameters are
    // covered by the wrap/unwrap test in unravel_core_test.dart.
    final EnvelopeEncryptionService service = EnvelopeEncryptionService(
      keyDerivation: Argon2id(
        memory: 256,
        parallelism: 1,
        iterations: 1,
        hashLength: 32,
      ),
    );

    test('survives a JSON round-trip and still unwraps the same key', () async {
      final SecretKey mdk = await service.generateMasterDataKey();
      final WrappedMasterKeyBundle bundle = await service.wrapMasterKey(
        masterDataKey: mdk,
        passphrase: 'moss-on-the-north-side',
      );

      final String json = jsonEncode(bundle.toJson());
      expect(json, isNot(contains('moss-on-the-north-side')));

      final WrappedMasterKeyBundle restored = WrappedMasterKeyBundle.fromJson(
        jsonDecode(json) as Map<String, Object?>,
      );
      final SecretKey unwrapped = await service.unwrapMasterKey(
        bundle: restored,
        passphrase: 'moss-on-the-north-side',
      );

      expect(await unwrapped.extractBytes(), await mdk.extractBytes());
    });

    test('rejects bundle JSON with a missing field', () {
      expect(
        () => WrappedMasterKeyBundle.fromJson(<String, Object?>{
          'v': 1,
          'salt': 'c2FsdA==',
          'nonce': 'bm9uY2U=',
          'ct': 'Y3Q=',
        }),
        throwsA(isA<UnravelCryptoException>()),
      );
    });
  });
}
