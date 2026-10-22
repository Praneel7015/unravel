import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../audio/voice_capture_service.dart';
import '../../crypto/envelope_encryption_service.dart';
import '../../database/tables.dart';
import '../../database/unravel_database.dart';
import '../../interfaces/sync_and_relay_interfaces.dart';
import '../../notifications/local_checkin_notification_service.dart';
import '../../theme/circadian_mode.dart';

/// Storage mode selected in Sanctuary's "Sovereign Data Vault".
enum StorageArchitectureMode {
  localOnly('Local Only'),
  selfHostWebDav('Self-Host'),
  encryptedCloudSync('Encrypted Sync');

  const StorageArchitectureMode(this.label);
  final String label;
}

/// AI processing mode selected in Sanctuary's "Intelligence Routing".
enum IntelligenceRoutingMode {
  managedMultiModelRelay('Managed Multi-Model Relay'),
  byokOrLocalDaemon('Bring Your Own Key or Local Daemon');

  const IntelligenceRoutingMode(this.label);
  final String label;
}

/// Reactive state controller for Unravel's Circadian Theme Engine, Open Threads,
/// Perspective Curve logs, offline check-in notifications, and Sovereign Sanctuary settings.
class UnravelJournalController extends ChangeNotifier {
  UnravelJournalController({
    required this.syncEngine,
    required this.isFossBuild,
    CircadianThemePreference initialThemePreference =
        CircadianThemePreference.circadianAuto,
    EnvelopeEncryptionService? encryptionService,
    LocalCheckInNotificationService? notificationService,
    VoiceCaptureService? voiceCaptureService,
    UnravelDatabase? database,
    DateTime Function()? clock,
  })  : _themePreference = initialThemePreference,
        _encryptionService = encryptionService ?? EnvelopeEncryptionService(),
        notificationService =
            notificationService ?? LocalCheckInNotificationService(),
        voiceCaptureService =
            voiceCaptureService ?? EphemeralHardwareVoiceCaptureService(),
        _database = database,
        _clock = clock ?? DateTime.now,
        _storageMode = StorageArchitectureMode.localOnly,
        _intelligenceMode = isFossBuild
            ? IntelligenceRoutingMode.byokOrLocalDaemon
            : IntelligenceRoutingMode.managedMultiModelRelay {
    if (_database == null) {
      _seedInitialFieldJournal();
    } else {
      unawaited(_hydrateFromDatabase());
    }
    _scheduleNextCircadianTransition();
  }

  final UnravelSyncEngine syncEngine;
  final bool isFossBuild;
  final EnvelopeEncryptionService _encryptionService;
  final LocalCheckInNotificationService notificationService;
  final VoiceCaptureService voiceCaptureService;
  final UnravelDatabase? _database;
  final DateTime Function() _clock;

  CircadianThemePreference _themePreference;
  StorageArchitectureMode _storageMode;
  IntelligenceRoutingMode _intelligenceMode;
  String _byokEndpointOrKey = 'http://localhost:11434';
  SecretKey? _masterDataKey;
  Timer? _circadianTransitionTimer;

  final List<OpenThreadRecord> _openThreads = <OpenThreadRecord>[];
  final List<PerspectiveCurveEntry> _perspectiveEntries =
      <PerspectiveCurveEntry>[];
  final Set<String> _scheduledNotificationThreadIds = <String>{};

  CircadianThemePreference get themePreference => _themePreference;
  StorageArchitectureMode get storageMode => _storageMode;
  IntelligenceRoutingMode get intelligenceMode => _intelligenceMode;
  String get byokEndpointOrKey => _byokEndpointOrKey;

  /// Set of `OpenThread` IDs that currently have an active local check-in notification scheduled.
  Set<String> get scheduledNotificationThreadIds =>
      Set<String>.unmodifiable(_scheduledNotificationThreadIds);

  bool get isCircadianAuto =>
      _themePreference == CircadianThemePreference.circadianAuto;

  /// Resolves the active [CircadianPalette] based on user preference and local clock.
  CircadianPalette get activePalette => CircadianResolver.resolvePalette(
        preference: _themePreference,
        now: _clock(),
      );

  /// Formatted label for the single lower Circadian sun pill on Home Journal
  /// (e.g. `Dawn · 7:15 AM` or `Dusk · 6:45 PM`).
  String get sunPillLabel => CircadianResolver.formatSunPillLabel(_clock());

  /// Human-readable label for the next automatic Circadian transition in Sanctuary.
  String get nextTransitionSummary {
    final DateTime now = _clock();
    final DateTime nextTime = CircadianResolver.nextTransitionTime(now);
    final CircadianPalette nextPalette =
        CircadianResolver.resolveForTime(nextTime);
    final String hh = nextTime.hour.toString().padLeft(2, '0');
    final String mm = nextTime.minute.toString().padLeft(2, '0');
    return 'Next: $hh:$mm ${nextPalette.displayName}';
  }

  List<OpenThreadRecord> get activeOpenThreads => _openThreads
      .where(
        (OpenThreadRecord t) => t.status != OpenThreadStatus.unraveled,
      )
      .toList(growable: false);

  List<OpenThreadRecord> get unraveledThreads => _openThreads
      .where(
        (OpenThreadRecord t) => t.status == OpenThreadStatus.unraveled,
      )
      .toList(growable: false);

  List<PerspectiveCurveEntry> get perspectiveEntries =>
      List<PerspectiveCurveEntry>.unmodifiable(_perspectiveEntries);

  /// Finds an [OpenThreadRecord] by its [threadId] (used when deep-linking from
  /// a local post-event check-in notification into `After a Moment`).
  OpenThreadRecord? findThreadById(String threadId) {
    for (final OpenThreadRecord thread in _openThreads) {
      if (thread.id == threadId) {
        return thread;
      }
    }
    return null;
  }

  /// Calculates how much gentler reality unfolded compared to predicted fear
  /// across all recorded Perspective Curve logs (e.g., `82` for `82% gentler`).
  int get gentlerThanFearedPercentage {
    if (_perspectiveEntries.isEmpty) {
      return 0;
    }
    double totalPredicted = 0;
    double totalReduction = 0;
    for (final PerspectiveCurveEntry entry in _perspectiveEntries) {
      totalPredicted += entry.predictedFear;
      final int delta = entry.predictedFear - entry.actualOutcome;
      if (delta > 0) {
        totalReduction += delta;
      }
    }
    if (totalPredicted <= 0) {
      return 0;
    }
    return ((totalReduction / totalPredicted) * 100).round().clamp(0, 100);
  }

  /// Toggles automatic "Circadian Rhythm Mode" on or off.
  void setCircadianAutoEnabled(bool enabled) {
    if (enabled) {
      _themePreference = CircadianThemePreference.circadianAuto;
      _scheduleNextCircadianTransition();
    } else {
      _circadianTransitionTimer?.cancel();
      _themePreference = _preferenceFromPalette(activePalette);
    }
    notifyListeners();
  }

  /// Selects a specific [CircadianPalette] swatch in Sanctuary.
  void selectPaletteManually(CircadianPalette palette) {
    _circadianTransitionTimer?.cancel();
    _themePreference = _preferenceFromPalette(palette);
    notifyListeners();
  }

  void setStorageMode(StorageArchitectureMode mode) {
    _storageMode = mode;
    notifyListeners();
  }

  void setIntelligenceMode(IntelligenceRoutingMode mode) {
    _intelligenceMode = mode;
    notifyListeners();
  }

  void setByokEndpointOrKey(String value) {
    if (value.trim().isNotEmpty) {
      _byokEndpointOrKey = value.trim();
      notifyListeners();
    }
  }

  /// Encrypts and adds a new "Before a Moment" [OpenThreadRecord] using
  /// on-device AES-256-GCM envelope encryption, and optionally schedules a
  /// real offline local notification at `scheduledCheckInAt`.
  Future<OpenThreadRecord> createOpenThread({
    required String eventTitle,
    required List<UnraveledWorryItem> worries,
    required String groundingAnchor,
    required int predictedFear,
    required DateTime eventOccursAt,
    String? voiceTranscript,
    bool scheduleNotification = true,
    Duration checkInDelayAfterEvent = const Duration(hours: 1),
  }) async {
    final SecretKey key = await _ensureMasterKey();
    final String id = 'thread_${DateTime.now().microsecondsSinceEpoch}';
    final String? encryptedTranscript =
        (voiceTranscript != null && voiceTranscript.trim().isNotEmpty)
            ? await _encryptionService.encryptText(
                plaintext: voiceTranscript.trim(),
                masterDataKey: key,
                associatedRecordId: '$id:transcript',
              )
            : null;

    final String encryptedSyncPayload = await _encryptionService.encryptText(
      plaintext: '$eventTitle|$groundingAnchor',
      masterDataKey: key,
      associatedRecordId: '$id:sync',
    );

    final DateTime now = _clock();
    final DateTime scheduledCheckInAt =
        eventOccursAt.add(checkInDelayAfterEvent);

    final OpenThreadRecord record = OpenThreadRecord(
      id: id,
      eventTitle: eventTitle.trim(),
      worries: List<UnraveledWorryItem>.unmodifiable(worries),
      groundingAnchor: groundingAnchor.trim(),
      encryptedTranscript: encryptedTranscript,
      encryptedSyncPayload: encryptedSyncPayload,
      predictedFear: predictedFear.clamp(1, 10),
      eventOccursAt: eventOccursAt,
      scheduledCheckInAt: scheduledCheckInAt,
      status: OpenThreadStatus.open,
      createdAt: now,
      updatedAt: now,
    );

    _openThreads.insert(0, record);

    if (_database != null) {
      try {
        await _database.into(_database.openThreads).insert(record);
      } catch (_) {
        // The in-memory journal still holds the thread if the local write fails.
      }
    }

    notifyListeners();

    if (scheduleNotification) {
      try {
        _scheduledNotificationThreadIds.add(id);
        await notificationService.scheduleGentleAfterMomentCheckIn(
          threadId: id,
          eventTitle: record.eventTitle,
          scheduledCheckInAt: scheduledCheckInAt,
        );
      } catch (_) {
        _scheduledNotificationThreadIds.remove(id);
      }
    }

    return record;
  }

  /// Completes the gentle "After a Moment" check-in, encrypting reflection notes
  /// with AES-256-GCM, cancelling any pending notification for [threadId], and
  /// appending a new point to the Perspective Curve.
  Future<PerspectiveCurveEntry> completeAfterMomentCheckIn({
    required String threadId,
    required int actualOutcome,
    required String reflectionNotes,
  }) async {
    final SecretKey key = await _ensureMasterKey();
    final int index =
        _openThreads.indexWhere((OpenThreadRecord t) => t.id == threadId);
    final OpenThreadRecord? existing =
        index >= 0 ? _openThreads[index] : null;

    final int predictedFear = existing?.predictedFear ?? 8;
    final String eventTitle = existing?.eventTitle ?? 'Recent Moment';
    final String logId = 'log_${DateTime.now().microsecondsSinceEpoch}';

    final String encryptedNotes = await _encryptionService.encryptText(
      plaintext: reflectionNotes.trim(),
      masterDataKey: key,
      associatedRecordId: '$logId:notes',
    );
    final String verifiedPlaintext = await _encryptionService.decryptText(
      encryptedEnvelope: encryptedNotes,
      masterDataKey: key,
      associatedRecordId: '$logId:notes',
    );

    final DateTime now = _clock();
    if (existing != null && index >= 0) {
      _openThreads[index] = OpenThreadRecord(
        id: existing.id,
        eventTitle: existing.eventTitle,
        worries: existing.worries,
        groundingAnchor: existing.groundingAnchor,
        encryptedTranscript: existing.encryptedTranscript,
        encryptedSyncPayload: existing.encryptedSyncPayload,
        predictedFear: existing.predictedFear,
        eventOccursAt: existing.eventOccursAt,
        scheduledCheckInAt: existing.scheduledCheckInAt,
        status: OpenThreadStatus.unraveled,
        createdAt: existing.createdAt,
        updatedAt: now,
        resolvedAt: now,
      );
    }

    _scheduledNotificationThreadIds.remove(threadId);
    await notificationService.cancelForThread(threadId);

    final PerspectiveCurveEntry entry = PerspectiveCurveEntry(
      logId: logId,
      threadId: threadId,
      eventTitle: eventTitle,
      predictedFear: predictedFear,
      actualOutcome: actualOutcome.clamp(1, 10),
      decryptedNotes: verifiedPlaintext,
      recordedAt: now,
    );

    _perspectiveEntries.add(entry);
    notifyListeners();
    return entry;
  }

  /// Apple App Store Guideline 5.1.1(v) Compliance:
  /// Permanently purges the local SQLite database (`OpenThreads` & `PerspectiveLogs`),
  /// cancels all scheduled notifications, rotates/destroys the on-device Master Data Key,
  /// and invokes the authenticated `delete_my_account()` RPC via [syncEngine].
  Future<void> purgeVaultAndDeleteCloudAccount() async {
    await notificationService.cancelAll();
    _scheduledNotificationThreadIds.clear();
    _openThreads.clear();
    _perspectiveEntries.clear();

    if (_database != null) {
      await _database.purgeAllLocalTables();
    }

    // Destroy current Master Data Key reference and generate a fresh unlinked key
    _masterDataKey = await _encryptionService.generateMasterDataKey();

    await syncEngine.deleteCloudAccountAndData();
    notifyListeners();
  }

  /// Generates an Argon2id-wrapped Master Data Key backup bundle on-device.
  Future<WrappedMasterKeyBundle> exportWrappedKeyBundle(
    String passphrase,
  ) async {
    final SecretKey key = await _ensureMasterKey();
    return _encryptionService.wrapMasterKey(
      masterDataKey: key,
      passphrase: passphrase,
    );
  }

  Future<SecretKey> _ensureMasterKey() async {
    return _masterDataKey ??= await _encryptionService.generateMasterDataKey();
  }

  CircadianThemePreference _preferenceFromPalette(CircadianPalette palette) {
    switch (palette) {
      case CircadianPalette.morningMist:
        return CircadianThemePreference.morningMist;
      case CircadianPalette.highSun:
        return CircadianThemePreference.highSun;
      case CircadianPalette.duskPine:
        return CircadianThemePreference.duskPine;
      case CircadianPalette.midnightStarlight:
        return CircadianThemePreference.midnightStarlight;
    }
  }

  Future<void> _hydrateFromDatabase() async {
    final UnravelDatabase? database = _database;
    if (database == null) {
      return;
    }
    try {
      final List<OpenThreadRecord> rows =
          await database.select(database.openThreads).get();
      if (_openThreads.isNotEmpty) {
        return;
      }
      if (rows.isEmpty) {
        _seedInitialFieldJournal();
      } else {
        rows.sort(
          (OpenThreadRecord a, OpenThreadRecord b) =>
              b.createdAt.compareTo(a.createdAt),
        );
        _openThreads.addAll(rows);
      }
      notifyListeners();
    } catch (_) {
      if (_openThreads.isEmpty) {
        _seedInitialFieldJournal();
        notifyListeners();
      }
    }
  }

  void _scheduleNextCircadianTransition() {
    _circadianTransitionTimer?.cancel();
    if (!isCircadianAuto) {
      return;
    }
    final DateTime now = _clock();
    final DateTime nextTransition = CircadianResolver.nextTransitionTime(now);
    final Duration delay = nextTransition.difference(now);
    _circadianTransitionTimer = Timer(
      delay.isNegative ? const Duration(minutes: 1) : delay,
      () {
        notifyListeners();
        _scheduleNextCircadianTransition();
      },
    );
  }

  void _seedInitialFieldJournal() {
    final DateTime now = _clock();
    _openThreads.addAll(<OpenThreadRecord>[
      OpenThreadRecord(
        id: 'thread_interview_01',
        eventTitle: 'Product Design Interview',
        worries: const <UnraveledWorryItem>[
          UnraveledWorryItem(
            indexNumber: '01',
            worryText:
                'I might freeze up when asked about system architecture trade-offs.',
            controlScope: WorryControlScope.withinMyControl,
            actionOrGrounding:
                'Sketch 2 past projects on index cards tonight.',
          ),
          UnraveledWorryItem(
            indexNumber: '02',
            worryText:
                'What if they already have an internal candidate in mind?',
            controlScope: WorryControlScope.beyondMyControl,
            actionOrGrounding:
                'I cannot control their budget, only the clarity of my craft.',
          ),
        ],
        groundingAnchor:
            'Preparation is quiet confidence. I am there to have a conversation among peers, not to pass an interrogation.',
        encryptedTranscript: null,
        encryptedSyncPayload: 'v1:seeded_local_envelope',
        predictedFear: 8,
        eventOccursAt: now.add(const Duration(hours: 18)),
        scheduledCheckInAt: now.add(const Duration(hours: 19)),
        status: OpenThreadStatus.open,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      OpenThreadRecord(
        id: 'thread_arch_review',
        eventTitle: 'Q3 Architecture Review',
        worries: const <UnraveledWorryItem>[
          UnraveledWorryItem(
            indexNumber: '01',
            worryText: 'The latency trade-off might derail the timeline review.',
            controlScope: WorryControlScope.withinMyControl,
            actionOrGrounding: 'Lead with the benchmark numbers upfront.',
          ),
        ],
        groundingAnchor: 'Clear data invites collaborative problem-solving.',
        encryptedTranscript: null,
        encryptedSyncPayload: 'v1:seeded_local_envelope_2',
        predictedFear: 8,
        eventOccursAt: now.subtract(const Duration(days: 2)),
        scheduledCheckInAt: now.subtract(const Duration(days: 2)),
        status: OpenThreadStatus.unraveled,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 2)),
        resolvedAt: now.subtract(const Duration(days: 2)),
      ),
      OpenThreadRecord(
        id: 'thread_difficult_conv',
        eventTitle: 'Difficult Conversation',
        worries: const <UnraveledWorryItem>[
          UnraveledWorryItem(
            indexNumber: '01',
            worryText: 'Setting a boundary on scope might create friction.',
            controlScope: WorryControlScope.withinMyControl,
            actionOrGrounding: 'Speak warmly and anchor on shared quality.',
          ),
        ],
        groundingAnchor: 'Kindness and clear boundaries can coexist.',
        encryptedTranscript: null,
        encryptedSyncPayload: 'v1:seeded_local_envelope_3',
        predictedFear: 9,
        eventOccursAt: now.subtract(const Duration(days: 5)),
        scheduledCheckInAt: now.subtract(const Duration(days: 5)),
        status: OpenThreadStatus.unraveled,
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: now.subtract(const Duration(days: 5)),
        resolvedAt: now.subtract(const Duration(days: 5)),
      ),
    ]);

    _perspectiveEntries.addAll(<PerspectiveCurveEntry>[
      PerspectiveCurveEntry(
        logId: 'log_mon',
        threadId: 'thread_hist_1',
        eventTitle: 'Sprint Scope Reset',
        predictedFear: 7,
        actualOutcome: 2,
        decryptedNotes: 'Team welcomed the realistic timeline.',
        recordedAt: now.subtract(const Duration(days: 5)),
      ),
      PerspectiveCurveEntry(
        logId: 'log_tue',
        threadId: 'thread_difficult_conv',
        eventTitle: 'Difficult Conversation',
        predictedFear: 9,
        actualOutcome: 2,
        decryptedNotes: 'Setting a calm boundary earned immediate respect.',
        recordedAt: now.subtract(const Duration(days: 4)),
      ),
      PerspectiveCurveEntry(
        logId: 'log_wed',
        threadId: 'thread_hist_3',
        eventTitle: 'Design Critique',
        predictedFear: 8,
        actualOutcome: 3,
        decryptedNotes: 'Feedback focused on typography polish, not rejection.',
        recordedAt: now.subtract(const Duration(days: 3)),
      ),
      PerspectiveCurveEntry(
        logId: 'log_thu',
        threadId: 'thread_hist_4',
        eventTitle: 'Client Roadmap Call',
        predictedFear: 6,
        actualOutcome: 2,
        decryptedNotes: 'Smooth alignment on Q4 priorities.',
        recordedAt: now.subtract(const Duration(days: 2)),
      ),
      PerspectiveCurveEntry(
        logId: 'log_fri',
        threadId: 'thread_arch_review',
        eventTitle: 'Q3 Architecture Review',
        predictedFear: 8,
        actualOutcome: 2,
        decryptedNotes:
            'They actually appreciated that I flagged the latency trade-off early.',
        recordedAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  @override
  void dispose() {
    _circadianTransitionTimer?.cancel();
    unawaited(voiceCaptureService.dispose());
    notificationService.dispose();
    super.dispose();
  }
}
