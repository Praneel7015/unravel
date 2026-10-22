import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../crypto/envelope_encryption_service.dart';

/// Lifecycle states of an Open Thread ("Before a Moment" -> "After a Moment").
enum OpenThreadStatus {
  /// Upcoming event; worries and grounding anchor are actively held.
  open('open'),

  /// The event time has passed and the gentle post-event check-in is due.
  readyForCheckIn('ready_for_checkin'),

  /// Post-event check-in completed and logged to the Perspective Curve.
  unraveled('unraveled');

  const OpenThreadStatus(this.wireValue);
  final String wireValue;

  static OpenThreadStatus fromWire(String value) {
    for (final status in OpenThreadStatus.values) {
      if (status.wireValue == value) {
        return status;
      }
    }
    return OpenThreadStatus.open;
  }
}

/// Stoic control dichotomy badge shown on each unraveled worry in "Unravel a Knot":
/// - `WITHIN MY CONTROL` (Primary Sage/Moss badge + actionable `Next Step`)
/// - `BEYOND MY CONTROL` (Secondary Amber/Clay badge + `Grounding` reframe)
enum WorryControlScope {
  withinMyControl('within_my_control', 'WITHIN MY CONTROL', 'Next Step'),
  beyondMyControl('beyond_my_control', 'BEYOND MY CONTROL', 'Grounding');

  const WorryControlScope(this.wireValue, this.badgeLabel, this.actionPrefix);
  final String wireValue;
  final String badgeLabel;
  final String actionPrefix;

  static WorryControlScope fromWire(String? value) {
    for (final scope in WorryControlScope.values) {
      if (scope.wireValue == value) {
        return scope;
      }
    }
    return WorryControlScope.withinMyControl;
  }
}

/// A single numbered worry (`01`, `02`, ...) inside an [OpenThreadRecord].
@immutable
class UnraveledWorryItem {
  const UnraveledWorryItem({
    required this.indexNumber,
    required this.worryText,
    this.controlScope = WorryControlScope.withinMyControl,
    this.actionOrGrounding = '',
  });

  /// Zero-padded technical monospace index (`01`, `02`).
  final String indexNumber;

  /// The specific worry statement (e.g. "I might freeze up on system trade-offs").
  final String worryText;

  /// Stoic locus-of-control classification (`WITHIN MY CONTROL` vs `BEYOND MY CONTROL`).
  final WorryControlScope controlScope;

  /// Concrete next step or grounding statement shown beneath the worry in "Unravel a Knot".
  final String actionOrGrounding;

  Map<String, Object?> toJson() => <String, Object?>{
        'idx': indexNumber,
        'text': worryText,
        'scope': controlScope.wireValue,
        'action': actionOrGrounding,
      };

  factory UnraveledWorryItem.fromJson(Object? raw, {int fallbackIndex = 1}) {
    final String defaultIdx = fallbackIndex.toString().padLeft(2, '0');
    if (raw is String) {
      return UnraveledWorryItem(
        indexNumber: defaultIdx,
        worryText: raw,
      );
    }
    if (raw is Map<String, Object?>) {
      return UnraveledWorryItem(
        indexNumber: (raw['idx'] as String?) ?? defaultIdx,
        worryText: (raw['text'] as String?) ?? '',
        controlScope: WorryControlScope.fromWire(raw['scope'] as String?),
        actionOrGrounding: (raw['action'] as String?) ?? '',
      );
    }
    return UnraveledWorryItem(indexNumber: defaultIdx, worryText: '');
  }
}

/// Converts a `List<UnraveledWorryItem>` to/from a JSON array string in SQLite.
class WorriesListConverter
    extends TypeConverter<List<UnraveledWorryItem>, String> {
  const WorriesListConverter();

  @override
  List<UnraveledWorryItem> fromSql(String fromDb) {
    final Object? decoded = jsonDecode(fromDb);
    if (decoded is List<Object?>) {
      final List<UnraveledWorryItem> items = <UnraveledWorryItem>[];
      for (int i = 0; i < decoded.length; i++) {
        items.add(
          UnraveledWorryItem.fromJson(decoded[i], fallbackIndex: i + 1),
        );
      }
      return List<UnraveledWorryItem>.unmodifiable(items);
    }
    return const <UnraveledWorryItem>[];
  }

  @override
  String toSql(List<UnraveledWorryItem> value) {
    return jsonEncode(
      value.map((UnraveledWorryItem item) => item.toJson()).toList(),
    );
  }
}

/// Converts [OpenThreadStatus] to/from its SQLite text representation.
class OpenThreadStatusConverter
    extends TypeConverter<OpenThreadStatus, String> {
  const OpenThreadStatusConverter();

  @override
  OpenThreadStatus fromSql(String fromDb) => OpenThreadStatus.fromWire(fromDb);

  @override
  String toSql(OpenThreadStatus value) => value.wireValue;
}

/// `OpenThreads` table — represents an upcoming real-life moment ("Before a Moment"),
/// its numbered worries (`01`, `02`), its warm Grounding Anchor, and the scheduled
/// gentle post-event check-in ("After a Moment").
@DataClassName('OpenThreadRecord')
class OpenThreads extends Table {
  /// Client-generated UUIDv4 primary key.
  TextColumn get id => text()();

  /// Upcoming life event title rendered in IBM Plex Serif.
  TextColumn get eventTitle => text().withLength(min: 1, max: 280)();

  /// JSON-encoded list of numbered [UnraveledWorryItem]s (`01`, `02`, ...) unraveled before the moment.
  TextColumn get worries => text().map(const WorriesListConverter())();

  /// Highlighted Grounding Anchor statement (`#242B26` container in Dusk Pine).
  TextColumn get groundingAnchor => text().withLength(min: 1, max: 1000)();

  /// Optional AES-256-GCM encrypted spoken voice transcript quote (`v1:<nonce>:<ct>:<mac>`).
  /// Raw audio is never stored on servers; even the transcript is E2EE capped at 16 KiB.
  TextColumn get encryptedTranscript => text()
      .nullable()
      .check(encryptedTranscript.length.isSmallerOrEqualValue(
        kMaxEncryptedPayloadBytes,
      ))();

  /// Complete AES-256-GCM encrypted envelope (`<= 16384` bytes) used whenever
  /// this thread is synced to WebDAV/Nextcloud or Supabase Cloud.
  TextColumn get encryptedSyncPayload => text().check(
        encryptedSyncPayload.length.isSmallerOrEqualValue(
          kMaxEncryptedPayloadBytes,
        ),
      )();

  /// Initial "What My Fear Predicted" intensity score (`1..10`) captured before the moment.
  IntColumn get predictedFear =>
      integer().check(predictedFear.isBetweenValues(1, 10))();

  /// When the upcoming life event occurs.
  DateTimeColumn get eventOccursAt => dateTime()();

  /// Scheduled gentle "After a Moment" check-in timestamp (no guilt or streak pressure).
  DateTimeColumn get scheduledCheckInAt => dateTime()();

  /// Current thread lifecycle state (`open`, `ready_for_checkin`, `unraveled`).
  TextColumn get status => text()
      .map(const OpenThreadStatusConverter())
      .withDefault(const Constant('open'))();

  /// Timestamp when the thread was created.
  DateTimeColumn get createdAt => dateTime()();

  /// Timestamp when the thread was last modified.
  DateTimeColumn get updatedAt => dateTime()();

  /// Timestamp when the post-event check-in was completed.
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// `PerspectiveLogs` table — powers the **Perspective Curve** comparing
/// "What My Fear Predicted" (`1..10`, `#C97054` muted terracotta dashed line)
/// vs. "How Life Actually Unfolded" (`1..10`, `#84A98C` solid sage curve),
/// along with AES-256-GCM encrypted post-event reflection notes.
@DataClassName('PerspectiveLogRecord')
class PerspectiveLogs extends Table {
  /// Client-generated UUIDv4 primary key.
  TextColumn get id => text()();

  /// Foreign key referencing the parent [OpenThreads.id].
  TextColumn get threadId =>
      text().references(OpenThreads, #id, onDelete: KeyAction.cascade)();

  /// "What My Fear Predicted" score on a 1–10 scale.
  IntColumn get predictedFear =>
      integer().check(predictedFear.isBetweenValues(1, 10))();

  /// "How Life Actually Unfolded" score on a 1–10 scale.
  IntColumn get actualOutcome =>
      integer().check(actualOutcome.isBetweenValues(1, 10))();

  /// AES-256-GCM encrypted post-event reflection notes (`v1:<nonce>:<ct>:<mac>`).
  /// Enforces `length <= 16384` bytes to match server-side abuse caps.
  TextColumn get encryptedNotes => text().check(
        encryptedNotes.length.isSmallerOrEqualValue(
          kMaxEncryptedPayloadBytes,
        ),
      )();

  /// Timestamp when the "After a Moment" perspective check-in was recorded.
  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
