import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../database/database.dart';
import '../../../services/reminder_service.dart';

final todayRemindersProvider = StreamProvider<List<Reminder>>((ref) {
  return ref.watch(databaseProvider).remindersDao.watchToday();
});

final reminderByIdProvider =
    StreamProvider.family<Reminder?, String>((ref, id) {
  return ref.watch(databaseProvider).remindersDao.watchById(id);
});

final remindersForProjectProvider =
    StreamProvider.family<List<Reminder>, String>((ref, projectId) {
  return ref.watch(databaseProvider).remindersDao.watchForProject(projectId);
});

final pendingRemindersForProjectProvider =
    StreamProvider.family<List<Reminder>, String>((ref, projectId) {
  return ref.watch(databaseProvider).remindersDao.watchPendingForProject(projectId);
});

final completedRemindersForProjectProvider =
    StreamProvider.family<List<Reminder>, String>((ref, projectId) {
  return ref.watch(databaseProvider).remindersDao.watchCompletedForProject(projectId);
});

/// UI-facing actions delegate straight to ReminderService — no scheduling
/// logic duplicated here (section 23/29).
class ReminderActions {
  ReminderActions(this._service);
  final ReminderService _service;

  Future<void> complete(String id) => _service.complete(id);
  Future<void> uncomplete(String id) => _service.uncomplete(id);
  Future<void> snooze(String id, Duration by) => _service.snooze(id, by);
  Future<void> cancel(String id) => _service.cancelReminder(id);
  Future<void> delete(String id) => _service.deleteReminder(id);
}

final reminderActionsProvider = Provider<ReminderActions>((ref) {
  return ReminderActions(ref.watch(reminderServiceProvider));
});
