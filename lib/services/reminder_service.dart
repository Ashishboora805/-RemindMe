import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show DateTimeComponents;
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/tables/reminders_table.dart';
import 'notification_service.dart';

/// Owns ALL recurrence math and notification (re)scheduling for reminders.
/// This is the single place that talks to both AppDatabase and
/// NotificationService for reminders — screens and providers must never
/// schedule notifications directly.
class ReminderService {
  ReminderService(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  /// Deterministic 32-bit id derived from the reminder's UUID, stable across
  /// app restarts so re-scheduling the same reminder never creates a
  /// second OS notification (idempotency requirement).
  int notificationIdFor(String reminderId) => reminderId.hashCode & 0x7FFFFFFF;

  Future<bool> ensurePermission() =>
      NotificationService.instance.requestPermission();

  /// Validates a reminder's proposed date/time. Returns an error string, or
  /// null if valid.
  String? validate({required DateTime scheduledAt, required String repeatType}) {
    if (repeatType == RepeatType.none &&
        scheduledAt.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
      return 'Reminder time must be in the future.';
    }
    return null;
  }

  /// Creates a reminder row and schedules its first OS notification.
  Future<Reminder> createReminder({
    required String projectId,
    String? noteId,
    required String title,
    String description = '',
    required DateTime scheduledAt,
    String repeatType = RepeatType.none,
    Map<String, dynamic>? repeatConfig,
    String priority = 'normal',
    String sound = 'default',
    bool vibration = true,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final companion = RemindersCompanion.insert(
      id: id,
      noteId: Value(noteId),
      projectId: projectId,
      title: title,
      description: Value(description),
      scheduledAt: scheduledAt,
      repeatType: Value(repeatType),
      repeatValue: Value(repeatConfig == null ? null : jsonEncode(repeatConfig)),
      priority: Value(priority),
      sound: Value(sound),
      vibration: Value(vibration),
      notificationId: notificationIdFor(id),
      createdAt: now,
      updatedAt: now,
    );
    await _db.remindersDao.insertReminder(companion);
    final reminder = (await _db.remindersDao.getById(id))!;
    await _scheduleOs(reminder);
    return reminder;
  }

  /// Applies edits to an existing reminder and re-arms its notification.
  Future<Reminder?> updateReminder({
    required String reminderId,
    String? title,
    String? description,
    DateTime? scheduledAt,
    String? repeatType,
    Map<String, dynamic>? repeatConfig,
    bool clearRepeatConfig = false,
    String? sound,
    bool? vibration,
  }) async {
    await _db.remindersDao.updateFields(
      reminderId,
      RemindersCompanion(
        title: title == null ? const Value.absent() : Value(title),
        description:
            description == null ? const Value.absent() : Value(description),
        scheduledAt:
            scheduledAt == null ? const Value.absent() : Value(scheduledAt),
        repeatType: repeatType == null ? const Value.absent() : Value(repeatType),
        repeatValue: clearRepeatConfig
            ? const Value(null)
            : (repeatConfig == null
                ? const Value.absent()
                : Value(jsonEncode(repeatConfig))),
        sound: sound == null ? const Value.absent() : Value(sound),
        vibration: vibration == null ? const Value.absent() : Value(vibration),
        updatedAt: Value(DateTime.now()),
      ),
    );
    final updated = await _db.remindersDao.getById(reminderId);
    if (updated != null) await _scheduleOs(updated);
    return updated;
  }

  /// Talks to NotificationService using the reminder's persisted data.
  /// Always cancels-then-schedules so calling this multiple times for the
  /// same reminder is a no-op beyond updating the fire time (idempotent).
  Future<void> _scheduleOs(Reminder input) async {
    if (!input.isActive || input.isCompleted) {
      await NotificationService.instance.cancel(input.notificationId);
      return;
    }

    var r = input;

    // A recurring reminder whose slot has already passed (app closed, device
    // off, occurrence never acted on) is rolled forward to its next future
    // slot, and the row is updated so the UI shows the real next fire time
    // rather than a date in the past.
    if (r.repeatType != RepeatType.none &&
        !r.scheduledAt.isAfter(DateTime.now())) {
      final next = nextOccurrenceAfter(r, DateTime.now());
      await _db.remindersDao.reschedule(r.id, next);
      r = r.copyWith(scheduledAt: next);
    }

    final payload = ReminderNotificationPayload(
      reminderId: r.id,
      noteId: r.noteId,
      projectId: r.projectId,
    );

    switch (r.repeatType) {
      case RepeatType.daily:
        await NotificationService.instance.scheduleRecurring(
          notificationId: r.notificationId,
          title: r.title,
          body: r.description,
          firstOccurrence: r.scheduledAt,
          matchComponents: DateTimeComponents.time,
          payload: payload,
          sound: r.sound,
          vibration: r.vibration,
        );
        return;

      case RepeatType.weekly:
        // A single weekday maps onto the OS's own weekly repeat. Multiple
        // weekdays (Mon/Wed/Fri) have no native equivalent, so they fall
        // through to the one-shot + advance-on-fire path below.
        if (weekdaysFor(r).length <= 1) {
          await NotificationService.instance.scheduleRecurring(
            notificationId: r.notificationId,
            title: r.title,
            body: r.description,
            firstOccurrence: r.scheduledAt,
            matchComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: payload,
            sound: r.sound,
            vibration: r.vibration,
          );
          return;
        }
        break;

      case RepeatType.monthly:
        await NotificationService.instance.scheduleRecurring(
          notificationId: r.notificationId,
          title: r.title,
          body: r.description,
          firstOccurrence: r.scheduledAt,
          matchComponents: DateTimeComponents.dayOfMonthAndTime,
          payload: payload,
          sound: r.sound,
          vibration: r.vibration,
        );
        return;
    }

    // One-time reminders, multi-weekday and custom cadences: schedule a single
    // occurrence. For the recurring ones, advanceRecurrence()/complete() arms
    // the next one. A one-time reminder already in the past is simply not
    // scheduled (scheduleOneTime returns false) and stays visible as overdue.
    await NotificationService.instance.scheduleOneTime(
      notificationId: r.notificationId,
      title: r.title,
      body: r.description,
      scheduledAt: r.scheduledAt,
      payload: payload,
      sound: r.sound,
      vibration: r.vibration,
    );
  }

  Map<String, dynamic>? _decodeConfig(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// The weekdays (DateTime.monday..DateTime.sunday) a weekly reminder fires
  /// on. Falls back to the weekday of its scheduled time.
  List<int> weekdaysFor(Reminder r) {
    final config = _decodeConfig(r.repeatValue);
    final raw = config?['weekdays'];
    if (raw is List && raw.isNotEmpty) {
      final days = raw.whereType<num>().map((d) => d.toInt()).toSet().toList()
        ..sort();
      if (days.isNotEmpty) return days;
    }
    return [r.scheduledAt.weekday];
  }

  /// Next fire time strictly after [from], preserving the reminder's
  /// time-of-day. Works for every repeat type; returns [from] unchanged for
  /// non-repeating reminders.
  DateTime nextOccurrenceAfter(Reminder r, DateTime from) {
    final base = r.scheduledAt;
    DateTime at(DateTime day) =>
        DateTime(day.year, day.month, day.day, base.hour, base.minute);

    switch (r.repeatType) {
      case RepeatType.daily:
        var next = at(from);
        while (!next.isAfter(from)) {
          next = at(next.add(const Duration(days: 1)));
        }
        return next;

      case RepeatType.weekly:
        final days = weekdaysFor(r);
        for (var i = 0; i <= 7; i++) {
          final candidate = at(from.add(Duration(days: i)));
          if (days.contains(candidate.weekday) && candidate.isAfter(from)) {
            return candidate;
          }
        }
        return at(from.add(const Duration(days: 7)));

      case RepeatType.monthly:
        var year = from.year;
        var month = from.month;
        for (var i = 0; i < 24; i++) {
          final daysInMonth = DateTime(year, month + 1, 0).day;
          final day = base.day > daysInMonth ? daysInMonth : base.day;
          final candidate =
              DateTime(year, month, day, base.hour, base.minute);
          if (candidate.isAfter(from)) return candidate;
          month++;
          if (month > 12) {
            month = 1;
            year++;
          }
        }
        return from.add(const Duration(days: 30));

      case RepeatType.custom:
        final config =
            _decodeConfig(r.repeatValue) ?? const {'unit': 'day', 'interval': 1};
        final unit = config['unit'] as String? ?? 'day';
        final interval = (config['interval'] as num?)?.toInt() ?? 1;
        final step = Duration(
            days: (unit == 'week' ? 7 : 1) * (interval < 1 ? 1 : interval));
        // Jump straight to the first slot after [from] so a reminder that was
        // missed for months doesn't cost a million loop iterations. The cadence
        // stays anchored to the originally chosen start date.
        var next = base;
        if (!next.isAfter(from)) {
          final skipped =
              from.difference(next).inMilliseconds ~/ step.inMilliseconds;
          next = next.add(step * skipped);
        }
        while (!next.isAfter(from)) {
          next = next.add(step);
        }
        return next;

      default:
        return from;
    }
  }

  /// Advances a recurring reminder to its next occurrence and re-arms the OS
  /// notification. Safe to call for any repeat type; one-time reminders are
  /// left alone.
  Future<void> advanceRecurrence(String reminderId) async {
    final r = await _db.remindersDao.getById(reminderId);
    if (r == null || r.repeatType == RepeatType.none) return;

    // Advance past whichever is later: the occurrence being handled, or now.
    // (They coincide when a reminder has just fired; they differ when the user
    // completes an upcoming occurrence early.)
    final now = DateTime.now();
    final from = r.scheduledAt.isAfter(now) ? r.scheduledAt : now;
    final next = nextOccurrenceAfter(r, from);
    await _db.remindersDao.reschedule(reminderId, next);
    final updated = await _db.remindersDao.getById(reminderId);
    if (updated != null) await _scheduleOs(updated);
  }

  /// Snooze: cancels the current notification, computes the new time,
  /// persists it, and re-schedules.
  Future<void> snooze(String reminderId, Duration by) async {
    final r = await _db.remindersDao.getById(reminderId);
    if (r == null) return;
    await NotificationService.instance.cancel(r.notificationId);

    final newTime = DateTime.now().add(by);
    await _db.remindersDao.reschedule(reminderId, newTime);

    await NotificationService.instance.scheduleOneTime(
      notificationId: r.notificationId,
      title: r.title,
      body: r.description,
      scheduledAt: newTime,
      payload: ReminderNotificationPayload(
        reminderId: r.id,
        noteId: r.noteId,
        projectId: r.projectId,
      ),
      sound: r.sound,
      vibration: r.vibration,
    );
  }

  /// Marks a one-time reminder done, or rolls a recurring one forward to its
  /// next occurrence (and re-arms it).
  Future<void> complete(String reminderId) async {
    final r = await _db.remindersDao.getById(reminderId);
    if (r == null) return;
    await NotificationService.instance.cancel(r.notificationId);
    if (r.repeatType == RepeatType.none) {
      await _db.remindersDao.markCompleted(reminderId, true);
    } else {
      await advanceRecurrence(reminderId);
    }
  }

  /// Re-opens a completed one-time reminder.
  Future<void> uncomplete(String reminderId) async {
    await _db.remindersDao.markCompleted(reminderId, false);
    final r = await _db.remindersDao.getById(reminderId);
    if (r != null) await _scheduleOs(r);
  }

  /// Deactivates a reminder and cancels its notification, keeping the row.
  Future<void> cancelReminder(String reminderId) async {
    final r = await _db.remindersDao.getById(reminderId);
    if (r == null) return;
    await NotificationService.instance.cancel(r.notificationId);
    await _db.remindersDao.setActive(reminderId, false);
  }

  /// Deletes a reminder outright, cancelling its notification first.
  Future<void> deleteReminder(String reminderId) async {
    final r = await _db.remindersDao.getById(reminderId);
    if (r == null) return;
    await NotificationService.instance.cancel(r.notificationId);
    await _db.remindersDao.deleteReminder(reminderId);
  }

  /// Called once at app boot. Re-arms OS notifications for every active,
  /// non-completed reminder — required because a device restart or app
  /// reinstall clears the OS notification queue on some platforms, and this
  /// call is safe to run redundantly (idempotent).
  ///
  /// A one-time reminder whose time has already passed is left as-is — the UI
  /// shows it as overdue and the user decides what to do with it.
  Future<void> rescheduleAllActiveOnBoot() async {
    final active = await _db.remindersDao.allActive();
    final now = DateTime.now();
    for (final r in active) {
      if (r.repeatType == RepeatType.none && !r.scheduledAt.isAfter(now)) {
        continue;
      }
      await _scheduleOs(r);
    }
  }
}
