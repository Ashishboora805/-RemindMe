import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';

import 'tables/projects_table.dart';
import 'tables/notes_table.dart';
import 'tables/reminders_table.dart';
import 'tables/attachments_and_tags_tables.dart';
import 'dao/projects_dao.dart';
import 'dao/notes_dao.dart';
import 'dao/reminders_dao.dart';

part 'database.g.dart';

/// Current schema version. Bump this and add a migration step in
/// [_migration] whenever a table changes shape.
const int kSchemaVersion = 1;

@DriftDatabase(
  tables: [Projects, Notes, Reminders, Attachments, Tags, NoteTags],
  daos: [ProjectsDao, NotesDao, RemindersDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Used by tests to inject an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => kSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Example pattern for future migrations:
          // if (from < 2) {
          //   await m.addColumn(notes, notes.someNewColumn);
          // }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'glass_notes.sqlite'));

    // Older Android releases ship a broken system sqlite3; this makes the
    // bundled library from sqlite3_flutter_libs load instead. It is an
    // Android-only workaround.
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    // Give sqlite3 a writable scratch directory (Android's default is not).
    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;

    return NativeDatabase.createInBackground(file);
  });
}
