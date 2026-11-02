import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unravel_core/unravel_core.dart';
import 'package:unravel_sync_foss/unravel_sync_foss.dart';

void main() {
  group('FossSyncEngine — Air-Gapped, HTTPS & WebDAV Invariants', () {
    test('air-gapped default mode makes zero network calls on push and delete', () async {
      int httpCalls = 0;
      final MockClient mockClient = MockClient((http.Request request) async {
        httpCalls += 1;
        return http.Response('', 200);
      });

      final FossSyncEngine engine = FossSyncEngine(httpClient: mockClient);

      expect(engine.modeDisplayName, 'Key Held on Device');

      await engine.pushEncryptedEnvelopes(<String>['v1:nonce:ciphertext:mac']);
      await engine.deleteCloudAccountAndData();

      expect(httpCalls, 0);
    });

    test('rejects cleartext HTTP remote URLs (http://example.com) before any network call', () async {
      int httpCalls = 0;
      final MockClient mockClient = MockClient((http.Request request) async {
        httpCalls += 1;
        return http.Response('', 200);
      });

      final FossSyncEngine engine = FossSyncEngine(
        webDavEndpoint: Uri.parse('http://example.com/webdav/unravel.json'),
        authHeaderValue: 'Basic dXNlcjpwYXNz',
        httpClient: mockClient,
      );

      expect(engine.modeDisplayName, 'WebDAV Sovereign Sync');

      await expectLater(
        engine.pushEncryptedEnvelopes(<String>['v1:nonce:ct:mac']),
        throwsA(isA<FossSyncException>()),
      );

      await expectLater(
        engine.deleteCloudAccountAndData(),
        throwsA(isA<FossSyncException>()),
      );

      expect(httpCalls, 0);
    });

    test('allows loopback HTTP (http://localhost and http://127.0.0.1) and HTTPS endpoints', () async {
      final List<Uri> requestedUris = <Uri>[];
      final MockClient mockClient = MockClient((http.Request request) async {
        requestedUris.add(request.url);
        return http.Response('', 204);
      });

      final List<Uri> validEndpoints = <Uri>[
        Uri.parse('http://localhost:8080/webdav/vault.json'),
        Uri.parse('http://127.0.0.1:8080/webdav/vault.json'),
        Uri.parse('https://nextcloud.example.org/remote.php/dav/files/user/unravel.json'),
      ];

      for (final Uri uri in validEndpoints) {
        final FossSyncEngine engine = FossSyncEngine(
          webDavEndpoint: uri,
          httpClient: mockClient,
        );
        await engine.pushEncryptedEnvelopes(<String>['v1:nonce:ct:mac']);
      }

      expect(requestedUris, equals(validEndpoints));
    });

    test('rejects encrypted payload exceeding 16,384 UTF-8 bytes before any network call', () async {
      int httpCalls = 0;
      final MockClient mockClient = MockClient((http.Request request) async {
        httpCalls += 1;
        return http.Response('', 200);
      });

      final FossSyncEngine engine = FossSyncEngine(
        webDavEndpoint: Uri.parse('https://nextcloud.example.org/unravel.json'),
        httpClient: mockClient,
      );

      // Exactly 16,384 bytes succeeds
      final String exactMaxPayload = 'a' * kMaxEncryptedPayloadBytes;
      await engine.pushEncryptedEnvelopes(<String>[exactMaxPayload]);
      expect(httpCalls, 1);

      // 16,385 bytes throws UnravelCryptoException without firing HTTP request
      final String oversizedPayload = 'a' * (kMaxEncryptedPayloadBytes + 1);
      await expectLater(
        engine.pushEncryptedEnvelopes(<String>[oversizedPayload]),
        throwsA(isA<UnravelCryptoException>()),
      );
      expect(httpCalls, 1);
    });

    test('executes WebDAV PUT and DELETE with Authorization header and schema envelope', () async {
      http.Request? capturedPut;
      http.Request? capturedDelete;

      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.method == 'PUT') {
          capturedPut = request;
          return http.Response('', 201);
        }
        if (request.method == 'DELETE') {
          capturedDelete = request;
          return http.Response('', 204);
        }
        return http.Response('Unexpected method', 405);
      });

      final Uri endpoint =
          Uri.parse('https://nextcloud.example.org/remote.php/dav/files/u/vault.json');
      final FossSyncEngine engine = FossSyncEngine(
        webDavEndpoint: endpoint,
        authHeaderValue: 'Basic dXNlcjpzZWNyZXQ=',
        httpClient: mockClient,
      );

      await engine.pushEncryptedEnvelopes(<String>['v1:n1:c1:m1', 'v1:n2:c2:m2']);
      expect(capturedPut, isNotNull);
      expect(capturedPut!.url, endpoint);
      expect(capturedPut!.headers['Authorization'], 'Basic dXNlcjpzZWNyZXQ=');

      final Map<String, Object?> decodedBody =
          jsonDecode(capturedPut!.body) as Map<String, Object?>;
      expect(decodedBody['schema'], 'unravel.e2ee.v1');
      expect(decodedBody['envelopes'], equals(<String>['v1:n1:c1:m1', 'v1:n2:c2:m2']));

      await engine.deleteCloudAccountAndData();
      expect(capturedDelete, isNotNull);
      expect(capturedDelete!.url, endpoint);
      expect(capturedDelete!.headers['Authorization'], 'Basic dXNlcjpzZWNyZXQ=');
    });
  });

  group('FossByokAiRelay — Local Ollama & Deterministic Stoic Fallback', () {
    test('uses deterministic offline Stoic fallback when unconfigured or network fails', () async {
      final FossByokAiRelay unconfiguredRelay = FossByokAiRelay();
      expect(unconfiguredRelay.isConfigured, isFalse);

      final UntangledKnotSuggestion suggestion =
          await unconfiguredRelay.untanglePreEventKnot(
        rawThoughtOrTranscript:
            'I might freeze during the architecture review. What if the latency numbers look bad?',
      );

      expect(suggestion.eventTitle, 'Upcoming Moment');
      expect(suggestion.numberedWorries.length, 2);
      expect(suggestion.groundingAnchor, isNotEmpty);
    });

    test('parses structured JSON from local Ollama / BYOK endpoint when configured', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer sk-local-key');
        return http.Response(
          jsonEncode(<String, Object>{
            'eventTitle': 'System Design Deep Dive',
            'worries': <String>[
              'Defending the SQLite local-first schema.',
              'Explaining Argon2id memory parameters.',
            ],
            'groundingAnchor': 'Simplicity and preparation speak for themselves.',
          }),
          200,
        );
      });

      final FossByokAiRelay relay = FossByokAiRelay(
        endpointUri: Uri.parse('http://localhost:11434/api/generate'),
        apiKey: 'sk-local-key',
        httpClient: mockClient,
      );

      expect(relay.isConfigured, isTrue);
      final UntangledKnotSuggestion result = await relay.untanglePreEventKnot(
        rawThoughtOrTranscript: 'Worried about SQLite and Argon2id questions.',
      );

      expect(result.eventTitle, 'System Design Deep Dive');
      expect(result.numberedWorries.length, 2);
      expect(result.groundingAnchor, 'Simplicity and preparation speak for themselves.');
    });

    test('fails over automatically from primary model (HTTP 429/503) to fallback model', () async {
      final List<String> attemptedModels = <String>[];
      final MockClient mockClient = MockClient((http.Request request) async {
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        final String model = body['model']! as String;
        attemptedModels.add(model);

        if (model == 'llama3.2') {
          return http.Response('Rate limit exceeded', 429);
        }

        return http.Response.bytes(
          utf8.encode(
            jsonEncode(<String, Object>{
              'eventTitle': 'Board Presentation',
              'whatFearSays': '"One tough question will derail the pitch."',
              'groundedTruth':
                  'Questions are signs of engagement, not hostility.',
              'physicalAnchor': 'Exhale slowly before answering.',
              'untangledWorries': <Object>[
                <String, Object>{
                  'indexNumber': '01',
                  'worryText': 'Clarifying the Q4 unit economics.',
                  'controlScope': 'WITHIN_MY_CONTROL',
                  'actionOrGrounding': 'Bring the one-page cost breakdown.',
                },
                <String, Object>{
                  'indexNumber': '02',
                  'worryText': 'Macroeconomic budget freezes.',
                  'controlScope': 'BEYOND_MY_CONTROL',
                  'actionOrGrounding':
                      'Focus only on the clarity of your proposal.',
                },
              ],
            }),
          ),
          200,
          headers: const <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      });

      final FossByokAiRelay relay = FossByokAiRelay(
        endpointUri: Uri.parse('http://localhost:11434/api/generate'),
        modelName: 'llama3.2',
        fallbackModelName: 'qwen2.5:3b',
        httpClient: mockClient,
      );

      final UntangledKnotSuggestion result = await relay.untanglePreEventKnot(
        rawThoughtOrTranscript: 'Anxious about the board presentation tomorrow.',
      );

      expect(attemptedModels, equals(<String>['llama3.2', 'qwen2.5:3b']));
      expect(result.eventTitle, 'Board Presentation');
      expect(result.untangledWorries.length, 2);
      expect(
        result.untangledWorries.first.controlScope,
        WorryControlScope.withinMyControl,
      );
      expect(
        result.untangledWorries.last.controlScope,
        WorryControlScope.beyondMyControl,
      );
    });
  });
}
