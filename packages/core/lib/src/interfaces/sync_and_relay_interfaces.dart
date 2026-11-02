import 'package:meta/meta.dart';

import '../database/tables.dart';

/// Cryptographic entitlement tier verified server-side on Store builds,
/// or `freeOrFossLocal` on F-Droid / air-gapped builds.
enum UnravelEntitlementTier {
  /// Default F-Droid / Free tier: $0.00 cloud cost, zero managed server calls.
  freeOrFossLocal,

  /// 7-day store trial: hard-capped at 15 total AI calls (`trial_ai_calls_remaining`).
  trial,

  /// Active Pro subscription: hard-capped at 20 AI calls/day (`ai_calls_today <= 20`).
  pro,
}

/// Exception thrown when an AI relay returns a payload that violates the
/// strict Stoic dichotomy-of-control JSON schema.
class UnravelSchemaValidationException implements Exception {
  const UnravelSchemaValidationException(this.message);
  final String message;

  @override
  String toString() => 'UnravelSchemaValidationException: $message';
}

/// Result of an AI untangling request with strict Stoic schema fields:
/// - `untangledWorries` (`WITHIN_MY_CONTROL` / `BEYOND_MY_CONTROL`)
/// - `whatFearSays` (Anxiety Projection)
/// - `groundedTruth` (Calibrated Reality)
/// - `physicalAnchor` (Somatic / Grounding Anchor)
@immutable
class UntangledKnotSuggestion {
  const UntangledKnotSuggestion({
    required this.eventTitle,
    required this.numberedWorries,
    required this.groundingAnchor,
    this.whatFearSays = '“Any silence means they think I’m unqualified.”',
    this.groundedTruth =
        'Thoughtful pauses show composure. Nobody expects instant answers.',
    this.untangledWorries = const <UnraveledWorryItem>[],
  });

  final String eventTitle;
  final List<String> numberedWorries;
  final String groundingAnchor;
  final String whatFearSays;
  final String groundedTruth;
  final List<UnraveledWorryItem> untangledWorries;

  /// Alias matching the strict relay schema key `physicalAnchor`.
  String get physicalAnchor => groundingAnchor;

  /// Parses and strictly validates a JSON response from `unravel-relay` or
  /// a local BYOK/Ollama model against the Stoic dichotomy-of-control schema.
  factory UntangledKnotSuggestion.fromValidatedJson(
    Map<String, Object?> json,
  ) {
    final String eventTitle =
        ((json['eventTitle'] as String?) ?? 'Upcoming Moment').trim();
    final String whatFearSays = ((json['whatFearSays'] as String?) ??
            '“Any silence means they think I’m unqualified.”')
        .trim();
    final String groundedTruth = ((json['groundedTruth'] as String?) ??
            'Thoughtful pauses show composure. Nobody expects instant answers.')
        .trim();
    final String physicalAnchor = ((json['physicalAnchor'] as String?) ??
            (json['groundingAnchor'] as String?) ??
            '')
        .trim();

    if (eventTitle.isEmpty ||
        whatFearSays.isEmpty ||
        groundedTruth.isEmpty ||
        physicalAnchor.isEmpty) {
      throw const UnravelSchemaValidationException(
        'Missing required top-level Stoic schema fields (eventTitle, whatFearSays, groundedTruth, physicalAnchor).',
      );
    }

    final List<UnraveledWorryItem> parsedWorries = <UnraveledWorryItem>[];
    final Object? rawUntangled = json['untangledWorries'];
    if (rawUntangled is List && rawUntangled.isNotEmpty) {
      for (int i = 0; i < rawUntangled.length; i++) {
        final Object? item = rawUntangled[i];
        if (item is! Map) {
          throw const UnravelSchemaValidationException(
            'Each item in untangledWorries must be a JSON object.',
          );
        }
        final Map<String, Object?> row = <String, Object?>{
          for (final MapEntry<dynamic, dynamic> entry
              in Map<dynamic, dynamic>.from(item).entries)
            entry.key.toString(): entry.value as Object?,
        };
        final String? rawScope =
            (row['controlScope'] ?? row['scope']) as String?;
        if (rawScope != 'WITHIN_MY_CONTROL' &&
            rawScope != 'BEYOND_MY_CONTROL') {
          throw UnravelSchemaValidationException(
            'Invalid controlScope "$rawScope": expected WITHIN_MY_CONTROL or BEYOND_MY_CONTROL.',
          );
        }
        final String worryText =
            ((row['worryText'] ?? row['worry'] ?? '') as String).trim();
        if (worryText.isEmpty) {
          throw const UnravelSchemaValidationException(
            'untangledWorries item is missing non-empty worryText.',
          );
        }
        final String actionOrGrounding = ((row['actionOrGrounding'] ??
                row['stoicReframe'] ??
                'Focus on the clarity of your own preparation.') as String)
            .trim();
        final String idx =
            ((row['indexNumber'] as String?) ?? (i + 1).toString())
                .padLeft(2, '0');

        parsedWorries.add(
          UnraveledWorryItem(
            indexNumber: idx,
            worryText: worryText,
            controlScope: rawScope == 'WITHIN_MY_CONTROL'
                ? WorryControlScope.withinMyControl
                : WorryControlScope.beyondMyControl,
            actionOrGrounding: actionOrGrounding,
          ),
        );
      }
    } else {
      final Object? legacyRaw = json['numberedWorries'] ?? json['worries'];
      if (legacyRaw is! List || legacyRaw.isEmpty) {
        throw const UnravelSchemaValidationException(
          'Response must include non-empty untangledWorries.',
        );
      }
      final List<String> strings =
          legacyRaw.whereType<String>().toList(growable: false);
      for (int i = 0; i < strings.length; i++) {
        parsedWorries.add(
          UnraveledWorryItem(
            indexNumber: (i + 1).toString().padLeft(2, '0'),
            worryText: strings[i],
            controlScope: i.isEven
                ? WorryControlScope.withinMyControl
                : WorryControlScope.beyondMyControl,
            actionOrGrounding: i.isEven
                ? 'Prepare one concrete step within your reach.'
                : 'Release what belongs to external circumstance.',
          ),
        );
      }
    }

    return UntangledKnotSuggestion(
      eventTitle: eventTitle,
      whatFearSays: whatFearSays,
      groundedTruth: groundedTruth,
      groundingAnchor: physicalAnchor,
      untangledWorries: List<UnraveledWorryItem>.unmodifiable(parsedWorries),
      numberedWorries: parsedWorries
          .map((UnraveledWorryItem w) => w.worryText)
          .toList(growable: false),
    );
  }
}

/// Abstract interface for E2EE Sync (implemented by WebDAV/Nextcloud in `sync_foss`
/// and Managed Supabase Cloud in `sync_store`).
abstract interface class UnravelSyncEngine {
  /// Human-readable mode label for Sanctuary settings (e.g., `Key Held on Device`,
  /// `WebDAV Sovereign Sync`, or `End-to-End Encrypted Cloud`).
  String get modeDisplayName;

  /// Pushes already-encrypted AES-256-GCM envelopes (`<= 16384` bytes each).
  /// Never accepts plaintext.
  Future<void> pushEncryptedEnvelopes(List<String> encryptedPayloads);

  /// Permanently deletes the user's remote cloud account and all synced E2EE
  /// envelopes (Apple App Store Guideline 5.1.1(v) compliance).
  /// On air-gapped FOSS builds, completes immediately with zero network traffic.
  Future<void> deleteCloudAccountAndData();
}

/// Abstract interface for AI Worry Untangling (implemented by BYOK / Local Ollama
/// in `sync_foss` and the entitlement-gated Multi-Model Cloud Relay in `sync_store`).
abstract interface class UnravelAiRelay {
  bool get isConfigured;

  Future<UntangledKnotSuggestion> untanglePreEventKnot({
    required String rawThoughtOrTranscript,
  });
}
