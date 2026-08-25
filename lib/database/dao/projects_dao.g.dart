// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'projects_dao.dart';

// ignore_for_file: type=lint
mixin _$ProjectsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProjectsTable get projects => attachedDatabase.projects;
  $NotesTable get notes => attachedDatabase.notes;
  $RemindersTable get reminders => attachedDatabase.reminders;
  ProjectsDaoManager get managers => ProjectsDaoManager(this);
}

class ProjectsDaoManager {
  final _$ProjectsDaoMixin _db;
  ProjectsDaoManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db.attachedDatabase, _db.projects);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db.attachedDatabase, _db.notes);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db.attachedDatabase, _db.reminders);
}
