// GENERATED CODE - HAND-VERIFIED DRIFT PART FILE (compatible with drift ^2.22.1)
// Run `dart run build_runner build --delete-conflicting-outputs` to regenerate.

part of 'unravel_database.dart';

// ignore_for_file: type=lint
class $OpenThreadsTable extends OpenThreads
    with TableInfo<$OpenThreadsTable, OpenThreadRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OpenThreadsTable(this.attachedDatabase, [this._alias]);

  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );

  static const VerificationMeta _eventTitleMeta =
      const VerificationMeta('eventTitle');
  @override
  late final GeneratedColumn<String> eventTitle = GeneratedColumn<String>(
    'event_title',
    aliasedName,
    false,
    additionalChecks:
        GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 280),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );

  static const VerificationMeta _worriesMeta =
      const VerificationMeta('worries');
  @override
  late final GeneratedColumnWithTypeConverter<List<UnraveledWorryItem>, String> worries =
      GeneratedColumn<String>(
    'worries',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<UnraveledWorryItem>>($OpenThreadsTable.$converterworries);

  static const VerificationMeta _groundingAnchorMeta =
      const VerificationMeta('groundingAnchor');
  @override
  late final GeneratedColumn<String> groundingAnchor = GeneratedColumn<String>(
    'grounding_anchor',
    aliasedName,
    false,
    additionalChecks:
        GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 1000),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );

  static const VerificationMeta _encryptedTranscriptMeta =
      const VerificationMeta('encryptedTranscript');
  @override
  late final GeneratedColumn<String> encryptedTranscript =
      GeneratedColumn<String>(
    'encrypted_transcript',
    aliasedName,
    true,
    check: () => encryptedTranscript.length
        .isSmallerOrEqualValue(kMaxEncryptedPayloadBytes),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );

  static const VerificationMeta _encryptedSyncPayloadMeta =
      const VerificationMeta('encryptedSyncPayload');
  @override
  late final GeneratedColumn<String> encryptedSyncPayload =
      GeneratedColumn<String>(
    'encrypted_sync_payload',
    aliasedName,
    false,
    check: () => encryptedSyncPayload.length
        .isSmallerOrEqualValue(kMaxEncryptedPayloadBytes),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );

  static const VerificationMeta _predictedFearMeta =
      const VerificationMeta('predictedFear');
  @override
  late final GeneratedColumn<int> predictedFear = GeneratedColumn<int>(
    'predicted_fear',
    aliasedName,
    false,
    check: () => predictedFear.isBetweenValues(1, 10),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );

  static const VerificationMeta _eventOccursAtMeta =
      const VerificationMeta('eventOccursAt');
  @override
  late final GeneratedColumn<DateTime> eventOccursAt =
      GeneratedColumn<DateTime>(
    'event_occurs_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );

  static const VerificationMeta _scheduledCheckInAtMeta =
      const VerificationMeta('scheduledCheckInAt');
  @override
  late final GeneratedColumn<DateTime> scheduledCheckInAt =
      GeneratedColumn<DateTime>(
    'scheduled_check_in_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );

  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumnWithTypeConverter<OpenThreadStatus, String> status =
      GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('open'),
  ).withConverter<OpenThreadStatus>($OpenThreadsTable.$converterstatus);

  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );

  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );

  static const VerificationMeta _resolvedAtMeta =
      const VerificationMeta('resolvedAt');
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );

  @override
  List<GeneratedColumn> get $columns => [
        id,
        eventTitle,
        worries,
        groundingAnchor,
        encryptedTranscript,
        encryptedSyncPayload,
        predictedFear,
        eventOccursAt,
        scheduledCheckInAt,
        status,
        createdAt,
        updatedAt,
        resolvedAt,
      ];

  @override
  String get aliasedName => _alias ?? actualTableName;

  @override
  String get actualTableName => $name;
  static const String $name = 'open_threads';

  @override
  VerificationContext validateIntegrity(
    Insertable<OpenThreadRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_title')) {
      context.handle(
        _eventTitleMeta,
        eventTitle.isAcceptableOrUnknown(data['event_title']!, _eventTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTitleMeta);
    }
    context.handle(_worriesMeta, const VerificationResult.success());
    if (data.containsKey('grounding_anchor')) {
      context.handle(
        _groundingAnchorMeta,
        groundingAnchor.isAcceptableOrUnknown(
          data['grounding_anchor']!,
          _groundingAnchorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_groundingAnchorMeta);
    }
    if (data.containsKey('encrypted_transcript')) {
      context.handle(
        _encryptedTranscriptMeta,
        encryptedTranscript.isAcceptableOrUnknown(
          data['encrypted_transcript']!,
          _encryptedTranscriptMeta,
        ),
      );
    }
    if (data.containsKey('encrypted_sync_payload')) {
      context.handle(
        _encryptedSyncPayloadMeta,
        encryptedSyncPayload.isAcceptableOrUnknown(
          data['encrypted_sync_payload']!,
          _encryptedSyncPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedSyncPayloadMeta);
    }
    if (data.containsKey('predicted_fear')) {
      context.handle(
        _predictedFearMeta,
        predictedFear.isAcceptableOrUnknown(
          data['predicted_fear']!,
          _predictedFearMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_predictedFearMeta);
    }
    if (data.containsKey('event_occurs_at')) {
      context.handle(
        _eventOccursAtMeta,
        eventOccursAt.isAcceptableOrUnknown(
          data['event_occurs_at']!,
          _eventOccursAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_eventOccursAtMeta);
    }
    if (data.containsKey('scheduled_check_in_at')) {
      context.handle(
        _scheduledCheckInAtMeta,
        scheduledCheckInAt.isAcceptableOrUnknown(
          data['scheduled_check_in_at']!,
          _scheduledCheckInAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledCheckInAtMeta);
    }
    context.handle(_statusMeta, const VerificationResult.success());
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};

  @override
  OpenThreadRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OpenThreadRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      eventTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_title'])!,
      worries: $OpenThreadsTable.$converterworries.fromSql(
        attachedDatabase.typeMapping
            .read(DriftSqlType.string, data['${effectivePrefix}worries'])!,
      ),
      groundingAnchor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grounding_anchor'],
      )!,
      encryptedTranscript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_transcript'],
      ),
      encryptedSyncPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_sync_payload'],
      )!,
      predictedFear: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}predicted_fear'])!,
      eventOccursAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}event_occurs_at'],
      )!,
      scheduledCheckInAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_check_in_at'],
      )!,
      status: $OpenThreadsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping
            .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      ),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      resolvedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}resolved_at']),
    );
  }

  @override
  $OpenThreadsTable createAlias(String alias) {
    return $OpenThreadsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<UnraveledWorryItem>, String> $converterworries =
      const WorriesListConverter();
  static TypeConverter<OpenThreadStatus, String> $converterstatus =
      const OpenThreadStatusConverter();
}

class OpenThreadRecord extends DataClass
    implements Insertable<OpenThreadRecord> {
  final String id;
  final String eventTitle;
  final List<UnraveledWorryItem> worries;
  final String groundingAnchor;
  final String? encryptedTranscript;
  final String encryptedSyncPayload;
  final int predictedFear;
  final DateTime eventOccursAt;
  final DateTime scheduledCheckInAt;
  final OpenThreadStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  const OpenThreadRecord({
    required this.id,
    required this.eventTitle,
    required this.worries,
    required this.groundingAnchor,
    this.encryptedTranscript,
    required this.encryptedSyncPayload,
    required this.predictedFear,
    required this.eventOccursAt,
    required this.scheduledCheckInAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_title'] = Variable<String>(eventTitle);
    {
      map['worries'] =
          Variable<String>($OpenThreadsTable.$converterworries.toSql(worries));
    }
    map['grounding_anchor'] = Variable<String>(groundingAnchor);
    if (!nullToAbsent || encryptedTranscript != null) {
      map['encrypted_transcript'] = Variable<String>(encryptedTranscript);
    }
    map['encrypted_sync_payload'] = Variable<String>(encryptedSyncPayload);
    map['predicted_fear'] = Variable<int>(predictedFear);
    map['event_occurs_at'] = Variable<DateTime>(eventOccursAt);
    map['scheduled_check_in_at'] = Variable<DateTime>(scheduledCheckInAt);
    {
      map['status'] =
          Variable<String>($OpenThreadsTable.$converterstatus.toSql(status));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventTitle': serializer.toJson<String>(eventTitle),
      'worries': serializer.toJson<List<UnraveledWorryItem>>(worries),
      'groundingAnchor': serializer.toJson<String>(groundingAnchor),
      'encryptedTranscript': serializer.toJson<String?>(encryptedTranscript),
      'encryptedSyncPayload': serializer.toJson<String>(encryptedSyncPayload),
      'predictedFear': serializer.toJson<int>(predictedFear),
      'eventOccursAt': serializer.toJson<DateTime>(eventOccursAt),
      'scheduledCheckInAt': serializer.toJson<DateTime>(scheduledCheckInAt),
      'status': serializer.toJson<OpenThreadStatus>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }
}

class OpenThreadsCompanion extends UpdateCompanion<OpenThreadRecord> {
  final Value<String> id;
  final Value<String> eventTitle;
  final Value<List<UnraveledWorryItem>> worries;
  final Value<String> groundingAnchor;
  final Value<String?> encryptedTranscript;
  final Value<String> encryptedSyncPayload;
  final Value<int> predictedFear;
  final Value<DateTime> eventOccursAt;
  final Value<DateTime> scheduledCheckInAt;
  final Value<OpenThreadStatus> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> resolvedAt;

  const OpenThreadsCompanion({
    this.id = const Value.absent(),
    this.eventTitle = const Value.absent(),
    this.worries = const Value.absent(),
    this.groundingAnchor = const Value.absent(),
    this.encryptedTranscript = const Value.absent(),
    this.encryptedSyncPayload = const Value.absent(),
    this.predictedFear = const Value.absent(),
    this.eventOccursAt = const Value.absent(),
    this.scheduledCheckInAt = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventTitle.present) {
      map['event_title'] = Variable<String>(eventTitle.value);
    }
    if (worries.present) {
      map['worries'] = Variable<String>(
        $OpenThreadsTable.$converterworries.toSql(worries.value),
      );
    }
    if (groundingAnchor.present) {
      map['grounding_anchor'] = Variable<String>(groundingAnchor.value);
    }
    if (encryptedTranscript.present) {
      map['encrypted_transcript'] =
          Variable<String>(encryptedTranscript.value);
    }
    if (encryptedSyncPayload.present) {
      map['encrypted_sync_payload'] =
          Variable<String>(encryptedSyncPayload.value);
    }
    if (predictedFear.present) {
      map['predicted_fear'] = Variable<int>(predictedFear.value);
    }
    if (eventOccursAt.present) {
      map['event_occurs_at'] = Variable<DateTime>(eventOccursAt.value);
    }
    if (scheduledCheckInAt.present) {
      map['scheduled_check_in_at'] =
          Variable<DateTime>(scheduledCheckInAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $OpenThreadsTable.$converterstatus.toSql(status.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    return map;
  }
}

class $PerspectiveLogsTable extends PerspectiveLogs
    with TableInfo<$PerspectiveLogsTable, PerspectiveLogRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PerspectiveLogsTable(this.attachedDatabase, [this._alias]);

  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );

  static const VerificationMeta _threadIdMeta =
      const VerificationMeta('threadId');
  @override
  late final GeneratedColumn<String> threadId = GeneratedColumn<String>(
    'thread_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES open_threads (id) ON DELETE CASCADE',
    ),
  );

  static const VerificationMeta _predictedFearMeta =
      const VerificationMeta('predictedFear');
  @override
  late final GeneratedColumn<int> predictedFear = GeneratedColumn<int>(
    'predicted_fear',
    aliasedName,
    false,
    check: () => predictedFear.isBetweenValues(1, 10),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );

  static const VerificationMeta _actualOutcomeMeta =
      const VerificationMeta('actualOutcome');
  @override
  late final GeneratedColumn<int> actualOutcome = GeneratedColumn<int>(
    'actual_outcome',
    aliasedName,
    false,
    check: () => actualOutcome.isBetweenValues(1, 10),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );

  static const VerificationMeta _encryptedNotesMeta =
      const VerificationMeta('encryptedNotes');
  @override
  late final GeneratedColumn<String> encryptedNotes = GeneratedColumn<String>(
    'encrypted_notes',
    aliasedName,
    false,
    check: () => encryptedNotes.length
        .isSmallerOrEqualValue(kMaxEncryptedPayloadBytes),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );

  static const VerificationMeta _recordedAtMeta =
      const VerificationMeta('recordedAt');
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );

  @override
  List<GeneratedColumn> get $columns => [
        id,
        threadId,
        predictedFear,
        actualOutcome,
        encryptedNotes,
        recordedAt,
      ];

  @override
  String get aliasedName => _alias ?? actualTableName;

  @override
  String get actualTableName => $name;
  static const String $name = 'perspective_logs';

  @override
  VerificationContext validateIntegrity(
    Insertable<PerspectiveLogRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('thread_id')) {
      context.handle(
        _threadIdMeta,
        threadId.isAcceptableOrUnknown(data['thread_id']!, _threadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_threadIdMeta);
    }
    if (data.containsKey('predicted_fear')) {
      context.handle(
        _predictedFearMeta,
        predictedFear.isAcceptableOrUnknown(
          data['predicted_fear']!,
          _predictedFearMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_predictedFearMeta);
    }
    if (data.containsKey('actual_outcome')) {
      context.handle(
        _actualOutcomeMeta,
        actualOutcome.isAcceptableOrUnknown(
          data['actual_outcome']!,
          _actualOutcomeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actualOutcomeMeta);
    }
    if (data.containsKey('encrypted_notes')) {
      context.handle(
        _encryptedNotesMeta,
        encryptedNotes.isAcceptableOrUnknown(
          data['encrypted_notes']!,
          _encryptedNotesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedNotesMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(
          data['recorded_at']!,
          _recordedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};

  @override
  PerspectiveLogRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PerspectiveLogRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      threadId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thread_id'])!,
      predictedFear: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}predicted_fear'])!,
      actualOutcome: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}actual_outcome'])!,
      encryptedNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_notes'],
      )!,
      recordedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}recorded_at'])!,
    );
  }

  @override
  $PerspectiveLogsTable createAlias(String alias) {
    return $PerspectiveLogsTable(attachedDatabase, alias);
  }
}

class PerspectiveLogRecord extends DataClass
    implements Insertable<PerspectiveLogRecord> {
  final String id;
  final String threadId;
  final int predictedFear;
  final int actualOutcome;
  final String encryptedNotes;
  final DateTime recordedAt;

  const PerspectiveLogRecord({
    required this.id,
    required this.threadId,
    required this.predictedFear,
    required this.actualOutcome,
    required this.encryptedNotes,
    required this.recordedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['thread_id'] = Variable<String>(threadId);
    map['predicted_fear'] = Variable<int>(predictedFear);
    map['actual_outcome'] = Variable<int>(actualOutcome);
    map['encrypted_notes'] = Variable<String>(encryptedNotes);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'threadId': serializer.toJson<String>(threadId),
      'predictedFear': serializer.toJson<int>(predictedFear),
      'actualOutcome': serializer.toJson<int>(actualOutcome),
      'encryptedNotes': serializer.toJson<String>(encryptedNotes),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }
}

class PerspectiveLogsCompanion extends UpdateCompanion<PerspectiveLogRecord> {
  final Value<String> id;
  final Value<String> threadId;
  final Value<int> predictedFear;
  final Value<int> actualOutcome;
  final Value<String> encryptedNotes;
  final Value<DateTime> recordedAt;

  const PerspectiveLogsCompanion({
    this.id = const Value.absent(),
    this.threadId = const Value.absent(),
    this.predictedFear = const Value.absent(),
    this.actualOutcome = const Value.absent(),
    this.encryptedNotes = const Value.absent(),
    this.recordedAt = const Value.absent(),
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (threadId.present) {
      map['thread_id'] = Variable<String>(threadId.value);
    }
    if (predictedFear.present) {
      map['predicted_fear'] = Variable<int>(predictedFear.value);
    }
    if (actualOutcome.present) {
      map['actual_outcome'] = Variable<int>(actualOutcome.value);
    }
    if (encryptedNotes.present) {
      map['encrypted_notes'] = Variable<String>(encryptedNotes.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    return map;
  }
}

abstract class _$UnravelDatabase extends GeneratedDatabase {
  _$UnravelDatabase(QueryExecutor e) : super(e);

  late final $OpenThreadsTable openThreads = $OpenThreadsTable(this);
  late final $PerspectiveLogsTable perspectiveLogs =
      $PerspectiveLogsTable(this);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [openThreads, perspectiveLogs];
}
