import 'package:drift/drift.dart';
import 'notes_table.dart';

class AttachmentType {
  static const image = 'image';
  static const audio = 'audio';
  static const file = 'file';
}

class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get noteId =>
      text().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()();
  TextColumn get fileName => text()();
  TextColumn get filePath => text()();
  TextColumn get mimeType => text()();
  IntColumn get duration => integer().nullable()(); // ms, audio only
  IntColumn get fileSize => integer()(); // bytes
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  IntColumn get color => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class NoteTags extends Table {
  TextColumn get noteId =>
      text().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}
