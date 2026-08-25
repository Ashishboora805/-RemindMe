import 'package:drift/drift.dart';

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get icon => text().withDefault(const Constant('folder_fill'))();
  IntColumn get color => integer()(); // ARGB int
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
