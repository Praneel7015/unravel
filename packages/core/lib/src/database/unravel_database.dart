import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:meta/meta.dart';

import '../crypto/envelope_encryption_service.dart';
import 'tables.dart';

part 'unravel_database.g.dart';

/// Decrypted view model of a single point on the Perspective Curve
/// ("What My Fear Predicted" vs. "How Life Actually Unfolded").
@immutable
class PerspectiveCurveEntry {
  const PerspectiveCurveEntry({
    required this.logId,
    required this.threadId,
    required this.eventTitle,
    required this.predictedFear,
    required this.actualOutcome,
    required this.decryptedNotes,
    required this.recordedAt,
  });

  final String logId;
  final String threadId;
  final String eventTitle;

  /// 1..10 ("What My Fear Predicted" — `#C97054` muted terracotta dashed line)
  final int predictedFear;

  /// 1..10 ("How Life Actually Unfolded" — `#84A98C` solid sage curve)
  final int actualOutcome;

  /// Client-side decrypted reflection notes.
  final String decryptedNotes;

  final DateTime recordedAt;
}

@DriftDatabase(tables: <Type>[OpenThreads, PerspectiveLogs])
class UnravelDatabase extends _$UnravelDatabase {
  UnravelDatabase({
    QueryExecutor? executor,
    EnvelopeEncryptionService? encryptionService,
  })  : _encryption = encryptionService ?? EnvelopeEncryptionService(),
        super(executor ?? _openDefaultConnection());

  final EnvelopeEncryptionService _encryption;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openDefaultConnection() {
    return driftDatabase(name: 'unravel_field_journal');
  }

  /// Creates a new "Before a Moment" [OpenThreadRecord], encrypting its
  /// sync envelope and optional voice transcript with AES-256-GCM on-device.
  Future<OpenThreadRecord> createOpenThread({
    required String id,
    required String eventTitle,
    required List<UnraveledWorryItem> worries,
    required String groundingAnchor,
    required int predictedFear,
    required DateTime eventOccursAt,
    required DateTime scheduledCheckInAt,
    required SecretKey masterDataKey,
    String? plainVoiceTranscript,
  }) async {
    if (predictedFear < 1 || predictedFear > 10) {
      throw ArgumentError.value(
        predictedFear,
        'predictedFear',
        'Must be between 1 and 10.',
      );
    }

    String? encryptedTranscript;
    if (plainVoiceTranscript != null &&
        plainVoiceTranscript.trim().isNotEmpty) {
      encryptedTranscript = await _encryption.encryptText(
        plaintext: plainVoiceTranscript.trim(),
        masterDataKey: masterDataKey,
        associatedRecordId: '$id:transcript',
      );
    }

    final String syncCleartextJson = jsonEncode(<String, Object?>{
      'id': id,
      'eventTitle': eventTitle,
      'worries': worries.map((UnraveledWorryItem w) => w.toJson()).toList(),
      'groundingAnchor': groundingAnchor,
      'predictedFear': predictedFear,
      'eventOccursAt': eventOccursAt.toUtc().toIso8601String(),
      'scheduledCheckInAt': scheduledCheckInAt.toUtc().toIso8601String(),
      'transcript': plainVoiceTranscript,
    });

    final String encryptedSyncPayload = await _encryption.encryptText(
      plaintext: syncCleartextJson,
      masterDataKey: masterDataKey,
      associatedRecordId: '$id:sync',
    );

    final DateTime now = DateTime.now().toUtc();
    final OpenThreadRecord record = OpenThreadRecord(
      id: id,
      eventTitle: eventTitle,
      worries: List<UnraveledWorryItem>.unmodifiable(worries),
      groundingAnchor: groundingAnchor,
      encryptedTranscript: encryptedTranscript,
      encryptedSyncPayload: encryptedSyncPayload,
      predictedFear: predictedFear,
      eventOccursAt: eventOccursAt.toUtc(),
      scheduledCheckInAt: scheduledCheckInAt.toUtc(),
      status: OpenThreadStatus.open,
      createdAt: now,
      updatedAt: now,
      resolvedAt: null,
    );

    await into(openThreads).insert(record);
    return record;
  }

  /// Watches all active Open Threads (`open` or `ready_for_checkin`) ordered by
  /// upcoming event time.
  Stream<List<OpenThreadRecord>> watchActiveOpenThreads() {
    final SimpleSelectStatement<$OpenThreadsTable, OpenThreadRecord> query =
        select(openThreads)
          ..where(
            ($OpenThreadsTable t) => t.status.isIn(<String>[
              OpenThreadStatus.open.wireValue,
              OpenThreadStatus.readyForCheckIn.wireValue,
            ]),
          )
          ..orderBy(<OrderClauseGenerator<$OpenThreadsTable>>[
            ($OpenThreadsTable t) => OrderingTerm(
                  expression: t.eventOccursAt,
                  mode: OrderingMode.asc,
                ),
          ]);
    return query.watch();
  }

  /// Completes the gentle "After a Moment" check-in by atomically:
  /// 1. Encrypting the post-event reflection [plainNotes] via AES-256-GCM,
  /// 2. Inserting a [PerspectiveLogRecord] (`predictedFear` 1..10 vs `actualOutcome` 1..10),
  /// 3. Marking the parent [OpenThreads] row as `unraveled`.
  Future<PerspectiveLogRecord> recordAfterMomentPerspective({
    required String logId,
    required String threadId,
    required int predictedFear,
    required int actualOutcome,
    required String plainNotes,
    required SecretKey masterDataKey,
    DateTime? recordedAt,
  }) async {
    if (predictedFear < 1 || predictedFear > 10) {
      throw ArgumentError.value(
        predictedFear,
        'predictedFear',
        'Must be between 1 and 10.',
      );
    }
    if (actualOutcome < 1 || actualOutcome > 10) {
      throw ArgumentError.value(
        actualOutcome,
        'actualOutcome',
        'Must be between 1 and 10.',
      );
    }

    final String encryptedNotes = await _encryption.encryptText(
      plaintext: plainNotes,
      masterDataKey: masterDataKey,
      associatedRecordId: '$logId:notes',
    );

    final DateTime timestamp = (recordedAt ?? DateTime.now()).toUtc();
    final PerspectiveLogRecord logRecord = PerspectiveLogRecord(
      id: logId,
      threadId: threadId,
      predictedFear: predictedFear,
      actualOutcome: actualOutcome,
      encryptedNotes: encryptedNotes,
      recordedAt: timestamp,
    );

    await transaction(() async {
      await into(perspectiveLogs).insert(logRecord);
      await (update(openThreads)
            ..where(($OpenThreadsTable t) => t.id.equals(threadId)))
          .write(
        OpenThreadsCompanion(
          status: const Value<OpenThreadStatus>(OpenThreadStatus.unraveled),
          updatedAt: Value<DateTime>(timestamp),
          resolvedAt: Value<DateTime?>(timestamp),
        ),
      );
    });

    return logRecord;
  }

  /// Loads and decrypts the chronological **Perspective Curve** entries on-device.
  Future<List<PerspectiveCurveEntry>> loadDecryptedPerspectiveCurve({
    required SecretKey masterDataKey,
  }) async {
    final JoinedSelectStatement<HasResultSet, dynamic> joined = select(
      perspectiveLogs,
    ).join(<Join<HasResultSet, dynamic>>[
      innerJoin(
        openThreads,
        openThreads.id.equalsExp(perspectiveLogs.threadId),
      ),
    ])
      ..orderBy(<OrderingTerm>[
        OrderingTerm(
          expression: perspectiveLogs.recordedAt,
          mode: OrderingMode.asc,
        ),
      ]);

    final List<TypedResult> rows = await joined.get();
    final List<PerspectiveCurveEntry> entries = <PerspectiveCurveEntry>[];

    for (final TypedResult row in rows) {
      final PerspectiveLogRecord log = row.readTable(perspectiveLogs);
      final OpenThreadRecord thread = row.readTable(openThreads);
      final String clearNotes = await _encryption.decryptText(
        encryptedEnvelope: log.encryptedNotes,
        masterDataKey: masterDataKey,
        associatedRecordId: '${log.id}:notes',
      );
      entries.add(
        PerspectiveCurveEntry(
          logId: log.id,
          threadId: log.threadId,
          eventTitle: thread.eventTitle,
          predictedFear: log.predictedFear,
          actualOutcome: log.actualOutcome,
          decryptedNotes: clearNotes,
          recordedAt: log.recordedAt,
        ),
      );
    }

    return entries;
  }

  /// Replaces one thread during a journal import.
  Future<void> replaceThread(OpenThreadRecord record) {
    return into(openThreads).insert(record, mode: InsertMode.insertOrReplace);
  }

  /// Replaces one perspective log during a journal import.
  Future<void> replacePerspectiveLog(PerspectiveLogRecord record) {
    return into(perspectiveLogs).insert(
      record,
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Writes a finished check-in and the updated thread together.
  Future<void> saveCheckIn({
    required OpenThreadRecord thread,
    required PerspectiveLogRecord log,
  }) {
    return transaction(() async {
      await into(openThreads).insert(thread, mode: InsertMode.insertOrReplace);
      await into(perspectiveLogs).insert(log, mode: InsertMode.insertOrReplace);
    });
  }

  /// Atomically wipes all local `PerspectiveLogs` and `OpenThreads` rows
  /// during a Sovereign Vault Purge (Apple Guideline 5.1.1(v) compliance).
  Future<void> purgeAllLocalTables() async {
    await transaction(() async {
      await delete(perspectiveLogs).go();
      await delete(openThreads).go();
    });
  }
}
