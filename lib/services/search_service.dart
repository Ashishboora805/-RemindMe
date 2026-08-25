import 'package:drift/drift.dart';

import '../database/database.dart';

enum SearchResultType { project, note, reminder }

class SearchResult {
  final SearchResultType type;
  final String id;
  final String title;
  final String subtitle;
  final DateTime date;

  SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
  });
}

/// Offline search across projects, notes, and reminders (section 14).
/// Pure LIKE-based SQLite querying — no network, no indexing service.
class SearchService {
  SearchService(this._db);
  final AppDatabase _db;

  Future<List<SearchResult>> searchAll(String query) async {
    if (query.trim().isEmpty) return [];
    final like = '%${query.toLowerCase()}%';

    final projects = await (_db.select(_db.projects)
          ..where((p) => p.name.lower().like(like)))
        .get();
    final notes = await _db.notesDao.searchNotes(query);
    final reminders = await _db.remindersDao.searchReminders(query);

    return [
      ...projects.map((p) => SearchResult(
            type: SearchResultType.project,
            id: p.id,
            title: p.name,
            subtitle: p.description,
            date: p.updatedAt,
          )),
      ...notes.map((n) => SearchResult(
            type: SearchResultType.note,
            id: n.id,
            title: n.title.isEmpty ? '(untitled note)' : n.title,
            subtitle: n.content,
            date: n.updatedAt,
          )),
      ...reminders.map((r) => SearchResult(
            type: SearchResultType.reminder,
            id: r.id,
            title: r.title,
            subtitle: r.description,
            date: r.scheduledAt,
          )),
    ]..sort((a, b) => b.date.compareTo(a.date));
  }
}
