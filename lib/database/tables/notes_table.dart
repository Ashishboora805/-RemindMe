import 'package:drift/drift.dart';
import 'projects_table.dart';

/// Note type stored as text for readability & forward-compat migrations.
class NoteType {
  static const text = 'text';
  static const image = 'image';
  static const voice = 'voice';
  static const mixed = 'mixed';
}

class NotePriority {
  static const low = 'low';
  static const normal = 'normal';
  static const high = 'high';
}

class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get type => text().withDefault(const Constant(NoteType.text))();
  TextColumn get priority =>
      text().withDefault(const Constant(NotePriority.normal))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
