import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/projects_table.dart';
import '../tables/notes_table.dart';
import '../tables/reminders_table.dart';

part 'projects_dao.g.dart';

@DriftAccessor(tables: [Projects, Notes, Reminders])
class ProjectsDao extends DatabaseAccessor<AppDatabase> with _$ProjectsDaoMixin {
  ProjectsDao(super.db);

  Stream<List<Project>> watchActiveProjects() {
    return (select(projects)
          ..where((p) => p.isArchived.equals(false))
          ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]))
        .watch();
  }

  Stream<List<Project>> watchArchivedProjects() {
    return (select(projects)..where((p) => p.isArchived.equals(true))).watch();
  }

  Future<Project?> getById(String id) =>
      (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  Stream<Project?> watchById(String id) =>
      (select(projects)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<int> insertProject(ProjectsCompanion entry) => into(projects).insert(entry);

  Future<bool> updateProject(ProjectsCompanion entry) =>
      update(projects).replace(entry);

  Future<int> setArchived(String id, bool archived) {
    return (update(projects)..where((p) => p.id.equals(id))).write(
      ProjectsCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Hard delete a project and (via FK cascade) its notes/reminders/attachments.
  Future<int> deleteProject(String id) =>
      (delete(projects)..where((p) => p.id.equals(id))).go();

  /// Aggregate counts for a project's dashboard header.
  Future<ProjectStats> statsFor(String projectId) async {
    final noteCountQuery = selectOnly(notes)
      ..addColumns([notes.id.count()])
      ..where(notes.projectId.equals(projectId) & notes.isDeleted.equals(false));
    final noteCount = await noteCountQuery
        .map((row) => row.read(notes.id.count()) ?? 0)
        .getSingle();

    final pendingQuery = selectOnly(reminders)
      ..addColumns([reminders.id.count()])
      ..where(reminders.projectId.equals(projectId) &
          reminders.isCompleted.equals(false) &
          reminders.isActive.equals(true));
    final pending = await pendingQuery
        .map((row) => row.read(reminders.id.count()) ?? 0)
        .getSingle();

    final completedQuery = selectOnly(reminders)
      ..addColumns([reminders.id.count()])
      ..where(reminders.projectId.equals(projectId) & reminders.isCompleted.equals(true));
    final completed = await completedQuery
        .map((row) => row.read(reminders.id.count()) ?? 0)
        .getSingle();

    return ProjectStats(notesCount: noteCount, pendingReminders: pending, completedReminders: completed);
  }

  /// Live version of [statsFor]: re-runs the aggregates whenever a note or
  /// reminder row changes, so dashboard counters can't go stale.
  Stream<ProjectStats> watchStatsFor(String projectId) async* {
    yield await statsFor(projectId);
    final updates = tableUpdates(TableUpdateQuery.onAllTables([notes, reminders]));
    await for (final _ in updates) {
      yield await statsFor(projectId);
    }
  }
}

class ProjectStats {
  final int notesCount;
  final int pendingReminders;
  final int completedReminders;
  const ProjectStats({
    required this.notesCount,
    required this.pendingReminders,
    required this.completedReminders,
  });
}
