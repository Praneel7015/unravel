import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../audio/voice_capture_service.dart';
import '../../crypto/envelope_encryption_service.dart';
import '../../database/tables.dart';
import '../../database/unravel_database.dart';
import '../../interfaces/sync_and_relay_interfaces.dart';
import '../../journal/journal_archive.dart';
import '../../journal/journal_field_rules.dart';
import '../../journal/journal_vault_store.dart';
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
    JournalVaultStore? vaultStore,
    DateTime Function()? clock,
  })  : _themePreference = initialThemePreference,
        _encryptionService = encryptionService ?? EnvelopeEncryptionService(),
        notificationService =
            notificationService ?? LocalCheckInNotificationService(),
        voiceCaptureService =
            voiceCaptureService ?? EphemeralHardwareVoiceCaptureService(),
        _database = database,
        _vault = database == null ? vaultStore : (vaultStore ?? FileJournalVaultStore()),
        _clock = clock ?? DateTime.now,
        _storageMode = StorageArchitectureMode.localOnly,
        _intelligenceMode = isFossBuild
            ? IntelligenceRoutingMode.byokOrLocalDaemon
            : IntelligenceRoutingMode.managedMultiModelRelay,
        _setupComplete = database == null && vaultStore == null,
        _vaultReady = database == null && vaultStore == null {
    if (_vault != null) {
      unawaited(_loadVault());
    }
    _scheduleNextCircadianTransition();
  }

  final UnravelSyncEngine syncEngine;
  final bool isFossBuild;
  final EnvelopeEncryptionService _encryptionService;
  final LocalCheckInNotificationService notificationService;
  final VoiceCaptureService voiceCaptureService;
  final UnravelDatabase? _database;
  final JournalVaultStore? _vault;
  final DateTime Function() _clock;

  CircadianThemePreference _themePreference;
  StorageArchitectureMode _storageMode;
  IntelligenceRoutingMode _intelligenceMode;
  String _byokEndpointOrKey = '';
  SecretKey? _masterDataKey;
  WrappedMasterKeyBundle? _wrappedKey;
  bool _setupComplete;
  bool _vaultReady;
  bool _needsUnlock = false;
  Timer? _circadianTransitionTimer;

  final List<OpenThreadRecord> _openThreads = <OpenThreadRecord>[];
  final List<PerspectiveCurveEntry> _perspectiveEntries =
      <PerspectiveCurveEntry>[];
  final Set<String> _scheduledNotificationThreadIds = <String>{};

  CircadianThemePreference get themePreference => _themePreference;
  StorageArchitectureMode get storageMode => _storageMode;
  IntelligenceRoutingMode get intelligenceMode => _intelligenceMode;
  String get byokEndpointOrKey => _byokEndpointOrKey;
  bool get setupComplete => _setupComplete;
  bool get vaultReady => _vaultReady;
  bool get needsUnlock => _needsUnlock;
  bool get hasWrappedKey => _wrappedKey != null;

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
  /// (e.g. `Dawn Â· 7:15 AM` or `Dusk Â· 6:45 PM`).
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
    final String title = eventTitle.trim();
    final String? titleError = JournalFieldRules.titleError(title);
    if (titleError != null) {
      throw ArgumentError(titleError);
    }
    final String anchor = groundingAnchor.trim();
    final String? anchorError = JournalFieldRules.anchorError(anchor);
    if (anchorError != null) {
      throw ArgumentError(anchorError);
    }
    final String? fearError = JournalFieldRules.fearError(predictedFear);
    if (fearError != null) {
      throw ArgumentError(fearError);
    }
    final List<UnraveledWorryItem> normalizedWorries =
        JournalFieldRules.normalizeWorries(worries);

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
      plaintext: '$title|$anchor',
      masterDataKey: key,
      associatedRecordId: '$id:sync',
    );

    final DateTime now = _clock();
    final DateTime scheduledCheckInAt =
        eventOccursAt.add(checkInDelayAfterEvent);

    final OpenThreadRecord record = OpenThreadRecord(
      id: id,
      eventTitle: title,
      worries: List<UnraveledWorryItem>.unmodifiable(normalizedWorries),
      groundingAnchor: anchor,
      encryptedTranscript: encryptedTranscript,
      encryptedSyncPayload: encryptedSyncPayload,
      predictedFear: predictedFear,
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

    if (existing == null) {
      throw ArgumentError('That moment is not on this device.');
    }
    final String? outcomeError = JournalFieldRules.fearError(actualOutcome);
    if (outcomeError != null) {
      throw ArgumentError(outcomeError);
    }
    final int predictedFear = existing.predictedFear;
    final String eventTitle = existing.eventTitle;
    final String notes = reflectionNotes.trim().isEmpty
        ? 'No written note.'
        : reflectionNotes.trim();
    final String logId = 'log_${DateTime.now().microsecondsSinceEpoch}';

    final String encryptedNotes = await _encryptionService.encryptText(
      plaintext: notes,
      masterDataKey: key,
      associatedRecordId: '$logId:notes',
    );
    final String verifiedPlaintext = await _encryptionService.decryptText(
      encryptedEnvelope: encryptedNotes,
      masterDataKey: key,
      associatedRecordId: '$logId:notes',
    );

    final DateTime now = _clock();
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

    _scheduledNotificationThreadIds.remove(threadId);
    await notificationService.cancelForThread(threadId);

    final PerspectiveCurveEntry entry = PerspectiveCurveEntry(
      logId: logId,
      threadId: threadId,
      eventTitle: eventTitle,
      predictedFear: predictedFear,
      actualOutcome: actualOutcome,
      decryptedNotes: verifiedPlaintext,
      recordedAt: now,
    );

    _perspectiveEntries.add(entry);
    final UnravelDatabase? database = _database;
    if (database != null && index >= 0) {
      try {
        await database.saveCheckIn(
          thread: _openThreads[index],
          log: PerspectiveLogRecord(
            id: logId,
            threadId: threadId,
            predictedFear: predictedFear,
            actualOutcome: actualOutcome,
            encryptedNotes: encryptedNotes,
            recordedAt: now.toUtc(),
          ),
        );
      } catch (_) {
        // The in-memory curve still holds the check-in if the local write fails.
      }
    }
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

    _masterDataKey = null;
    _wrappedKey = null;
    if (_vault != null) {
      await _vault.clear();
      _setupComplete = false;
      _needsUnlock = false;
    }

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
      if (_openThreads.isEmpty) {
        rows.sort(
          (OpenThreadRecord a, OpenThreadRecord b) =>
              b.createdAt.compareTo(a.createdAt),
        );
        _openThreads.addAll(rows);
      }
      final SecretKey? key = _masterDataKey;
      if (key != null && _perspectiveEntries.isEmpty) {
        _perspectiveEntries.addAll(
          await database.loadDecryptedPerspectiveCurve(masterDataKey: key),
        );
      }
      notifyListeners();
    } catch (_) {
      notifyListeners();
    }
  }

  Future<void> _loadVault() async {
    final JournalVaultStore? vault = _vault;
    if (vault == null) {
      _vaultReady = true;
      notifyListeners();
      return;
    }
    try {
      final JournalVaultRecord? record = await vault.read();
      _wrappedKey = record?.wrappedKey;
      _setupComplete = record?.setupComplete == true && _wrappedKey != null;
      _needsUnlock = _setupComplete && _masterDataKey == null;
    } catch (_) {
      _setupComplete = false;
      _needsUnlock = false;
    }
    _vaultReady = true;
    notifyListeners();
  }

  /// Wraps a new master key. Setup stays unfinished until the later screens end.
  Future<void> savePassphrase(String passphrase) async {
    final SecretKey key = await _encryptionService.generateMasterDataKey();
    final WrappedMasterKeyBundle wrapped = await _encryptionService.wrapMasterKey(
      masterDataKey: key,
      passphrase: passphrase,
    );
    _masterDataKey = key;
    _wrappedKey = wrapped;
    _needsUnlock = false;
    await _vault?.write(
      JournalVaultRecord(setupComplete: false, wrappedKey: wrapped),
    );
    notifyListeners();
  }

  /// Marks the first-run sequence finished and opens the empty journal.
  Future<void> markSetupFinished() async {
    final WrappedMasterKeyBundle? wrapped = _wrappedKey;
    if (wrapped == null) {
      return;
    }
    _setupComplete = true;
    _needsUnlock = false;
    await _vault?.write(
      JournalVaultRecord(setupComplete: true, wrappedKey: wrapped),
    );
    notifyListeners();
  }

  /// Unwraps the on-device key. Returns false when the passphrase is wrong.
  Future<bool> unlock(String passphrase) async {
    final WrappedMasterKeyBundle? wrapped = _wrappedKey;
    if (wrapped == null) {
      return false;
    }
    try {
      _masterDataKey = await _encryptionService.unwrapMasterKey(
        bundle: wrapped,
        passphrase: passphrase,
      );
      _needsUnlock = false;
      await _hydrateFromDatabase();
      notifyListeners();
      return true;
    } on UnravelCryptoException {
      return false;
    }
  }

  /// Builds an encrypted journal file marked with this app's edition.
  Future<Uint8List> exportJournalArchive() async {
    final SecretKey key = await _ensureMasterKey();
    final WrappedMasterKeyBundle? wrapped = _wrappedKey;
    if (wrapped == null) {
      throw const JournalTransferException(
        'Set a passphrase before exporting the journal.',
      );
    }
    final List<Map<String, Object?>> threads = <Map<String, Object?>>[];
    for (final OpenThreadRecord thread in _openThreads) {
      String? transcript;
      final String? envelope = thread.encryptedTranscript;
      if (envelope != null && envelope.isNotEmpty) {
        try {
          transcript = await _encryptionService.decryptText(
            encryptedEnvelope: envelope,
            masterDataKey: key,
            associatedRecordId: '${thread.id}:transcript',
          );
        } catch (_) {
          transcript = null;
        }
      }
      threads.add(<String, Object?>{
        'id': thread.id,
        'eventTitle': thread.eventTitle,
        'worries': thread.worries
            .map((UnraveledWorryItem item) => item.toJson())
            .toList(),
        'groundingAnchor': thread.groundingAnchor,
        'predictedFear': thread.predictedFear,
        'eventOccursAt': thread.eventOccursAt.toUtc().toIso8601String(),
        'scheduledCheckInAt': thread.scheduledCheckInAt.toUtc().toIso8601String(),
        'status': thread.status.wireValue,
        'createdAt': thread.createdAt.toUtc().toIso8601String(),
        'updatedAt': thread.updatedAt.toUtc().toIso8601String(),
        'resolvedAt': thread.resolvedAt?.toUtc().toIso8601String(),
        'transcript': transcript,
      });
    }
    final List<Map<String, Object?>> logs = <Map<String, Object?>>[
      for (final PerspectiveCurveEntry entry in _perspectiveEntries)
        <String, Object?>{
          'id': entry.logId,
          'threadId': entry.threadId,
          'eventTitle': entry.eventTitle,
          'predictedFear': entry.predictedFear,
          'actualOutcome': entry.actualOutcome,
          'notes': entry.decryptedNotes,
          'recordedAt': entry.recordedAt.toUtc().toIso8601String(),
        },
    ];
    final String payload = jsonEncode(<String, Object?>{
      'threads': threads,
      'logs': logs,
    });
    final String encrypted = await _encryptionService.encryptJournalArchive(
      plaintext: payload,
      masterDataKey: key,
    );
    return JournalArchive.encode(
      JournalArchive(
        edition: isFossBuild ? JournalArchive.fossEdition : JournalArchive.storeEdition,
        wrappedKey: wrapped,
        encryptedPayload: encrypted,
      ),
    );
  }

  /// Merges a journal file. A store file is refused on the open-source app
  /// before the passphrase is used to decrypt anything into the journal.
  Future<void> importJournalArchive({
    required Uint8List bytes,
    required String passphrase,
  }) async {
    final JournalArchive peeked = JournalArchive.peek(bytes);
    JournalArchive.assertImportable(
      edition: peeked.edition,
      isFossBuild: isFossBuild,
    );
    final SecretKey fileKey = await _encryptionService.unwrapMasterKey(
      bundle: peeked.wrappedKey,
      passphrase: passphrase,
    );
    final String clear = await _encryptionService.decryptJournalArchive(
      encryptedEnvelope: peeked.encryptedPayload,
      masterDataKey: fileKey,
    );
    final Object? decoded = jsonDecode(clear);
    if (decoded is! Map) {
      throw const JournalTransferException('This file is not an Unravel journal.');
    }
    final SecretKey localKey = await _ensureMasterKey();
    final Object? rawThreads = decoded['threads'];
    if (rawThreads is List) {
      for (final Object? raw in rawThreads) {
        if (raw is! Map) {
          continue;
        }
        final Map<String, Object?> json = raw.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value as Object?),
        );
        await _mergeImportedThread(json, localKey);
      }
    }
    final Object? rawLogs = decoded['logs'];
    if (rawLogs is List) {
      for (final Object? raw in rawLogs) {
        if (raw is! Map) {
          continue;
        }
        final Map<String, Object?> json = raw.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value as Object?),
        );
        await _mergeImportedLog(json, localKey);
      }
    }
    notifyListeners();
  }

  Future<void> _mergeImportedThread(
    Map<String, Object?> json,
    SecretKey localKey,
  ) async {
    final String? id = json['id'] as String?;
    final String title = (json['eventTitle'] as String?) ?? '';
    final String anchor = (json['groundingAnchor'] as String?) ?? '';
    final int fear = (json['predictedFear'] as num?)?.toInt() ?? 0;
    if (id == null ||
        JournalFieldRules.titleError(title) != null ||
        JournalFieldRules.anchorError(anchor) != null ||
        JournalFieldRules.fearError(fear) != null) {
      return;
    }
    final int existingIndex =
        _openThreads.indexWhere((OpenThreadRecord thread) => thread.id == id);
    final DateTime updatedAt =
        DateTime.tryParse((json['updatedAt'] as String?) ?? '')?.toUtc() ??
            _clock().toUtc();
    if (existingIndex >= 0 &&
        !_openThreads[existingIndex].updatedAt.isBefore(updatedAt)) {
      return;
    }
    final Object? rawWorries = json['worries'];
    final List<UnraveledWorryItem> worries = <UnraveledWorryItem>[];
    if (rawWorries is List) {
      for (int i = 0; i < rawWorries.length; i++) {
        worries.add(UnraveledWorryItem.fromJson(rawWorries[i], fallbackIndex: i + 1));
      }
    }
    final List<UnraveledWorryItem> normalized =
        JournalFieldRules.normalizeWorries(worries);
    final String? transcript = json['transcript'] as String?;
    final String? encryptedTranscript =
        (transcript != null && transcript.trim().isNotEmpty)
            ? await _encryptionService.encryptText(
                plaintext: transcript.trim(),
                masterDataKey: localKey,
                associatedRecordId: '$id:transcript',
              )
            : null;
    final String encryptedSyncPayload = await _encryptionService.encryptText(
      plaintext: '$title|$anchor',
      masterDataKey: localKey,
      associatedRecordId: '$id:sync',
    );
    final OpenThreadRecord record = OpenThreadRecord(
      id: id,
      eventTitle: title.trim(),
      worries: normalized,
      groundingAnchor: anchor.trim(),
      encryptedTranscript: encryptedTranscript,
      encryptedSyncPayload: encryptedSyncPayload,
      predictedFear: fear,
      eventOccursAt:
          DateTime.tryParse((json['eventOccursAt'] as String?) ?? '')?.toUtc() ??
              updatedAt,
      scheduledCheckInAt: DateTime.tryParse(
            (json['scheduledCheckInAt'] as String?) ?? '',
          )?.toUtc() ??
          updatedAt,
      status: OpenThreadStatus.fromWire((json['status'] as String?) ?? 'open'),
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '')?.toUtc() ??
              updatedAt,
      updatedAt: updatedAt,
      resolvedAt: DateTime.tryParse((json['resolvedAt'] as String?) ?? '')?.toUtc(),
    );
    if (existingIndex >= 0) {
      _openThreads[existingIndex] = record;
    } else {
      _openThreads.insert(0, record);
    }
    final UnravelDatabase? database = _database;
    if (database != null) {
      await database.replaceThread(record);
    }
  }

  Future<void> _mergeImportedLog(
    Map<String, Object?> json,
    SecretKey localKey,
  ) async {
    final String? id = json['id'] as String?;
    final String? threadId = json['threadId'] as String?;
    final int predicted = (json['predictedFear'] as num?)?.toInt() ?? 0;
    final int actual = (json['actualOutcome'] as num?)?.toInt() ?? 0;
    final String notes = ((json['notes'] as String?) ?? '').trim();
    if (id == null ||
        threadId == null ||
        JournalFieldRules.fearError(predicted) != null ||
        JournalFieldRules.fearError(actual) != null ||
        notes.isEmpty) {
      return;
    }
    if (_openThreads.every((OpenThreadRecord thread) => thread.id != threadId)) {
      return;
    }
    final DateTime recordedAt =
        DateTime.tryParse((json['recordedAt'] as String?) ?? '')?.toUtc() ??
            _clock().toUtc();
    final int existingIndex = _perspectiveEntries.indexWhere(
      (PerspectiveCurveEntry entry) => entry.logId == id,
    );
    if (existingIndex >= 0 &&
        !_perspectiveEntries[existingIndex].recordedAt.isBefore(recordedAt)) {
      return;
    }
    final String encryptedNotes = await _encryptionService.encryptText(
      plaintext: notes,
      masterDataKey: localKey,
      associatedRecordId: '$id:notes',
    );
    final OpenThreadRecord thread = _openThreads.firstWhere(
      (OpenThreadRecord item) => item.id == threadId,
    );
    final PerspectiveCurveEntry entry = PerspectiveCurveEntry(
      logId: id,
      threadId: threadId,
      eventTitle: thread.eventTitle,
      predictedFear: predicted,
      actualOutcome: actual,
      decryptedNotes: notes,
      recordedAt: recordedAt,
    );
    if (existingIndex >= 0) {
      _perspectiveEntries[existingIndex] = entry;
    } else {
      _perspectiveEntries.add(entry);
    }
    final UnravelDatabase? database = _database;
    if (database != null) {
      await database.replacePerspectiveLog(
        PerspectiveLogRecord(
          id: id,
          threadId: threadId,
          predictedFear: predicted,
          actualOutcome: actual,
          encryptedNotes: encryptedNotes,
          recordedAt: recordedAt,
        ),
      );
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

  @override
  void dispose() {
    _circadianTransitionTimer?.cancel();
    unawaited(voiceCaptureService.dispose());
    notificationService.dispose();
    super.dispose();
  }
}
