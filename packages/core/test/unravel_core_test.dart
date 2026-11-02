import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unravel_core/unravel_core.dart';

class _FakeSyncEngine implements UnravelSyncEngine {
  bool accountDeleted = false;
  final List<String> pushedPayloads = <String>[];

  @override
  String get modeDisplayName => 'Key Held on Device';

  @override
  Future<void> pushEncryptedEnvelopes(List<String> encryptedPayloads) async {
    pushedPayloads.addAll(encryptedPayloads);
  }

  @override
  Future<void> deleteCloudAccountAndData() async {
    accountDeleted = true;
  }
}

void main() {
  group('CircadianResolver exact time-window boundaries & manual overrides',
      () {
    test('verifies exact minute transitions across all 4 Circadian modes', () {
      // 23:00–05:59 -> Midnight Starlight (OLED)
      expect(
        CircadianResolver.resolveForTime(DateTime(2026, 10, 21, 5, 59)),
        CircadianPalette.midnightStarlight,
      );
      // 06:00–10:59 -> Morning Mist
      expect(
        CircadianResolver.resolveForTime(DateTime(2026, 10, 21, 6, 0)),
        CircadianPalette.morningMist,
      );
      expect(
        CircadianResolver.resolveForTime(DateTime(2026, 10, 21, 10, 59)),
        CircadianPalette.morningMist,
      );
      // 11:00–17:29 -> High Sun
      expect(
        CircadianResolver.resolveForTime(DateTime(2026, 10, 21, 11, 0)),
        CircadianPalette.highSun,
      );
      expect(
        CircadianResolver.resolveForTime(DateTime(2026, 10, 21, 17, 29)),
        CircadianPalette.highSun,
      );
      // 17:30–22:59 -> Dusk Pine
      expect(
        CircadianResolver.resolveForTime(DateTime(2026, 10, 21, 17, 30)),
        CircadianPalette.duskPine,
      );
      expect(
        CircadianResolver.resolveForTime(DateTime(2026, 10, 21, 22, 59)),
        CircadianPalette.duskPine,
      );
      // 23:00–06:00 -> Midnight Starlight (OLED)
      expect(
        CircadianResolver.resolveForTime(DateTime(2026, 10, 21, 23, 0)),
        CircadianPalette.midnightStarlight,
      );
      expect(
        CircadianResolver.resolveForTime(DateTime(2026, 10, 21, 0, 0)),
        CircadianPalette.midnightStarlight,
      );
    });

    test('verifies manual palette override vs automatic Circadian mode', () {
      final DateTime middayTime = DateTime(2026, 10, 21, 13, 30);

      // Auto mode follows local time (13:30 -> High Sun)
      expect(
        CircadianResolver.resolvePalette(
          preference: CircadianThemePreference.circadianAuto,
          now: middayTime,
        ),
        CircadianPalette.highSun,
      );

      // Manual overrides ignore local time and return the exact chosen surface
      expect(
        CircadianResolver.resolvePalette(
          preference: CircadianThemePreference.morningMist,
          now: middayTime,
        ),
        CircadianPalette.morningMist,
      );
      expect(
        CircadianResolver.resolvePalette(
          preference: CircadianThemePreference.highSun,
          now: DateTime(2026, 10, 21, 2, 0),
        ),
        CircadianPalette.highSun,
      );
      expect(
        CircadianResolver.resolvePalette(
          preference: CircadianThemePreference.duskPine,
          now: middayTime,
        ),
        CircadianPalette.duskPine,
      );
      expect(
        CircadianResolver.resolvePalette(
          preference: CircadianThemePreference.midnightStarlight,
          now: middayTime,
        ),
        CircadianPalette.midnightStarlight,
      );
    });

    test('computes nextTransitionTime accurately across all 4 windows', () {
      expect(
        CircadianResolver.nextTransitionTime(DateTime(2026, 10, 21, 3, 15)),
        DateTime(2026, 10, 21, 6, 0),
      );
      expect(
        CircadianResolver.nextTransitionTime(DateTime(2026, 10, 21, 7, 15)),
        DateTime(2026, 10, 21, 11, 0),
      );
      expect(
        CircadianResolver.nextTransitionTime(DateTime(2026, 10, 21, 14, 0)),
        DateTime(2026, 10, 21, 17, 30),
      );
      expect(
        CircadianResolver.nextTransitionTime(DateTime(2026, 10, 21, 19, 45)),
        DateTime(2026, 10, 21, 23, 0),
      );
      expect(
        CircadianResolver.nextTransitionTime(DateTime(2026, 10, 21, 23, 30)),
        DateTime(2026, 10, 22, 6, 0),
      );
    });

    test('formats lower Circadian sun pill label cleanly across periods', () {
      expect(
        CircadianResolver.formatSunPillLabel(DateTime(2026, 10, 21, 7, 15)),
        'Dawn · 7:15 AM',
      );
      expect(
        CircadianResolver.formatSunPillLabel(DateTime(2026, 10, 21, 12, 5)),
        'Midday · 12:05 PM',
      );
      expect(
        CircadianResolver.formatSunPillLabel(DateTime(2026, 10, 21, 18, 45)),
        'Dusk · 6:45 PM',
      );
      expect(
        CircadianResolver.formatSunPillLabel(DateTime(2026, 10, 21, 0, 0)),
        'Starlight · 12:00 AM',
      );
    });
  });

  group('EnvelopeEncryptionService (AES-256-GCM + Argon2id)', () {
    final EnvelopeEncryptionService service = EnvelopeEncryptionService();

    test('round-trips encryption/decryption and rejects AAD tampering',
        () async {
      final SecretKey mdk = await service.generateMasterDataKey();
      const String cleartext =
          'They actually appreciated that I flagged the latency trade-off early.';

      final String ciphertext = await service.encryptText(
        plaintext: cleartext,
        masterDataKey: mdk,
        associatedRecordId: 'log_01:notes',
      );

      final String decrypted = await service.decryptText(
        encryptedEnvelope: ciphertext,
        masterDataKey: mdk,
        associatedRecordId: 'log_01:notes',
      );
      expect(decrypted, cleartext);

      // Tampering with AAD (transplanting ciphertext to a different record) must throw
      await expectLater(
        () => service.decryptText(
          encryptedEnvelope: ciphertext,
          masterDataKey: mdk,
          associatedRecordId: 'log_02:notes',
        ),
        throwsA(isA<UnravelCryptoException>()),
      );
    });

    test('rejects empty plaintext and malformed envelope formats (v2:...)',
        () async {
      final SecretKey mdk = await service.generateMasterDataKey();

      await expectLater(
        () => service.encryptText(
          plaintext: '   ',
          masterDataKey: mdk,
          associatedRecordId: 'log_01:notes',
        ),
        throwsA(isA<UnravelCryptoException>()),
      );

      await expectLater(
        () => service.decryptText(
          encryptedEnvelope: 'v2:bm9uY2U=:Y2lwaGVydGV4dA==:bWFj',
          masterDataKey: mdk,
          associatedRecordId: 'log_01:notes',
        ),
        throwsA(isA<UnravelCryptoException>()),
      );

      await expectLater(
        () => service.decryptText(
          encryptedEnvelope: 'v1:only_two_parts',
          masterDataKey: mdk,
          associatedRecordId: 'log_01:notes',
        ),
        throwsA(isA<UnravelCryptoException>()),
      );
    });

    test(
        'wraps and unwraps Master Data Key via Argon2id and rejects wrong passphrase',
        () async {
      final SecretKey originalKey = await service.generateMasterDataKey();
      final WrappedMasterKeyBundle bundle = await service.wrapMasterKey(
        masterDataKey: originalKey,
        passphrase: 'quiet-forest-birch-river',
      );

      final SecretKey unwrappedKey = await service.unwrapMasterKey(
        bundle: bundle,
        passphrase: 'quiet-forest-birch-river',
      );
      expect(
        await unwrappedKey.extractBytes(),
        await originalKey.extractBytes(),
      );

      await expectLater(
        () => service.unwrapMasterKey(
          bundle: bundle,
          passphrase: 'wrong-passphrase-attempt',
        ),
        throwsA(isA<UnravelCryptoException>()),
      );
    });

    test('enforces 16384-byte hard cap on encrypted payloads vs valid payload',
        () async {
      final SecretKey mdk = await service.generateMasterDataKey();

      // Valid moderately sized payload (~4 KiB) succeeds cleanly
      final String validPayload = 'Quiet reflection note. ' * 160;
      final String validEnvelope = await service.encryptText(
        plaintext: validPayload,
        masterDataKey: mdk,
        associatedRecordId: 'log_valid:notes',
      );
      expect(
          validEnvelope.length, lessThanOrEqualTo(kMaxEncryptedPayloadBytes));

      // Exact 16384-byte raw plaintext expands beyond 16384 bytes once base64 + GCM tag are added
      final String boundaryPlaintext = 'A' * kMaxEncryptedPayloadBytes;
      await expectLater(
        () => service.encryptText(
          plaintext: boundaryPlaintext,
          masterDataKey: mdk,
          associatedRecordId: 'log_oversized:notes',
        ),
        throwsA(isA<UnravelCryptoException>()),
      );

      // Oversized envelope passed to decryptText is also rejected before base64 decoding
      final String oversizedEnvelope =
          'v1:aa:${'B' * kMaxEncryptedPayloadBytes}:cc';
      await expectLater(
        () => service.decryptText(
          encryptedEnvelope: oversizedEnvelope,
          masterDataKey: mdk,
          associatedRecordId: 'log_oversized:notes',
        ),
        throwsA(isA<UnravelCryptoException>()),
      );
    });
  });

  group(
      'UnravelJournalController lifecycle & notification scheduling variabilities',
      () {
    test(
      'creates OpenThread with scheduleNotification true vs false, completes After a Moment check-in, and purges vault',
      () async {
        final _FakeSyncEngine fakeSync = _FakeSyncEngine();
        final UnravelJournalController controller = UnravelJournalController(
          syncEngine: fakeSync,
          isFossBuild: true,
          initialThemePreference: CircadianThemePreference.duskPine,
        );

        // 1. Create an OpenThread with scheduleNotification: true
        final OpenThreadRecord scheduledThread =
            await controller.createOpenThread(
          eventTitle: 'Architecture Trade-off Review',
          worries: const <UnraveledWorryItem>[
            UnraveledWorryItem(
              indexNumber: '01',
              worryText: 'Latency spike under burst load.',
              controlScope: WorryControlScope.withinMyControl,
              actionOrGrounding: 'Prepare flamegraph benchmarks.',
            ),
          ],
          groundingAnchor: 'Breathe slowly before sharing screen.',
          predictedFear: 9,
          eventOccursAt: DateTime(2026, 10, 22, 10, 0),
          scheduleNotification: true,
        );

        expect(
          controller.scheduledNotificationThreadIds
              .contains(scheduledThread.id),
          isTrue,
        );

        // 2. Create an OpenThread with scheduleNotification: false
        final OpenThreadRecord unscheduledThread =
            await controller.createOpenThread(
          eventTitle: 'Quiet Solo Design Sprint',
          worries: const <UnraveledWorryItem>[
            UnraveledWorryItem(
              indexNumber: '01',
              worryText: 'Scope creep on animations.',
            ),
          ],
          groundingAnchor: 'Stick to 1px borders and calm surfaces.',
          predictedFear: 6,
          eventOccursAt: DateTime(2026, 10, 23, 14, 0),
          scheduleNotification: false,
        );

        expect(
          controller.scheduledNotificationThreadIds
              .contains(unscheduledThread.id),
          isFalse,
        );

        // 3. Complete After a Moment check-in for scheduledThread
        final int entriesBefore = controller.perspectiveEntries.length;
        final PerspectiveCurveEntry curveEntry =
            await controller.completeAfterMomentCheckIn(
          threadId: scheduledThread.id,
          actualOutcome: 1,
          reflectionNotes: 'The team loved the benchmark clarity.',
        );

        expect(controller.perspectiveEntries.length, entriesBefore + 1);
        expect(curveEntry.predictedFear, 9);
        expect(curveEntry.actualOutcome, 1);
        expect(
          controller.scheduledNotificationThreadIds
              .contains(scheduledThread.id),
          isFalse,
        );
        expect(
          controller.gentlerThanFearedPercentage,
          inInclusiveRange(70, 95),
        );

        // 4. Purge vault and delete cloud account
        await controller.purgeVaultAndDeleteCloudAccount();
        expect(controller.activeOpenThreads, isEmpty);
        expect(controller.unraveledThreads, isEmpty);
        expect(controller.perspectiveEntries, isEmpty);
        expect(controller.scheduledNotificationThreadIds, isEmpty);
        expect(fakeSync.accountDeleted, isTrue);

        controller.dispose();
      },
    );
  });

  group('UI Polish Fixes & Sanctuary compliance widget tests', () {
    test('encodes and parses After a Moment notification deep-link payload',
        () {
      const String threadId = 'thread_interview_01';
      final String payload =
          LocalCheckInNotificationService.buildDeepLinkPayload(threadId);
      expect(payload, 'unravel://after-moment?threadId=thread_interview_01');
      expect(
        LocalCheckInNotificationService.parseThreadIdFromPayload(payload),
        threadId,
      );
    });

    testWidgets(
      'verifies HomeJournalScreen single lower sun pill (no double clock) and UnravelKnotSheet single close button + Before/After toggle',
      (WidgetTester tester) async {
        final _FakeSyncEngine fakeSync = _FakeSyncEngine();
        final UnravelJournalController controller = UnravelJournalController(
          syncEngine: fakeSync,
          isFossBuild: false,
          initialThemePreference: CircadianThemePreference.duskPine,
          clock: () => DateTime(2026, 10, 21, 18, 45),
        );

        await tester.pumpWidget(
          UnravelApp(
            syncEngine: fakeSync,
            isFossBuild: false,
            controller: controller,
          ),
        );
        tester.view.physicalSize = const Size(900, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpAndSettle();

        // Mandatory UI Polish Fix #1: Exactly ONE Circadian sun pill ("Dusk · 6:45 PM")
        expect(find.text('Dusk · 6:45 PM'), findsOneWidget);

        // Open the thread wizard from the floating pill. It is one screen, with one close button.
        await tester.tap(find.text('Hold to Unravel a Worry'));
        await tester.pumpAndSettle();

        expect(find.text('Name the moment'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(find.text('Unravel Entry Modal'), findsNothing);

        await tester.tap(find.byTooltip('Dismiss reflection'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'deep-links into After a Moment tab and executes two-step Sanctuary Vault Purge',
      (WidgetTester tester) async {
        final _FakeSyncEngine fakeSync = _FakeSyncEngine();
        final UnravelJournalController controller = UnravelJournalController(
          syncEngine: fakeSync,
          isFossBuild: false,
          initialThemePreference: CircadianThemePreference.duskPine,
        );

        await tester.pumpWidget(
          UnravelApp(
            syncEngine: fakeSync,
            isFossBuild: false,
            controller: controller,
          ),
        );
        tester.view.physicalSize = const Size(900, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpAndSettle();

        // 1. Simulate tapping a scheduled post-event check-in notification
        controller.notificationService
            .dispatchDeepLinkForThread('thread_interview_01');
        await tester.pumpAndSettle();

        // Verify the Unravel a Knot sheet opened directly to "After a Moment"
        expect(
          find.text('AFTER A MOMENT · REALITY CHECK-IN'),
          findsOneWidget,
        );
        expect(find.text('Record to Perspective Curve'), findsOneWidget);

        // Dismiss modal sheet
        await tester.tap(find.byTooltip('Dismiss reflection'));
        await tester.pumpAndSettle();

        // 2. Navigate to Sanctuary tab and verify Safe-Harbor & Two-Step Purge
        await tester.tap(find.text('Sanctuary'));
        await tester.pumpAndSettle();

        expect(find.text('Circadian Rhythm Mode'), findsOneWidget);
        expect(find.text('AES-256-GCM · Key Held on Device'), findsOneWidget);
        expect(
          find.textContaining('Philosophical Safe-Harbor Notice'),
          findsOneWidget,
        );

        // Scroll down to "Purge Vault & Delete Cloud Account"
        await tester.scrollUntilVisible(
          find.text('Purge Vault & Delete Cloud Account'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(SanctuaryScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.text('Purge Vault & Delete Cloud Account'));
        await tester.pumpAndSettle();

        // Step 1 of dialog: Confirm button is disabled until checkbox is ticked
        expect(
          find.text('Purge Vault & Delete Cloud Account?'),
          findsOneWidget,
        );
        await tester.tap(
          find.text('I understand this purge is immediate and irreversible.'),
        );
        await tester.pumpAndSettle();

        // Step 2 of dialog: Confirm permanent purge
        await tester.tap(find.text('Confirm Permanent Purge'));
        await tester.pumpAndSettle();

        expect(fakeSync.accountDeleted, isTrue);
        expect(controller.activeOpenThreads, isEmpty);
        expect(controller.perspectiveEntries, isEmpty);
      },
    );
  });

  group('Sprint 3 — EphemeralHardwareVoiceCaptureService & Stoic Schema', () {
    test(
      'streams 30fps normalized amplitude (0.0..1.0) and shreds RAM + temp files on stopAndShred()',
      () async {
        final EphemeralHardwareVoiceCaptureService voiceService =
            EphemeralHardwareVoiceCaptureService(
          frameInterval: const Duration(milliseconds: 10),
        );

        final Directory tempDir =
            await Directory.systemTemp.createTemp('unravel_audio_test_');
        final File tempAudioFile = File('${tempDir.path}/ephemeral_buf.pcm');
        await tempAudioFile.writeAsBytes(Uint8List.fromList(<int>[1, 2, 3, 4]));
        voiceService.registerEphemeralTempFileForShredding(tempAudioFile);

        final List<VoiceAmplitudeFrame> frames = <VoiceAmplitudeFrame>[];
        final subscription = voiceService.amplitudeStream.listen(frames.add);

        await voiceService.startCapture(
          maxDuration: const Duration(seconds: 60),
        );
        expect(voiceService.isRecording, isTrue);
        expect(voiceService.activeTempFilesCount, 1);

        // Feed a loud 16-bit PCM frame and wait for 30fps ticks
        final ByteData loudPcm = ByteData(320);
        for (int i = 0; i < 160; i++) {
          loudPcm.setInt16(i * 2, 16000, Endian.little);
        }
        voiceService.ingestPcm16Frame(loudPcm.buffer.asUint8List());
        await Future<void>.delayed(const Duration(milliseconds: 45));

        expect(voiceService.inMemoryBufferBytes, greaterThan(0));
        expect(frames, isNotEmpty);
        for (final VoiceAmplitudeFrame frame in frames) {
          expect(frame.normalizedAmplitude, inInclusiveRange(0.0, 1.0));
          expect(frame.decibelsDbfs, inInclusiveRange(-60.0, 0.0));
        }

        // Stop and shred: verify ZERO persistent audio disk or RAM leaks
        final EphemeralVoiceCaptureResult result =
            await voiceService.stopAndShred();
        expect(voiceService.isRecording, isFalse);
        expect(voiceService.inMemoryBufferBytes, 0);
        expect(voiceService.activeTempFilesCount, 0);
        expect(tempAudioFile.existsSync(), isFalse);
        expect(result.shreddedPcmBytes, greaterThan(0));
        expect(result.shreddedTempFiles, 1);

        await subscription.cancel();
        await voiceService.dispose();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'UntangledKnotSuggestion.fromValidatedJson enforces WITHIN_MY_CONTROL and BEYOND_MY_CONTROL schema',
      () {
        final UntangledKnotSuggestion valid =
            UntangledKnotSuggestion.fromValidatedJson(<String, Object?>{
          'eventTitle': 'Architecture Review',
          'whatFearSays': '“Any silence means I failed.”',
          'groundedTruth': 'Composure invites thoughtful engineering dialogue.',
          'physicalAnchor':
              'Place both feet flat on the floor before speaking.',
          'untangledWorries': <Object?>[
            <String, Object?>{
              'indexNumber': '01',
              'worryText': 'Explaining the SQLite encryption envelope.',
              'controlScope': 'WITHIN_MY_CONTROL',
              'actionOrGrounding': 'Review the Argon2id parameters once.',
            },
            <String, Object?>{
              'indexNumber': '02',
              'worryText': 'Whether the committee prefers a cloud vendor.',
              'controlScope': 'BEYOND_MY_CONTROL',
              'actionOrGrounding':
                  'Their vendor preference is outside your sphere of choice.',
            },
          ],
        });

        expect(valid.eventTitle, 'Architecture Review');
        expect(valid.whatFearSays, '“Any silence means I failed.”');
        expect(
          valid.physicalAnchor,
          'Place both feet flat on the floor before speaking.',
        );
        expect(valid.untangledWorries.length, 2);
        expect(
          valid.untangledWorries.first.controlScope,
          WorryControlScope.withinMyControl,
        );
        expect(
          valid.untangledWorries.last.controlScope,
          WorryControlScope.beyondMyControl,
        );

        // Invalid controlScope enum must throw UnravelSchemaValidationException
        expect(
          () => UntangledKnotSuggestion.fromValidatedJson(<String, Object?>{
            'eventTitle': 'Architecture Review',
            'whatFearSays': '“Any silence means I failed.”',
            'groundedTruth': 'Composure invites dialogue.',
            'physicalAnchor': 'Breathe slowly.',
            'untangledWorries': <Object?>[
              <String, Object?>{
                'indexNumber': '01',
                'worryText': 'Invalid scope test',
                'controlScope': 'INVALID_SCOPE',
                'actionOrGrounding': 'Step',
              },
            ],
          }),
          throwsA(isA<UnravelSchemaValidationException>()),
        );
      },
    );
  });

  group('Voice distance and one-way journal files', () {
    test('near speech fills the scale and distant speech stays small', () {
      expect(EphemeralHardwareVoiceCaptureService.normalizeDbfs(-12), 1);
      expect(EphemeralHardwareVoiceCaptureService.normalizeDbfs(0), 1);
      expect(EphemeralHardwareVoiceCaptureService.normalizeDbfs(-48), 0);
      expect(EphemeralHardwareVoiceCaptureService.normalizeDbfs(-60), 0);
      final double distant =
          EphemeralHardwareVoiceCaptureService.normalizeDbfs(-40);
      expect(distant, greaterThan(0));
      expect(distant, lessThan(0.2));
    });

    test('the open-source app refuses a store journal before decrypting it',
        () {
      const WrappedMasterKeyBundle wrapped = WrappedMasterKeyBundle(
        version: 1,
        argon2SaltBase64: 'c2FsdA==',
        wrappingNonceBase64: 'bm9uY2U=',
        wrappedKeyCiphertextBase64: 'Y3Q=',
        wrappingMacBase64: 'bWFj',
      );
      final Uint8List storeFile = JournalArchive.encode(
        const JournalArchive(
          edition: JournalArchive.storeEdition,
          wrappedKey: wrapped,
          encryptedPayload: 'v1:bm9uY2U=:Y3Q=:bWFj',
        ),
      );
      final JournalArchive peeked = JournalArchive.peek(storeFile);
      expect(
        () => JournalArchive.assertImportable(
          edition: peeked.edition,
          isFossBuild: true,
        ),
        throwsA(isA<JournalTransferException>()),
      );
      JournalArchive.assertImportable(
        edition: peeked.edition,
        isFossBuild: false,
      );

      final Uint8List fossFile = JournalArchive.encode(
        const JournalArchive(
          edition: JournalArchive.fossEdition,
          wrappedKey: wrapped,
          encryptedPayload: 'v1:bm9uY2U=:Y3Q=:bWFj',
        ),
      );
      JournalArchive.assertImportable(
        edition: JournalArchive.peek(fossFile).edition,
        isFossBuild: true,
      );
    });
  });
}
