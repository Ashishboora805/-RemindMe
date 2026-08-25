import 'dart:convert';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Notification action ids. Kept as consts so the reminder repository,
/// the UI, and this service all agree on the same strings.
class NotificationActionIds {
  static const complete = 'action_complete';
  static const snooze = 'action_snooze';
  static const open = 'action_open';
}

const String _reminderCategoryId = 'reminder_category';
const String _defaultChannelId = 'reminders';
const String _channelName = 'Reminders';
const String _channelDescription = 'Scheduled reminders from Glass Notes';

/// Actions delivered while the app process is dead are handled in a separate
/// background isolate, which cannot touch the UI isolate's database. They are
/// appended to this file instead and replayed by [drainPendingActions] the
/// next time the app starts.
const String _pendingActionsFileName = 'pending_notification_actions.jsonl';

/// Payload carried on the notification, used to route taps/actions back to
/// the correct reminder without hitting the DB first.
class ReminderNotificationPayload {
  final String reminderId;
  final String? noteId;
  final String projectId;

  ReminderNotificationPayload({
    required this.reminderId,
    required this.projectId,
    this.noteId,
  });

  String encode() => jsonEncode({
        'reminderId': reminderId,
        'noteId': noteId,
        'projectId': projectId,
      });

  static ReminderNotificationPayload? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ReminderNotificationPayload(
        reminderId: map['reminderId'] as String,
        noteId: map['noteId'] as String?,
        projectId: map['projectId'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

typedef NotificationActionHandler = Future<void> Function(
  String actionId,
  ReminderNotificationPayload payload,
);

/// Safety net for notification responses that reach the app while its process
/// is not running — a dismissal, or an action the OS declines to bring the app
/// forward for. It executes in its own isolate with no access to the app's
/// providers or open database, so it only records what happened; the UI
/// isolate replays it via [NotificationService.drainPendingActions] on the
/// next launch.
///
/// The Complete / Snooze / Open buttons are all declared as foreground
/// actions, so in normal operation they are handled live by [_onResponse]
/// instead of arriving here.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  DartPluginRegistrant.ensureInitialized();
  final payload = response.payload;
  if (payload == null) return;
  final actionId = response.actionId ?? NotificationActionIds.open;
  // Fire-and-forget: the isolate stays alive long enough for a small append.
  _appendPendingAction(actionId, payload);
}

Future<void> _appendPendingAction(String actionId, String rawPayload) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, _pendingActionsFileName));
    await file.writeAsString(
      '${jsonEncode({'actionId': actionId, 'payload': rawPayload})}\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {
    // Losing a queued action is preferable to crashing a background isolate.
  }
}

/// Thin, testable wrapper around flutter_local_notifications configured for
/// both iOS and Android: permission requests, categories/actions/channels, and
/// scheduling primitives. Business logic (recurrence math, DB writes) lives in
/// ReminderService — this class only knows how to talk to the OS.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  NotificationActionHandler? _actionHandler;
  bool _initialized = false;

  /// Android channel ids already created this session, keyed by sound name.
  final Set<String> _createdChannels = {};

  Future<void> init({required NotificationActionHandler onAction}) async {
    _actionHandler = onAction;
    if (_initialized) return;

    await _configureLocalTimezone();

    final darwinInit = DarwinInitializationSettings(
      // Permission is requested explicitly and lazily — see requestPermission().
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _reminderCategoryId,
          // Every action is a foreground action on purpose. Completing or
          // snoozing has to write to SQLite *and* arm the next notification,
          // and a background action runs in an isolate with no access to the
          // app's open database — a snooze handled there would silently never
          // fire again. Bringing the app forward keeps the action honest.
          actions: [
            DarwinNotificationAction.plain(
              NotificationActionIds.complete,
              'Complete',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              NotificationActionIds.snooze,
              'Snooze',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              NotificationActionIds.open,
              'Open',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
          options: {DarwinNotificationCategoryOption.hiddenPreviewShowTitle},
        ),
      ],
    );

    // A silhouette drawable, not the launcher icon — Android strips colour from
    // the small icon and a full-colour asset renders as a white square.
    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');

    await _plugin.initialize(
      InitializationSettings(
        iOS: darwinInit,
        macOS: darwinInit,
        android: androidInit,
      ),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );

    if (Platform.isAndroid) {
      await _ensureChannel('default');
    }

    _initialized = true;
  }

  /// `timezone` defaults to UTC, which would fire every reminder at the wrong
  /// wall-clock time. Resolve the device's real zone before anything is
  /// scheduled.
  Future<void> _configureLocalTimezone() async {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to a zone whose current offset matches the device's, so
      // scheduled times still land on the right wall clock.
      final offset = DateTime.now().timeZoneOffset;
      final match = tz.timeZoneDatabase.locations.values.firstWhere(
        (l) => l.currentTimeZone.offset == offset.inMilliseconds,
        orElse: () => tz.getLocation('UTC'),
      );
      tz.setLocalLocation(match);
    }
  }

  Future<void> _onResponse(NotificationResponse response) async {
    final payload = ReminderNotificationPayload.tryDecode(response.payload);
    if (payload == null) return;
    // actionId is null on a plain tap (treat as "open").
    final actionId = response.actionId ?? NotificationActionIds.open;
    await _actionHandler?.call(actionId, payload);
  }

  /// Replays actions that were queued by [notificationBackgroundHandler] while
  /// the app was killed, then clears the queue. Call once at boot, after
  /// [init].
  Future<void> drainPendingActions() async {
    final handler = _actionHandler;
    if (handler == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _pendingActionsFileName));
      if (!await file.exists()) return;
      final lines = await file.readAsLines();
      await file.delete();
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final entry = jsonDecode(line) as Map<String, dynamic>;
        final payload =
            ReminderNotificationPayload.tryDecode(entry['payload'] as String?);
        if (payload == null) continue;
        await handler(entry['actionId'] as String, payload);
      }
    } catch (_) {
      // A malformed queue must never block app startup.
    }
  }

  /// If the app was launched by tapping a notification (cold start), returns
  /// that notification's action + payload so the caller can act on it.
  Future<void> handleAppLaunchNotification() async {
    final handler = _actionHandler;
    if (handler == null) return;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return;
    final payload =
        ReminderNotificationPayload.tryDecode(details.notificationResponse?.payload);
    if (payload == null) return;
    final actionId =
        details.notificationResponse?.actionId ?? NotificationActionIds.open;
    await handler(actionId, payload);
  }

  /// Requests notification permission. Call this lazily, right before the user
  /// schedules their first reminder — not at app launch.
  ///
  /// On Android 12+ this also asks for the exact-alarm permission, without
  /// which the OS silently downgrades scheduled reminders to inexact windows.
  Future<bool> requestPermission() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? false;
      // Best-effort: the user can decline exact alarms and still get reminders,
      // just with OS-chosen slack around the fire time.
      await android?.requestExactAlarmsPermission();
      return granted;
    }

    return false;
  }

  /// Creates (idempotently) the Android channel used for a given sound name.
  /// Android >= 8 takes the sound from the channel, not the notification, so a
  /// custom sound needs its own channel.
  Future<String> _ensureChannel(String sound) async {
    final channelId =
        sound == 'default' ? _defaultChannelId : '${_defaultChannelId}_$sound';
    if (!Platform.isAndroid || _createdChannels.contains(channelId)) {
      return channelId;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(AndroidNotificationChannel(
      channelId,
      sound == 'default' ? _channelName : '$_channelName ($sound)',
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      sound: sound == 'default'
          ? null
          : RawResourceAndroidNotificationSound(sound),
    ));
    _createdChannels.add(channelId);
    return channelId;
  }

  Future<NotificationDetails> _details({
    required String sound,
    required bool vibration,
  }) async {
    final channelId = await _ensureChannel(sound);
    return NotificationDetails(
      iOS: DarwinNotificationDetails(
        categoryIdentifier: _reminderCategoryId,
        sound: sound == 'default' ? null : '$sound.caf',
        presentSound: true,
        presentAlert: true,
        presentBadge: true,
      ),
      macOS: DarwinNotificationDetails(
        categoryIdentifier: _reminderCategoryId,
        sound: sound == 'default' ? null : '$sound.caf',
      ),
      android: AndroidNotificationDetails(
        channelId,
        sound == 'default' ? _channelName : '$_channelName ($sound)',
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: vibration,
        category: AndroidNotificationCategory.reminder,
        sound: sound == 'default'
            ? null
            : RawResourceAndroidNotificationSound(sound),
        // showsUserInterface on every action for the same reason as iOS
        // above: only the UI isolate can update SQLite and arm the next
        // occurrence.
        actions: const [
          AndroidNotificationAction(
            NotificationActionIds.complete,
            'Complete',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotificationActionIds.snooze,
            'Snooze',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotificationActionIds.open,
            'Open',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
    );
  }

  /// Schedules (or reschedules — this call is idempotent per notificationId)
  /// a single local notification. Returns false if the time was in the past
  /// and nothing was scheduled.
  Future<bool> scheduleOneTime({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required ReminderNotificationPayload payload,
    String sound = 'default',
    bool vibration = true,
  }) async {
    // Cancelling first guarantees idempotency: calling this twice for the
    // same reminder never produces duplicate notifications.
    await _plugin.cancel(notificationId);

    final tzTime = tz.TZDateTime.from(scheduledAt, tz.local);
    if (!tzTime.isAfter(tz.TZDateTime.now(tz.local))) {
      // Never schedule in the past; the caller is responsible for rolling a
      // recurring reminder forward to its next future occurrence.
      return false;
    }

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body.isEmpty ? null : body,
      tzTime,
      await _details(sound: sound, vibration: vibration),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload.encode(),
    );
    return true;
  }

  /// Schedules a recurring notification using flutter_local_notifications'
  /// native repeat matching (fires reliably even if the app is killed).
  /// For 'weekly on multiple weekdays' and 'custom every N days', the
  /// ReminderService instead computes the next single occurrence and calls
  /// [scheduleOneTime] again once that occurrence fires/completes.
  Future<void> scheduleRecurring({
    required int notificationId,
    required String title,
    required String body,
    required DateTime firstOccurrence,
    required DateTimeComponents matchComponents,
    required ReminderNotificationPayload payload,
    String sound = 'default',
    bool vibration = true,
  }) async {
    await _plugin.cancel(notificationId);

    // A `matchDateTimeComponents` schedule whose anchor is in the past is
    // rejected on some platforms — roll the anchor forward first.
    var tzTime = tz.TZDateTime.from(firstOccurrence, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    while (!tzTime.isAfter(now)) {
      tzTime = _advanceAnchor(tzTime, matchComponents);
    }

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body.isEmpty ? null : body,
      tzTime,
      await _details(sound: sound, vibration: vibration),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload.encode(),
      matchDateTimeComponents: matchComponents,
    );
  }

  tz.TZDateTime _advanceAnchor(
    tz.TZDateTime anchor,
    DateTimeComponents components,
  ) {
    switch (components) {
      case DateTimeComponents.time:
        return anchor.add(const Duration(days: 1));
      case DateTimeComponents.dayOfWeekAndTime:
        return anchor.add(const Duration(days: 7));
      case DateTimeComponents.dayOfMonthAndTime:
        return tz.TZDateTime(
          tz.local,
          anchor.month == 12 ? anchor.year + 1 : anchor.year,
          anchor.month == 12 ? 1 : anchor.month + 1,
          anchor.day,
          anchor.hour,
          anchor.minute,
        );
      case DateTimeComponents.dateAndTime:
        return tz.TZDateTime(
          tz.local,
          anchor.year + 1,
          anchor.month,
          anchor.day,
          anchor.hour,
          anchor.minute,
        );
    }
  }

  Future<void> cancel(int notificationId) => _plugin.cancel(notificationId);

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();
}
