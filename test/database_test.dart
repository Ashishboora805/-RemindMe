import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_notes/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Projects', () {
    test('create and fetch a project', () async {
      final now = DateTime.now();
      await db.projectsDao.insertProject(ProjectsCompanion.insert(
        id: 'p1',
        name: 'Work',
        color: 0xFF6C63FF,
        createdAt: now,
        updatedAt: now,
      ));
      final project = await db.projectsDao.getById('p1');
      expect(project, isNotNull);
      expect(project!.name, 'Work');
    });

    test('update a project', () async {
      final now = DateTime.now();
      await db.projectsDao.insertProject(ProjectsCompanion.insert(
        id: 'p1',
        name: 'Work',
        color: 0xFF6C63FF,
        createdAt: now,
        updatedAt: now,
      ));
      final project = (await db.projectsDao.getById('p1'))!;
      await db.projectsDao.updateProject(project.copyWith(name: 'Personal').toCompanion(true));
      final updated = await db.projectsDao.getById('p1');
      expect(updated!.name, 'Personal');
    });

    test('archive and delete a project', () async {
      final now = DateTime.now();
      await db.projectsDao.insertProject(ProjectsCompanion.insert(
        id: 'p1',
        name: 'Work',
        color: 0xFF6C63FF,
        createdAt: now,
        updatedAt: now,
      ));
      await db.projectsDao.setArchived('p1', true);
      final archived = await db.projectsDao.watchArchivedProjects().first;
      expect(archived.length, 1);

      await db.projectsDao.deleteProject('p1');
      final gone = await db.projectsDao.getById('p1');
      expect(gone, isNull);
    });
  });

  group('Notes', () {
    Future<String> seedProject() async {
      final now = DateTime.now();
      await db.projectsDao.insertProject(ProjectsCompanion.insert(
        id: 'p1',
        name: 'Work',
        color: 0xFF6C63FF,
        createdAt: now,
        updatedAt: now,
      ));
      return 'p1';
    }

    test('create, update, soft-delete, restore, permanently delete a note', () async {
      final projectId = await seedProject();
      final now = DateTime.now();
      await db.notesDao.insertNote(NotesCompanion.insert(
        id: 'n1',
        projectId: projectId,
        title: const Value('Groceries'),
        createdAt: now,
        updatedAt: now,
      ));

      var note = await db.notesDao.getById('n1');
      expect(note!.title, 'Groceries');

      await db.notesDao.updateFields('n1', NotesCompanion(content: Value('Milk, eggs')));
      note = await db.notesDao.getById('n1');
      expect(note!.content, 'Milk, eggs');

      await db.notesDao.softDelete('n1');
      note = await db.notesDao.getById('n1');
      expect(note!.isDeleted, true);

      await db.notesDao.restore('n1');
      note = await db.notesDao.getById('n1');
      expect(note!.isDeleted, false);

      await db.notesDao.permanentlyDelete('n1');
      note = await db.notesDao.getById('n1');
      expect(note, isNull);
    });

    test('deleting a project cascades to its notes', () async {
      final projectId = await seedProject();
      final now = DateTime.now();
      await db.notesDao.insertNote(NotesCompanion.insert(
        id: 'n1',
        projectId: projectId,
        createdAt: now,
        updatedAt: now,
      ));
      await db.projectsDao.deleteProject(projectId);
      final note = await db.notesDao.getById('n1');
      expect(note, isNull);
    });
  });

  group('Reminders', () {
    Future<String> seedProject() async {
      final now = DateTime.now();
      await db.projectsDao.insertProject(ProjectsCompanion.insert(
        id: 'p1',
        name: 'Work',
        color: 0xFF6C63FF,
        createdAt: now,
        updatedAt: now,
      ));
      return 'p1';
    }

    test('create and complete a reminder', () async {
      final projectId = await seedProject();
      final now = DateTime.now();
      await db.remindersDao.insertReminder(RemindersCompanion.insert(
        id: 'r1',
        projectId: projectId,
        title: 'Call dentist',
        scheduledAt: now.add(const Duration(hours: 1)),
        notificationId: 1234,
        createdAt: now,
        updatedAt: now,
      ));

      var reminder = await db.remindersDao.getById('r1');
      expect(reminder!.isCompleted, false);

      await db.remindersDao.markCompleted('r1', true);
      reminder = await db.remindersDao.getById('r1');
      expect(reminder!.isCompleted, true);
    });
  });
}

