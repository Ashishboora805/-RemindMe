import 'package:drift/drift.dart';
import 'projects_table.dart';
import 'notes_table.dart';

/// repeatType values. repeatValue holds extra config as JSON-encoded text,
/// e.g. weekly -> {"weekdays":[1,3,5]}, custom -> {"unit":"day","interval":2}
class RepeatType {
  static const none = 'none';
  static const daily = 'daily';
  static const weekly = 'weekly';
  static const monthly = 'monthly';
  static const custom = 'custom';
}

class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get noteId =>
      text().nullable().references(Notes, #id, onDelete: KeyAction.setNull)();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get repeatType =>
      text().withDefault(const Constant(RepeatType.none))();
  TextColumn get repeatValue => text().nullable()(); // JSON config
  TextColumn get priority => text().withDefault(const Constant('normal'))();
  TextColumn get sound => text().withDefault(const Constant('default'))();
  BoolColumn get vibration => boolean().withDefault(const Constant(true))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  // Stable integer id used for the OS notification system (32-bit safe).
  IntColumn get notificationId => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
