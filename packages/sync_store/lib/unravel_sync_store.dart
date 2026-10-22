library unravel_sync_store;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:unravel_core/unravel_core.dart';

/// Hard abuse caps enforced on both client and server (`unravel-relay`).
const int kTrialTotalAiCallCap = 15;
const int kProDailyAiCallCap = 20;

/// Exception thrown when an entitlement or quota gate blocks a cloud operation.
class StoreEntitlementException implements Exception {
  const StoreEntitlementException(this.message);
  final String message;

  @override
  String toString() => 'StoreEntitlementException: $message';
}

/// Compile-time configuration injected strictly via `--dart-define` in `app.unravel.store`.
class StoreCloudConfig {
  const StoreCloudConfig({
    required this.cloudUrl,
    required this.supabasePublishableKey,
  });

  final String cloudUrl;
  final String supabasePublishableKey;

  bool get isConfigured =>
      cloudUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  Uri get relayFunctionUri =>
      Uri.parse('$cloudUrl/functions/v1/unravel-relay');

  Uri get encryptedSyncRestUri =>
      Uri.parse('$cloudUrl/rest/v1/encrypted_journal_envelopes');

  Uri get deleteMyAccountRpcUri =>
      Uri.parse('$cloudUrl/rest/v1/rpc/delete_my_account');
}

/// Entitlement-gated E2EE Cloud Sync Engine for App Store & Play Store builds.
///
/// Zero-Bill-Shock Guarantees:
/// - Free tier users (`UnravelEntitlementTier.freeOrFossLocal`) cost $0.00 and
///   never touch managed Supabase tables.
/// - Every synced payload is verified to be `<= 16384` UTF-8 bytes before upload.
class StoreSyncEngine implements UnravelSyncEngine {
  StoreSyncEngine({
    required this.config,
    required this.tier,
    this.userAccessToken,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final StoreCloudConfig config;
  final UnravelEntitlementTier tier;
  final String? userAccessToken;
  final http.Client _httpClient;

  bool get _hasCloudEntitlement =>
      tier == UnravelEntitlementTier.trial ||
      tier == UnravelEntitlementTier.pro;

  @override
  String get modeDisplayName => _hasCloudEntitlement
      ? 'End-to-End Encrypted Cloud'
      : 'Key Held on Device';

  @override
  Future<void> pushEncryptedEnvelopes(
    List<String> encryptedPayloads, {
    String recordType = 'open_thread',
  }) async {
    if (!_hasCloudEntitlement) {
      throw const StoreEntitlementException(
        'Cloud Sync requires an active 7-day Trial or Pro entitlement.',
      );
    }
    if (!config.isConfigured ||
        userAccessToken == null ||
        userAccessToken!.isEmpty) {
      throw const StoreEntitlementException(
        'Cloud Sync is not configured or missing session token.',
      );
    }

    for (final String payload in encryptedPayloads) {
      final int byteLength = utf8.encode(payload).length;
      if (byteLength > kMaxEncryptedPayloadBytes) {
        throw UnravelCryptoException(
          'Encrypted payload ($byteLength bytes) exceeds '
          '$kMaxEncryptedPayloadBytes-byte Postgres CHECK constraint.',
        );
      }
    }

    final List<Map<String, Object>> rows = encryptedPayloads
        .map(
          (String envelope) => <String, Object>{
            'record_type': recordType,
            'encrypted_payload': envelope,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        )
        .toList(growable: false);

    final http.Response response = await _httpClient.post(
      config.encryptedSyncRestUri,
      headers: <String, String>{
        'apikey': config.supabasePublishableKey,
        'Authorization': 'Bearer $userAccessToken',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates',
      },
      body: jsonEncode(rows),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StoreEntitlementException(
        'Encrypted cloud sync rejected with HTTP ${response.statusCode}.',
      );
    }
  }

  @override
  Future<void> deleteCloudAccountAndData() async {
    if (!config.isConfigured ||
        userAccessToken == null ||
        userAccessToken!.isEmpty) {
      // No active cloud account session to delete on server.
      return;
    }

    final http.Response response = await _httpClient.post(
      config.deleteMyAccountRpcUri,
      headers: <String, String>{
        'apikey': config.supabasePublishableKey,
        'Authorization': 'Bearer $userAccessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(const <String, Object>{}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StoreEntitlementException(
        'delete_my_account() RPC failed with HTTP ${response.statusCode}.',
      );
    }
  }
}

/// Entitlement-gated Multi-Model AI Relay (`POST /functions/v1/unravel-relay`).
///
/// Enforces:
/// - `tier IN ('trial', 'pro')`
/// - `trial_ai_calls_remaining` (max 15 total calls during 7-day trial)
/// - `ai_calls_today <= 20` (max 20 calls/day for Pro users)
class StoreCloudAiRelay implements UnravelAiRelay {
  StoreCloudAiRelay({
    required this.config,
    required this.tier,
    this.userAccessToken,
    this.trialAiCallsRemaining = kTrialTotalAiCallCap,
    this.aiCallsToday = 0,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final StoreCloudConfig config;
  final UnravelEntitlementTier tier;
  final String? userAccessToken;
  int trialAiCallsRemaining;
  int aiCallsToday;
  final http.Client _httpClient;

  @override
  bool get isConfigured =>
      config.isConfigured &&
      (tier == UnravelEntitlementTier.trial ||
          tier == UnravelEntitlementTier.pro) &&
      userAccessToken != null &&
      userAccessToken!.isNotEmpty;

  @override
  Future<UntangledKnotSuggestion> untanglePreEventKnot({
    required String rawThoughtOrTranscript,
  }) async {
    if (tier == UnravelEntitlementTier.freeOrFossLocal) {
      throw const StoreEntitlementException(
        'Cloud AI Relay requires an active 7-day Trial or Pro entitlement.',
      );
    }
    if (tier == UnravelEntitlementTier.trial && trialAiCallsRemaining <= 0) {
      throw const StoreEntitlementException(
        '7-day Trial cap of 15 AI untangling calls reached.',
      );
    }
    if (tier == UnravelEntitlementTier.pro &&
        aiCallsToday >= kProDailyAiCallCap) {
      throw const StoreEntitlementException(
        'Daily Pro cap of 20 AI untangling calls reached.',
      );
    }
    if (!isConfigured) {
      throw const StoreEntitlementException(
        'Cloud AI Relay is not configured or missing session token.',
      );
    }

    final int byteLength = utf8.encode(rawThoughtOrTranscript).length;
    if (byteLength > kMaxEncryptedPayloadBytes) {
      throw const StoreEntitlementException(
        'Reflection text exceeds 16 KiB relay limit.',
      );
    }

    final http.Response response = await _httpClient.post(
      config.relayFunctionUri,
      headers: <String, String>{
        'apikey': config.supabasePublishableKey,
        'Authorization': 'Bearer $userAccessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, Object>{
        'reflection': rawThoughtOrTranscript,
      }),
    );

    if (response.statusCode != 200) {
      throw StoreEntitlementException(
        'unravel-relay returned HTTP ${response.statusCode}.',
      );
    }

    if (tier == UnravelEntitlementTier.trial) {
      trialAiCallsRemaining -= 1;
    } else if (tier == UnravelEntitlementTier.pro) {
      aiCallsToday += 1;
    }

    final Map<String, Object?> data =
        jsonDecode(response.body) as Map<String, Object?>;
    return UntangledKnotSuggestion.fromValidatedJson(data);
  }
}
