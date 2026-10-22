import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:meta/meta.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Deep-link URI scheme used by local post-event check-in notifications.
const String kAfterMomentDeepLinkPrefix = 'unravel://after-moment?threadId=';

/// Pure FOSS local notification scheduler (`flutter_local_notifications` + `timezone`)
/// with ZERO Firebase Cloud Messaging or Google Play Services dependencies.
///
/// Schedules a single gentle "After a Moment" check-in notification at
/// `scheduledCheckInAt` and deep-links into the `After a Moment (How It Unfolded)`
/// tab of `UnravelKnotSheet` for the specific `OpenThread`.
class LocalCheckInNotificationService {
  LocalCheckInNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _deepLinkThreadController =
      StreamController<String>.broadcast();
  bool _initialized = false;

  /// Emits the `threadId` whenever the user taps a post-event check-in notification.
  Stream<String> get onCheckInThreadSelected =>
      _deepLinkThreadController.stream;

  /// Builds the deterministic notification payload (`unravel://after-moment?threadId=<id>`).
  static String buildDeepLinkPayload(String threadId) =>
      '$kAfterMomentDeepLinkPrefix${Uri.encodeComponent(threadId)}';

  /// Parses the `threadId` from a notification payload if it matches our deep-link scheme.
  static String? parseThreadIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(kAfterMomentDeepLinkPrefix)) {
      return null;
    }
    final String encoded = payload.substring(kAfterMomentDeepLinkPrefix.length);
    if (encoded.isEmpty) {
      return null;
    }
    return Uri.decodeComponent(encoded);
  }

  /// Deterministically maps a string `threadId` to a positive 31-bit notification ID.
  @visibleForTesting
  static int notificationIdForThread(String threadId) {
    int hash = 0x811c9dc5;
    for (int i = 0; i < threadId.length; i++) {
      hash ^= threadId.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  /// Initializes the local notification plugin and timezone database.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open reflection');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      final NotificationAppLaunchDetails? launchDetails =
          await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final String? launchThreadId = parseThreadIdFromPayload(
          launchDetails.notificationResponse?.payload,
        );
        if (launchThreadId != null) {
          _deepLinkThreadController.add(launchThreadId);
        }
      }
      _initialized = true;
    } catch (_) {
      // Gracefully tolerate headless widget test environments where platform channels are absent.
      _initialized = false;
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final String? threadId = parseThreadIdFromPayload(response.payload);
    if (threadId != null) {
      _deepLinkThreadController.add(threadId);
    }
  }

  /// Simulates or dispatches a deep-link tap for testing or cold-start routing.
  void dispatchDeepLinkForThread(String threadId) {
    _deepLinkThreadController.add(threadId);
  }

  /// Schedules a single gentle "After a Moment" notification at [scheduledCheckInAt].
  /// Never sends repeat/nagging notifications or raw worry text on the lock screen.
  Future<void> scheduleGentleAfterMomentCheckIn({
    required String threadId,
    required String eventTitle,
    required DateTime scheduledCheckInAt,
  }) async {
    await initialize();
    if (!_initialized) {
      return;
    }

    final int notificationId = notificationIdForThread(threadId);
    final DateTime now = DateTime.now();
    final DateTime effectiveTarget = scheduledCheckInAt.isAfter(now)
        ? scheduledCheckInAt
        : now.add(const Duration(minutes: 1));
    final tz.TZDateTime tzScheduled =
        tz.TZDateTime.from(effectiveTarget.toUtc(), tz.UTC);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'unravel_after_moment_channel',
      'Gentle Post-Event Check-Ins',
      channelDescription:
          'Single calm reflection prompt after a scheduled life moment has passed.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      visibility: NotificationVisibility.private,
    );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.zonedSchedule(
      notificationId,
      'After a Moment · $eventTitle',
      'Now that the moment has passed, gently record how reality unfolded.',
      tzScheduled,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: buildDeepLinkPayload(threadId),
    );
  }

  /// Cancels a scheduled check-in notification once the thread is unraveled.
  Future<void> cancelForThread(String threadId) async {
    if (!_initialized) {
      return;
    }
    await _plugin.cancel(notificationIdForThread(threadId));
  }

  /// Cancels all pending notifications (invoked during Vault Purge).
  Future<void> cancelAll() async {
    if (!_initialized) {
      return;
    }
    await _plugin.cancelAll();
  }

  void dispose() {
    unawaited(_deepLinkThreadController.close());
  }
}
