import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/reminders_table.dart';

part 'reminders_dao.g.dart';

@DriftAccessor(tables: [Reminders])
class RemindersDao extends DatabaseAccessor<AppDatabase> with _$RemindersDaoMixin {
  RemindersDao(super.db);

  Stream<List<Reminder>> watchForProject(String projectId) {
    return (select(reminders)
          ..where((r) => r.projectId.equals(projectId))
          ..orderBy([(r) => OrderingTerm.asc(r.scheduledAt)]))
        .watch();
  }

  Stream<List<Reminder>> watchPendingForProject(String projectId) {
    return (select(reminders)
          ..where((r) =>
              r.projectId.equals(projectId) &
              r.isCompleted.equals(false) &
              r.isActive.equals(true))
          ..orderBy([(r) => OrderingTerm.asc(r.scheduledAt)]))
        .watch();
  }

  Stream<List<Reminder>> watchCompletedForProject(String projectId) {
    return (select(reminders)
          ..where((r) => r.projectId.equals(projectId) & r.isCompleted.equals(true)))
        .watch();
  }

  /// All active reminders scheduled for today, across every project — used
  /// by the Home screen "Today" section.
  Stream<List<Reminder>> watchToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return (select(reminders)
          ..where((r) =>
              r.isActive.equals(true) &
              r.isCompleted.equals(false) &
              r.scheduledAt.isBetweenValues(start, end))
          ..orderBy([(r) => OrderingTerm.asc(r.scheduledAt)]))
        .watch();
  }

  /// All active (non-completed) reminders — used at app boot to
  /// reschedule OS notifications after a device restart / reinstall.
  Future<List<Reminder>> allActive() =>
      (select(reminders)..where((r) => r.isActive.equals(true) & r.isCompleted.equals(false)))
          .get();

  Future<List<Reminder>> forProject(String projectId) =>
      (select(reminders)..where((r) => r.projectId.equals(projectId))).get();

  Future<Reminder?> getById(String id) =>
      (select(reminders)..where((r) => r.id.equals(id))).getSingleOrNull();

  Stream<Reminder?> watchById(String id) =>
      (select(reminders)..where((r) => r.id.equals(id))).watchSingleOrNull();

  Future<int> insertReminder(RemindersCompanion entry) => into(reminders).insert(entry);

  Future<bool> updateReminder(RemindersCompanion entry) => update(reminders).replace(entry);

  /// Partial update — unlike [updateReminder] (full replace), this only writes
  /// the columns present in [partial].
  Future<int> updateFields(String id, RemindersCompanion partial) =>
      (update(reminders)..where((r) => r.id.equals(id))).write(partial);

  Future<int> markCompleted(String id, bool completed) =>
      (update(reminders)..where((r) => r.id.equals(id))).write(
        RemindersCompanion(isCompleted: Value(completed), updatedAt: Value(DateTime.now())),
      );

  Future<int> reschedule(String id, DateTime newTime) =>
      (update(reminders)..where((r) => r.id.equals(id))).write(
        RemindersCompanion(scheduledAt: Value(newTime), updatedAt: Value(DateTime.now())),
      );

  Future<int> setActive(String id, bool active) =>
      (update(reminders)..where((r) => r.id.equals(id)))
          .write(RemindersCompanion(isActive: Value(active)));

  Future<int> deleteReminder(String id) =>
      (delete(reminders)..where((r) => r.id.equals(id))).go();

  Future<List<Reminder>> searchReminders(String query) {
    final like = '%${query.toLowerCase()}%';
    return (select(reminders)..where((r) => r.title.lower().like(like))).get();
  }
}
