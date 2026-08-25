import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/core_providers.dart';
import '../../../database/database.dart';
import '../../../database/tables/notes_table.dart';

const _uuid = Uuid();

final notesForProjectProvider =
    StreamProvider.family<List<Note>, String>((ref, projectId) {
  return ref.watch(databaseProvider).notesDao.watchNotesForProject(projectId);
});

final favoriteNotesProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(databaseProvider).notesDao.watchFavorites();
});

final trashedNotesProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(databaseProvider).notesDao.watchTrash();
});

final noteByIdProvider = StreamProvider.family<Note?, String>((ref, id) {
  return ref.watch(databaseProvider).notesDao.watchById(id);
});

final attachmentsForNoteProvider =
    StreamProvider.family<List<Attachment>, String>((ref, noteId) {
  return ref.watch(databaseProvider).notesDao.watchAttachmentsForNote(noteId);
});

class NoteController {
  NoteController(this._db);
  final AppDatabase _db;

  Future<Note> create({
    required String projectId,
    String title = '',
    String content = '',
    String type = NoteType.text,
    String priority = NotePriority.normal,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.notesDao.insertNote(NotesCompanion.insert(
      id: id,
      projectId: projectId,
      title: Value(title),
      content: Value(content),
      type: Value(type),
      priority: Value(priority),
      createdAt: now,
      updatedAt: now,
    ));
    return (await _db.notesDao.getById(id))!;
  }

  /// Auto-save: updates title/content only, debounced by the caller (the
  /// editor screen), never blocks the UI thread noticeably given SQLite's
  /// speed for single-row writes.
  Future<void> autoSave(String noteId, {String? title, String? content}) {
    return _db.notesDao.updateFields(noteId, NotesCompanion(
      title: title == null ? const Value.absent() : Value(title),
      content: content == null ? const Value.absent() : Value(content),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> togglePin(String id, bool value) => _db.notesDao.setPinned(id, value);
  Future<void> toggleFavorite(String id, bool value) => _db.notesDao.setFavorite(id, value);
  Future<void> archive(String id, bool value) => _db.notesDao.setArchived(id, value);

  Future<void> softDelete(String id) => _db.notesDao.softDelete(id);
  Future<void> restore(String id) => _db.notesDao.restore(id);

  Future<void> permanentlyDelete(String id) async {
    // Attachments must be removed from disk by the caller via
    // AttachmentService.deleteAllAttachmentsForNote before calling this,
    // since cascade only removes DB rows, not files.
    await _db.notesDao.permanentlyDelete(id);
  }
}

final noteControllerProvider = Provider<NoteController>((ref) {
  return NoteController(ref.watch(databaseProvider));
});
