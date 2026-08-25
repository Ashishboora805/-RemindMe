import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/notes_table.dart';
import '../tables/attachments_and_tags_tables.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [Notes, Attachments, Tags, NoteTags])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  Stream<List<Note>> watchNotesForProject(String projectId, {bool includeArchived = false}) {
    final query = select(notes)
      ..where((n) =>
          n.projectId.equals(projectId) &
          n.isDeleted.equals(false) &
          (includeArchived ? const Constant(true) : n.isArchived.equals(false)))
      ..orderBy([
        (n) => OrderingTerm.desc(n.isPinned),
        (n) => OrderingTerm.desc(n.updatedAt),
      ]);
    return query.watch();
  }

  Stream<List<Note>> watchFavorites() {
    return (select(notes)
          ..where((n) => n.isFavorite.equals(true) & n.isDeleted.equals(false)))
        .watch();
  }

  Stream<List<Note>> watchTrash() {
    return (select(notes)
          ..where((n) => n.isDeleted.equals(true))
          ..orderBy([(n) => OrderingTerm.desc(n.deletedAt)]))
        .watch();
  }

  Future<Note?> getById(String id) =>
      (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  /// Every note in a project, archived and trashed included. Used when a
  /// project is deleted, so no attachment file is left orphaned on disk.
  Future<List<Note>> allNotesForProject(String projectId) =>
      (select(notes)..where((n) => n.projectId.equals(projectId))).get();

  Stream<Note?> watchById(String id) =>
      (select(notes)..where((n) => n.id.equals(id))).watchSingleOrNull();

  Future<int> insertNote(NotesCompanion entry) => into(notes).insert(entry);

  Future<bool> updateNote(NotesCompanion entry) => update(notes).replace(entry);

  /// Partial update used for auto-save (title/content only) — unlike
  /// [updateNote] (full replace), this only touches the columns provided.
  Future<int> updateFields(String id, NotesCompanion partial) =>
      (update(notes)..where((n) => n.id.equals(id))).write(partial);

  Future<int> setPinned(String id, bool value) =>
      (update(notes)..where((n) => n.id.equals(id)))
          .write(NotesCompanion(isPinned: Value(value), updatedAt: Value(DateTime.now())));

  Future<int> setFavorite(String id, bool value) =>
      (update(notes)..where((n) => n.id.equals(id)))
          .write(NotesCompanion(isFavorite: Value(value), updatedAt: Value(DateTime.now())));

  Future<int> setArchived(String id, bool value) =>
      (update(notes)..where((n) => n.id.equals(id)))
          .write(NotesCompanion(isArchived: Value(value), updatedAt: Value(DateTime.now())));

  /// Soft delete: moves the note into Recently Deleted / trash.
  Future<int> softDelete(String id) => (update(notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<int> restore(String id) => (update(notes)..where((n) => n.id.equals(id))).write(
        const NotesCompanion(isDeleted: Value(false), deletedAt: Value(null)),
      );

  /// Permanently removes the note row; caller is responsible for deleting
  /// attachment files from disk beforehand (see AttachmentService).
  Future<int> permanentlyDelete(String id) =>
      (delete(notes)..where((n) => n.id.equals(id))).go();

  Future<List<Note>> notesOlderThanInTrash(DateTime cutoff) =>
      (select(notes)..where((n) => n.isDeleted.equals(true) & n.deletedAt.isSmallerThanValue(cutoff)))
          .get();

  Stream<List<Attachment>> watchAttachmentsForNote(String noteId) =>
      (select(attachments)..where((a) => a.noteId.equals(noteId))).watch();

  Future<int> insertAttachment(AttachmentsCompanion entry) =>
      into(attachments).insert(entry);

  Future<int> deleteAttachment(String id) =>
      (delete(attachments)..where((a) => a.id.equals(id))).go();

  Future<List<Attachment>> attachmentsForNote(String noteId) =>
      (select(attachments)..where((a) => a.noteId.equals(noteId))).get();

  // --- Tags -----------------------------------------------------------
  Stream<List<Tag>> watchAllTags() => select(tags).watch();

  Future<int> insertTag(TagsCompanion entry) => into(tags).insert(entry);

  Future<void> setTagsForNote(String noteId, List<String> tagIds) async {
    await (delete(noteTags)..where((nt) => nt.noteId.equals(noteId))).go();
    for (final tagId in tagIds) {
      await into(noteTags).insert(NoteTagsCompanion.insert(noteId: noteId, tagId: tagId));
    }
  }

  Future<List<Tag>> tagsForNote(String noteId) async {
    final query = select(tags).join([
      innerJoin(noteTags, noteTags.tagId.equalsExp(tags.id)),
    ])
      ..where(noteTags.noteId.equals(noteId));
    final rows = await query.get();
    return rows.map((r) => r.readTable(tags)).toList();
  }

  /// Full-text-ish offline search across title/content (case-insensitive LIKE).
  Future<List<Note>> searchNotes(String query) {
    final like = '%${query.toLowerCase()}%';
    return (select(notes)
          ..where((n) =>
              n.isDeleted.equals(false) &
              (n.title.lower().like(like) | n.content.lower().like(like))))
        .get();
  }
}
