import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:glass_notes/database/database.dart';
import 'package:glass_notes/database/tables/reminders_table.dart';
import 'package:glass_notes/services/reminder_service.dart';

// NOTE: ReminderService talks to NotificationService, which talks to the
// flutter_local_notifications platform channel. On a bare `flutter test`
// (no device/simulator) that channel doesn't exist, so we stub it here to
// return empty/success responses — enough for these DB + recurrence-math
// tests to run without a MissingPluginException. This does NOT verify real
// notification delivery; that requires an integration test on a simulator
// or physical device (see README "Known iOS limitations").
void _stubNotificationChannels() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('UTC'));
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'initialize':
        return true;
      case 'pendingNotificationRequests':
        return <Map<dynamic, dynamic>>[];
      default:
        return null;
    }
  });
}

void main() {
  _stubNotificationChannels();
  late AppDatabase db;
  late ReminderService service;
  late String projectId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ReminderService(db);
    final now = DateTime.now();
    projectId = 'p1';
    await db.projectsDao.insertProject(ProjectsCompanion.insert(
      id: projectId,
      name: 'Test Project',
      color: 0xFF6C63FF,
      createdAt: now,
      updatedAt: now,
    ));
  });

  tearDown(() async => db.close());

  test('validate rejects a one-time reminder in the past', () {
    final error = service.validate(
      scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
      repeatType: RepeatType.none,
    );
    expect(error, isNotNull);
  });

  test('validate allows a recurring reminder even if the anchor time has passed today', () {
    final error = service.validate(
      scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
      repeatType: RepeatType.daily,
    );
    expect(error, isNull);
  });

  test('notificationIdFor is stable for the same reminder id', () {
    final a = service.notificationIdFor('abc-123');
    final b = service.notificationIdFor('abc-123');
    expect(a, equals(b));
  });

  test('advanceRecurrence moves a multi-weekday reminder to the next matching day', () async {
    // Anchor on a Monday (weekday == 1).
    final monday = DateTime(2026, 8, 24, 9, 0); // a Monday
    await db.remindersDao.insertReminder(RemindersCompanion.insert(
      id: 'r1',
      projectId: projectId,
      title: 'Gym',
      scheduledAt: monday,
      repeatType: const Value(RepeatType.weekly),
      repeatValue: const Value('{"weekdays":[1,3,5]}'),
      notificationId: 999,
      createdAt: monday,
      updatedAt: monday,
    ));

    await service.advanceRecurrence('r1');
    final updated = await db.remindersDao.getById('r1');
    // Next occurrence after Monday within {Mon, Wed, Fri} should be Wednesday.
    expect(updated!.scheduledAt.weekday, DateTime.wednesday);
  });

  test('complete() on a one-time reminder marks it completed permanently', () async {
    final now = DateTime.now();
    await db.remindersDao.insertReminder(RemindersCompanion.insert(
      id: 'r2',
      projectId: projectId,
      title: 'One-off task',
      scheduledAt: now.add(const Duration(minutes: 30)),
      notificationId: 1000,
      createdAt: now,
      updatedAt: now,
    ));
    await service.complete('r2');
    final reminder = await db.remindersDao.getById('r2');
    expect(reminder!.isCompleted, true);
  });

  test('complete() on a daily reminder does NOT mark it permanently completed', () async {
    final now = DateTime.now();
    await db.remindersDao.insertReminder(RemindersCompanion.insert(
      id: 'r3',
      projectId: projectId,
      title: 'Daily standup',
      scheduledAt: now.add(const Duration(minutes: 30)),
      repeatType: const Value(RepeatType.daily),
      notificationId: 1001,
      createdAt: now,
      updatedAt: now,
    ));
    await service.complete('r3');
    final reminder = await db.remindersDao.getById('r3');
    // Daily reminders have no manual-advance path (native matchComponents
    // handles recurrence), so completion here just leaves isCompleted false
    // and relies on the OS to refire — verify it wasn't force-completed.
    expect(reminder!.isCompleted, false);
  });

  test('snooze() reschedules to approximately now + duration', () async {
    final now = DateTime.now();
    await db.remindersDao.insertReminder(RemindersCompanion.insert(
      id: 'r4',
      projectId: projectId,
      title: 'Take a break',
      scheduledAt: now.add(const Duration(minutes: 5)),
      notificationId: 1002,
      createdAt: now,
      updatedAt: now,
    ));
    await service.snooze('r4', const Duration(minutes: 10));
    final reminder = await db.remindersDao.getById('r4');
    final expected = DateTime.now().add(const Duration(minutes: 10));
    expect(
      reminder!.scheduledAt.difference(expected).inSeconds.abs() < 5,
      isTrue,
    );
  });

  group('nextOccurrenceAfter', () {
    Reminder build({
      required DateTime scheduledAt,
      required String repeatType,
      String? repeatValue,
    }) {
      final now = DateTime(2026, 1, 1);
      return Reminder(
        id: 'x',
        projectId: 'p1',
        title: 'x',
        description: '',
        scheduledAt: scheduledAt,
        repeatType: repeatType,
        repeatValue: repeatValue,
        priority: 'normal',
        sound: 'default',
        vibration: true,
        isCompleted: false,
        isActive: true,
        notificationId: 1,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('daily keeps the original time of day', () {
      final r = build(
        scheduledAt: DateTime(2026, 3, 10, 7, 30),
        repeatType: RepeatType.daily,
      );
      final next = service.nextOccurrenceAfter(r, DateTime(2026, 3, 12, 9, 0));
      expect(next, DateTime(2026, 3, 13, 7, 30));
    });

    test('daily returns today when the time has not passed yet', () {
      final r = build(
        scheduledAt: DateTime(2026, 3, 10, 21, 0),
        repeatType: RepeatType.daily,
      );
      final next = service.nextOccurrenceAfter(r, DateTime(2026, 3, 12, 9, 0));
      expect(next, DateTime(2026, 3, 12, 21, 0));
    });

    test('multi-weekday walks through every selected day', () {
      final r = build(
        scheduledAt: DateTime(2026, 8, 24, 9, 0), // Monday
        repeatType: RepeatType.weekly,
        repeatValue: '{"weekdays":[1,3,5]}', // Mon, Wed, Fri
      );
      final wed = service.nextOccurrenceAfter(r, DateTime(2026, 8, 24, 9, 0));
      expect(wed, DateTime(2026, 8, 26, 9, 0));
      final fri = service.nextOccurrenceAfter(r, wed);
      expect(fri, DateTime(2026, 8, 28, 9, 0));
      // …and wraps around to the following Monday.
      expect(service.nextOccurrenceAfter(r, fri), DateTime(2026, 8, 31, 9, 0));
    });

    test('weekly with no config falls back to the anchor weekday', () {
      final r = build(
        scheduledAt: DateTime(2026, 8, 24, 9, 0), // Monday
        repeatType: RepeatType.weekly,
      );
      expect(service.weekdaysFor(r), [DateTime.monday]);
      expect(
        service.nextOccurrenceAfter(r, DateTime(2026, 8, 24, 9, 0)),
        DateTime(2026, 8, 31, 9, 0),
      );
    });

    test('monthly clamps to the last day of a shorter month', () {
      final r = build(
        scheduledAt: DateTime(2026, 1, 31, 8, 0),
        repeatType: RepeatType.monthly,
      );
      // February 2026 has 28 days.
      expect(
        service.nextOccurrenceAfter(r, DateTime(2026, 1, 31, 9, 0)),
        DateTime(2026, 2, 28, 8, 0),
      );
    });

    test('custom cadence stays anchored to the start date', () {
      final r = build(
        scheduledAt: DateTime(2026, 1, 1, 6, 0),
        repeatType: RepeatType.custom,
        repeatValue: '{"unit":"day","interval":3}',
      );
      // 1st, 4th, 7th, 10th … the first slot after the 8th is the 10th.
      expect(
        service.nextOccurrenceAfter(r, DateTime(2026, 1, 8, 12, 0)),
        DateTime(2026, 1, 10, 6, 0),
      );
    });

    test('custom cadence skips months of missed occurrences in one step', () {
      final r = build(
        scheduledAt: DateTime(2020, 1, 1, 6, 0),
        repeatType: RepeatType.custom,
        repeatValue: '{"unit":"week","interval":2}',
      );
      final next = service.nextOccurrenceAfter(r, DateTime(2026, 1, 8, 12, 0));
      expect(next.isAfter(DateTime(2026, 1, 8, 12, 0)), isTrue);
      // Still on the every-14-days grid that started in 2020.
      expect(next.difference(DateTime(2020, 1, 1, 6, 0)).inDays % 14, 0);
    });

    test('a one-time reminder is never advanced', () {
      final r = build(
        scheduledAt: DateTime(2026, 1, 1, 6, 0),
        repeatType: RepeatType.none,
      );
      final from = DateTime(2026, 5, 5, 5, 5);
      expect(service.nextOccurrenceAfter(r, from), from);
    });
  });

  test('advanceRecurrence rolls a daily reminder forward without completing it',
      () async {
    final anchor = DateTime.now().add(const Duration(minutes: 30));
    await db.remindersDao.insertReminder(RemindersCompanion.insert(
      id: 'r6',
      projectId: projectId,
      title: 'Standup',
      scheduledAt: anchor,
      repeatType: const Value(RepeatType.daily),
      notificationId: 1004,
      createdAt: anchor,
      updatedAt: anchor,
    ));

    await service.advanceRecurrence('r6');
    final updated = (await db.remindersDao.getById('r6'))!;
    expect(updated.isCompleted, false);
    expect(updated.scheduledAt.isAfter(anchor), isTrue);
    expect(updated.scheduledAt.difference(anchor).inHours, closeTo(24, 1));
  });

  test('cancelReminder() deactivates without deleting the row', () async {
    final now = DateTime.now();
    await db.remindersDao.insertReminder(RemindersCompanion.insert(
      id: 'r5',
      projectId: projectId,
      title: 'Cancel me',
      scheduledAt: now.add(const Duration(minutes: 5)),
      notificationId: 1003,
      createdAt: now,
      updatedAt: now,
    ));
    await service.cancelReminder('r5');
    final reminder = await db.remindersDao.getById('r5');
    expect(reminder, isNotNull);
    expect(reminder!.isActive, false);
  });
}
