import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unravel_core/unravel_core.dart';
import 'package:unravel_sync_store/unravel_sync_store.dart';

void main() {
  const StoreCloudConfig testConfig = StoreCloudConfig(
    cloudUrl: 'https://project-ref.supabase.co',
    supabasePublishableKey: 'sb_publishable_test_key_123',
  );

  group('StoreSyncEngine — Zero-Bill-Shock Entitlement Gate & E2EE Sync', () {
    test(r'free tier ($0.00 gate) throws StoreEntitlementException before any HTTP call', () async {
      int httpCalls = 0;
      final MockClient mockClient = MockClient((http.Request request) async {
        httpCalls += 1;
        return http.Response('', 200);
      });

      final StoreSyncEngine freeEngine = StoreSyncEngine(
        config: testConfig,
        tier: UnravelEntitlementTier.freeOrFossLocal,
        userAccessToken: 'jwt_free_user',
        httpClient: mockClient,
      );

      expect(freeEngine.modeDisplayName, 'Key Held on Device');

      await expectLater(
        freeEngine.pushEncryptedEnvelopes(<String>['v1:nonce:ct:mac']),
        throwsA(isA<StoreEntitlementException>()),
      );

      expect(httpCalls, 0);
    });

    test('rejects payload >16,384 UTF-8 bytes with UnravelCryptoException before any HTTP call', () async {
      int httpCalls = 0;
      final MockClient mockClient = MockClient((http.Request request) async {
        httpCalls += 1;
        return http.Response('', 201);
      });

      final StoreSyncEngine proEngine = StoreSyncEngine(
        config: testConfig,
        tier: UnravelEntitlementTier.pro,
        userAccessToken: 'jwt_pro_user',
        httpClient: mockClient,
      );

      final String oversizedEnvelope = 'x' * (kMaxEncryptedPayloadBytes + 1);

      await expectLater(
        proEngine.pushEncryptedEnvelopes(<String>[oversizedEnvelope]),
        throwsA(isA<UnravelCryptoException>()),
      );

      expect(httpCalls, 0);
    });

    test('trial and pro tiers POST encrypted envelopes and invoke delete_my_account RPC', () async {
      http.Request? capturedSyncPost;
      http.Request? capturedDeleteRpc;

      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/rest/v1/encrypted_journal_envelopes')) {
          capturedSyncPost = request;
          return http.Response('', 201);
        }
        if (request.url.path.endsWith('/rest/v1/rpc/delete_my_account')) {
          capturedDeleteRpc = request;
          return http.Response('', 204);
        }
        return http.Response('Not Found', 404);
      });

      final StoreSyncEngine trialEngine = StoreSyncEngine(
        config: testConfig,
        tier: UnravelEntitlementTier.trial,
        userAccessToken: 'jwt_trial_token',
        httpClient: mockClient,
      );

      expect(trialEngine.modeDisplayName, 'End-to-End Encrypted Cloud');

      await trialEngine.pushEncryptedEnvelopes(<String>['v1:nonce1:ct1:mac1']);
      expect(capturedSyncPost, isNotNull);
      expect(capturedSyncPost!.method, 'POST');
      expect(capturedSyncPost!.headers['apikey'], 'sb_publishable_test_key_123');
      expect(capturedSyncPost!.headers['Authorization'], 'Bearer jwt_trial_token');

      final List<Object?> rows = jsonDecode(capturedSyncPost!.body) as List<Object?>;
      expect(rows.length, 1);
      final Map<String, Object?> firstRow = rows.first! as Map<String, Object?>;
      expect(firstRow['encrypted_payload'], 'v1:nonce1:ct1:mac1');
      expect(firstRow['record_type'], 'open_thread');

      await trialEngine.deleteCloudAccountAndData();
      expect(capturedDeleteRpc, isNotNull);
      expect(capturedDeleteRpc!.method, 'POST');
      expect(capturedDeleteRpc!.url.toString(),
          'https://project-ref.supabase.co/rest/v1/rpc/delete_my_account');
      expect(capturedDeleteRpc!.headers['Authorization'], 'Bearer jwt_trial_token');
    });
  });

  group('StoreCloudAiRelay — Entitlement Gate, Trial/Pro Quota Caps & Payload Size', () {
    test('free tier throws StoreEntitlementException before any HTTP call', () async {
      int httpCalls = 0;
      final MockClient mockClient = MockClient((http.Request request) async {
        httpCalls += 1;
        return http.Response('', 200);
      });

      final StoreCloudAiRelay freeRelay = StoreCloudAiRelay(
        config: testConfig,
        tier: UnravelEntitlementTier.freeOrFossLocal,
        userAccessToken: 'jwt_free_user',
        httpClient: mockClient,
      );

      expect(freeRelay.isConfigured, isFalse);

      await expectLater(
        freeRelay.untanglePreEventKnot(
          rawThoughtOrTranscript: 'Worried about upcoming presentation.',
        ),
        throwsA(isA<StoreEntitlementException>()),
      );

      expect(httpCalls, 0);
    });

    test('enforces 15-call trial cap, 20/day pro cap, and 16,384-byte reflection cap', () async {
      int httpCalls = 0;
      final MockClient mockClient = MockClient((http.Request request) async {
        httpCalls += 1;
        return http.Response(
          jsonEncode(<String, Object>{
            'eventTitle': 'Product Design Interview',
            'numberedWorries': <String>[
              'System architecture trade-offs.',
              'Internal candidate preference.',
            ],
            'groundingAnchor': 'Pause for one slow breath before speaking.',
          }),
          200,
        );
      });

      // Trial user with 1 call remaining succeeds once, then blocks on the 2nd call
      final StoreCloudAiRelay trialRelay = StoreCloudAiRelay(
        config: testConfig,
        tier: UnravelEntitlementTier.trial,
        userAccessToken: 'jwt_trial_user',
        trialAiCallsRemaining: 1,
        httpClient: mockClient,
      );

      final UntangledKnotSuggestion suggestion =
          await trialRelay.untanglePreEventKnot(
        rawThoughtOrTranscript: 'Product design interview tomorrow morning.',
      );
      expect(suggestion.eventTitle, 'Product Design Interview');
      expect(trialRelay.trialAiCallsRemaining, 0);
      expect(httpCalls, 1);

      // Next call is blocked client-side before touching network
      await expectLater(
        trialRelay.untanglePreEventKnot(
          rawThoughtOrTranscript: 'Another reflection.',
        ),
        throwsA(isA<StoreEntitlementException>()),
      );
      expect(httpCalls, 1);

      // Pro user at daily cap (20) is blocked before touching network
      final StoreCloudAiRelay exhaustedProRelay = StoreCloudAiRelay(
        config: testConfig,
        tier: UnravelEntitlementTier.pro,
        userAccessToken: 'jwt_pro_user',
        aiCallsToday: kProDailyAiCallCap,
        httpClient: mockClient,
      );
      await expectLater(
        exhaustedProRelay.untanglePreEventKnot(
          rawThoughtOrTranscript: 'Over daily pro cap.',
        ),
        throwsA(isA<StoreEntitlementException>()),
      );
      expect(httpCalls, 1);

      // Oversized reflection (>16,384 bytes) is blocked before touching network
      final StoreCloudAiRelay activeProRelay = StoreCloudAiRelay(
        config: testConfig,
        tier: UnravelEntitlementTier.pro,
        userAccessToken: 'jwt_pro_user',
        aiCallsToday: 5,
        httpClient: mockClient,
      );
      await expectLater(
        activeProRelay.untanglePreEventKnot(
          rawThoughtOrTranscript: 'w' * (kMaxEncryptedPayloadBytes + 1),
        ),
        throwsA(isA<StoreEntitlementException>()),
      );
      expect(httpCalls, 1);
    });
  });
}
