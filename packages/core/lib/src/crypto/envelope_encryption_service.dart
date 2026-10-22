import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart';

/// Maximum serialized byte length for any encrypted column or sync payload,
/// matching the Postgres constraint `CHECK (octet_length(encrypted_payload) <= 16384)`.
const int kMaxEncryptedPayloadBytes = 16384;

/// Exception thrown when an E2EE operation violates security or size invariants.
class UnravelCryptoException implements Exception {
  const UnravelCryptoException(this.message);
  final String message;

  @override
  String toString() => 'UnravelCryptoException: $message';
}

/// Serialized wrapped Master Data Key (MDK) bundle derived via Argon2id.
/// Safe to store in local preferences or sync metadata; the raw MDK never
/// touches disk unwrapped unless held in OS hardware keystore.
@immutable
class WrappedMasterKeyBundle {
  const WrappedMasterKeyBundle({
    required this.version,
    required this.argon2SaltBase64,
    required this.wrappingNonceBase64,
    required this.wrappedKeyCiphertextBase64,
    required this.wrappingMacBase64,
  });

  final int version;
  final String argon2SaltBase64;
  final String wrappingNonceBase64;
  final String wrappedKeyCiphertextBase64;
  final String wrappingMacBase64;

  Map<String, Object> toJson() => <String, Object>{
        'v': version,
        'salt': argon2SaltBase64,
        'nonce': wrappingNonceBase64,
        'ct': wrappedKeyCiphertextBase64,
        'mac': wrappingMacBase64,
      };

  factory WrappedMasterKeyBundle.fromJson(Map<String, Object?> json) {
    final int? version = json['v'] as int?;
    final String? salt = json['salt'] as String?;
    final String? nonce = json['nonce'] as String?;
    final String? ct = json['ct'] as String?;
    final String? mac = json['mac'] as String?;
    if (version == null ||
        salt == null ||
        nonce == null ||
        ct == null ||
        mac == null) {
      throw const UnravelCryptoException(
        'Malformed WrappedMasterKeyBundle JSON.',
      );
    }
    return WrappedMasterKeyBundle(
      version: version,
      argon2SaltBase64: salt,
      wrappingNonceBase64: nonce,
      wrappedKeyCiphertextBase64: ct,
      wrappingMacBase64: mac,
    );
  }
}

/// Client-side AES-256-GCM Envelope Encryption Service.
///
/// Architecture:
/// 1. A 256-bit Master Data Key (MDK) encrypts all reflection notes, worries,
///    and transcripts on-device using AES-256-GCM with unique 96-bit nonces
///    and 128-bit authentication tags.
/// 2. When wrapped with a user passphrase for cross-device backup, Argon2id
///    (64 MiB memory, 3 iterations, parallelism 2) derives a Key Encryption Key (KEK)
///    that wraps the 256-bit MDK via AES-256-GCM.
/// 3. Every encrypted payload enforces `octet_length <= 16384` bytes on-device
///    before database persistence or cloud relay upload.
class EnvelopeEncryptionService {
  EnvelopeEncryptionService({
    AesGcm? cipher,
    Argon2id? keyDerivation,
  })  : _cipher = cipher ?? AesGcm.with256bits(),
        _kdf = keyDerivation ??
            Argon2id(
              memory: 65536, // 64 MiB
              parallelism: 2,
              iterations: 3,
              hashLength: 32,
            );

  final AesGcm _cipher;
  final Argon2id _kdf;

  static const String _envelopeVersionPrefix = 'v1';

  /// Generates a fresh, cryptographically random 256-bit Master Data Key (MDK).
  Future<SecretKey> generateMasterDataKey() async {
    return _cipher.newSecretKey();
  }

  /// Wraps the [masterDataKey] using a Key Encryption Key (KEK) derived from
  /// [passphrase] via Argon2id.
  Future<WrappedMasterKeyBundle> wrapMasterKey({
    required SecretKey masterDataKey,
    required String passphrase,
  }) async {
    if (passphrase.trim().length < 8) {
      throw const UnravelCryptoException(
        'Passphrase must be at least 8 characters to wrap Master Data Key.',
      );
    }
    final List<int> salt = SecretKeyData.random(length: 16).bytes;
    final SecretKey kek = await _kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    final List<int> rawMdkBytes = await masterDataKey.extractBytes();
    final List<int> wrappingNonce = _cipher.newNonce();

    final SecretBox wrappedBox = await _cipher.encrypt(
      rawMdkBytes,
      secretKey: kek,
      nonce: wrappingNonce,
      aad: utf8.encode('unravel-mdk-wrap-v1'),
    );

    return WrappedMasterKeyBundle(
      version: 1,
      argon2SaltBase64: base64Encode(salt),
      wrappingNonceBase64: base64Encode(wrappedBox.nonce),
      wrappedKeyCiphertextBase64: base64Encode(wrappedBox.cipherText),
      wrappingMacBase64: base64Encode(wrappedBox.mac.bytes),
    );
  }

  /// Unwraps a [WrappedMasterKeyBundle] using the user's [passphrase] and Argon2id.
  Future<SecretKey> unwrapMasterKey({
    required WrappedMasterKeyBundle bundle,
    required String passphrase,
  }) async {
    final List<int> salt = base64Decode(bundle.argon2SaltBase64);
    final SecretKey kek = await _kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    final SecretBox box = SecretBox(
      base64Decode(bundle.wrappedKeyCiphertextBase64),
      nonce: base64Decode(bundle.wrappingNonceBase64),
      mac: Mac(base64Decode(bundle.wrappingMacBase64)),
    );

    try {
      final List<int> rawMdkBytes = await _cipher.decrypt(
        box,
        secretKey: kek,
        aad: utf8.encode('unravel-mdk-wrap-v1'),
      );
      return SecretKey(rawMdkBytes);
    } on SecretBoxAuthenticationError {
      throw const UnravelCryptoException(
        'Failed to unlock Master Data Key: invalid passphrase or corrupted key bundle.',
      );
    }
  }

  /// Encrypts [plaintext] with AES-256-GCM using [masterDataKey] and binds it
  /// to [associatedRecordId] (AAD) so ciphertext cannot be transplanted across rows.
  ///
  /// Returns a compact envelope string: `v1:<base64Nonce>:<base64Ciphertext>:<base64Mac>`
  /// guaranteed to be `<= 16384` UTF-8 bytes.
  Future<String> encryptText({
    required String plaintext,
    required SecretKey masterDataKey,
    required String associatedRecordId,
  }) async {
    if (plaintext.trim().isEmpty) {
      throw const UnravelCryptoException(
        'Refusing to encrypt empty plaintext payload.',
      );
    }
    if (associatedRecordId.trim().isEmpty) {
      throw const UnravelCryptoException(
        'Associated record ID (AAD) must not be empty.',
      );
    }

    final Uint8List plaintextBytes = utf8.encoder.convert(plaintext);
    final List<int> nonce = _cipher.newNonce();
    final List<int> aad = utf8.encode(associatedRecordId);

    final SecretBox secretBox = await _cipher.encrypt(
      plaintextBytes,
      secretKey: masterDataKey,
      nonce: nonce,
      aad: aad,
    );

    final String serialized = '$_envelopeVersionPrefix:'
        '${base64Encode(secretBox.nonce)}:'
        '${base64Encode(secretBox.cipherText)}:'
        '${base64Encode(secretBox.mac.bytes)}';

    final int byteLength = utf8.encode(serialized).length;
    if (byteLength > kMaxEncryptedPayloadBytes) {
      throw UnravelCryptoException(
        'Encrypted payload ($byteLength bytes) exceeds hard cap of '
        '$kMaxEncryptedPayloadBytes bytes.',
      );
    }

    return serialized;
  }

  /// Decrypts an AES-256-GCM envelope produced by [encryptText] and verifies
  /// both the 128-bit GCM authentication tag and [associatedRecordId] (AAD).
  Future<String> decryptText({
    required String encryptedEnvelope,
    required SecretKey masterDataKey,
    required String associatedRecordId,
  }) async {
    final int byteLength = utf8.encode(encryptedEnvelope).length;
    if (byteLength > kMaxEncryptedPayloadBytes) {
      throw UnravelCryptoException(
        'Refusing to decrypt oversized payload ($byteLength bytes > $kMaxEncryptedPayloadBytes).',
      );
    }

    final List<String> parts = encryptedEnvelope.split(':');
    if (parts.length != 4 || parts[0] != _envelopeVersionPrefix) {
      throw const UnravelCryptoException(
        'Unsupported or malformed AES-256-GCM envelope format.',
      );
    }

    final List<int> nonce = base64Decode(parts[1]);
    final List<int> cipherText = base64Decode(parts[2]);
    final List<int> macBytes = base64Decode(parts[3]);

    final SecretBox secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    try {
      final List<int> clearBytes = await _cipher.decrypt(
        secretBox,
        secretKey: masterDataKey,
        aad: utf8.encode(associatedRecordId),
      );
      return utf8.decode(clearBytes);
    } on SecretBoxAuthenticationError {
      throw const UnravelCryptoException(
        'AES-256-GCM authentication tag verification failed.',
      );
    }
  }
}
