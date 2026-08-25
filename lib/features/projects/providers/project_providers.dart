import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/core_providers.dart';
import '../../../database/database.dart';
import '../../../database/dao/projects_dao.dart';

const _uuid = Uuid();

final activeProjectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(databaseProvider).projectsDao.watchActiveProjects();
});

final archivedProjectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(databaseProvider).projectsDao.watchArchivedProjects();
});

final projectByIdProvider =
    StreamProvider.family<Project?, String>((ref, id) {
  return ref.watch(databaseProvider).projectsDao.watchById(id);
});

final projectStatsProvider =
    StreamProvider.family<ProjectStats, String>((ref, projectId) {
  return ref.watch(databaseProvider).projectsDao.watchStatsFor(projectId);
});

class ProjectController {
  ProjectController(this._db);
  final AppDatabase _db;

  Future<Project> create({
    required String name,
    String description = '',
    String icon = 'folder_fill',
    required int color,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.projectsDao.insertProject(ProjectsCompanion.insert(
      id: id,
      name: name,
      description: Value(description),
      icon: Value(icon),
      color: color,
      createdAt: now,
      updatedAt: now,
    ));
    return (await _db.projectsDao.getById(id))!;
  }

  Future<void> update(Project project) {
    return _db.projectsDao.updateProject(
      project.copyWith(updatedAt: DateTime.now()).toCompanion(true),
    );
  }

  Future<void> archive(String id, bool archived) =>
      _db.projectsDao.setArchived(id, archived);

  Future<void> delete(String id) => _db.projectsDao.deleteProject(id);
}

final projectControllerProvider = Provider<ProjectController>((ref) {
  return ProjectController(ref.watch(databaseProvider));
});
