import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../database/database.dart';
import '../../../services/attachment_service.dart';

final trashedNotesStreamProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(databaseProvider).notesDao.watchTrash();
});

/// Trash policy: items are permanently purged after 30 days (section 15).
const kTrashRetentionDays = 30;

class TrashController {
  TrashController(this._db, this._attachmentService);
  final AppDatabase _db;
  final AttachmentService _attachmentService;

  Future<void> restore(String noteId) => _db.notesDao.restore(noteId);

  Future<void> permanentlyDelete(String noteId) async {
    await _attachmentService.deleteAllAttachmentsForNote(noteId);
    await _db.notesDao.permanentlyDelete(noteId);
  }

  /// Call periodically (e.g. on app start) to auto-purge old trash.
  Future<void> purgeExpired() async {
    final cutoff = DateTime.now().subtract(const Duration(days: kTrashRetentionDays));
    final expired = await _db.notesDao.notesOlderThanInTrash(cutoff);
    for (final note in expired) {
      await permanentlyDelete(note.id);
    }
  }
}

final trashControllerProvider = Provider<TrashController>((ref) {
  return TrashController(
    ref.watch(databaseProvider),
    ref.watch(attachmentServiceProvider),
  );
});
