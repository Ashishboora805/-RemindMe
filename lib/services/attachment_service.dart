import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../database/tables/attachments_and_tags_tables.dart';

/// Copies picked/recorded files into the app's Documents directory (so they
/// survive app restarts and are included in ZIP backups) and records
/// metadata in SQLite. Raw bytes never go into the database (section 3/7).
class AttachmentService {
  AttachmentService(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  Future<Directory> _subDir(String name) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> imagesDir() => _subDir('attachments/images');
  Future<Directory> audioDir() => _subDir('attachments/audio');
  Future<Directory> filesDir() => _subDir('attachments/files');

  Future<Attachment> saveImage({
    required String noteId,
    required File sourceFile,
  }) async {
    final dir = await imagesDir();
    final ext = p.extension(sourceFile.path).isEmpty ? '.jpg' : p.extension(sourceFile.path);
    final fileName = '${_uuid.v4()}$ext';
    final destPath = p.join(dir.path, fileName);
    final copied = await sourceFile.copy(destPath);
    final size = await copied.length();

    final id = _uuid.v4();
    await _db.notesDao.insertAttachment(AttachmentsCompanion.insert(
      id: id,
      noteId: noteId,
      type: AttachmentType.image,
      fileName: fileName,
      filePath: copied.path,
      mimeType: _mimeForExt(ext),
      fileSize: size,
      createdAt: DateTime.now(),
    ));
    await _touchNote(noteId);
    return (await _db.notesDao.attachmentsForNote(noteId))
        .firstWhere((a) => a.id == id);
  }

  Future<Attachment> saveAudio({
    required String noteId,
    required File sourceFile,
    required int durationMs,
  }) async {
    final dir = await audioDir();
    final fileName = '${_uuid.v4()}.m4a';
    final destPath = p.join(dir.path, fileName);
    final copied = await sourceFile.copy(destPath);
    final size = await copied.length();

    final id = _uuid.v4();
    await _db.notesDao.insertAttachment(AttachmentsCompanion.insert(
      id: id,
      noteId: noteId,
      type: AttachmentType.audio,
      fileName: fileName,
      filePath: copied.path,
      mimeType: 'audio/m4a',
      duration: Value(durationMs),
      fileSize: size,
      createdAt: DateTime.now(),
    ));
    await _touchNote(noteId);
    return (await _db.notesDao.attachmentsForNote(noteId))
        .firstWhere((a) => a.id == id);
  }

  /// Attaching or removing a file is an edit to the note, so its `updatedAt`
  /// has to move — otherwise the note keeps its old position in the
  /// most-recently-edited ordering.
  Future<void> _touchNote(String noteId) => _db.notesDao.updateFields(
        noteId,
        NotesCompanion(updatedAt: Value(DateTime.now())),
      );

  /// Deletes both the DB row and the file on disk. Called from the note
  /// editor when the user removes an attachment, and from trash purge.
  Future<void> deleteAttachment(Attachment attachment) async {
    final file = File(attachment.filePath);
    if (await file.exists()) await file.delete();
    await _db.notesDao.deleteAttachment(attachment.id);
    await _touchNote(attachment.noteId);
  }

  Future<void> deleteAllAttachmentsForNote(String noteId) async {
    final list = await _db.notesDao.attachmentsForNote(noteId);
    for (final a in list) {
      await deleteAttachment(a);
    }
  }

  /// Total bytes used by attachments, for Settings > Storage.
  Future<int> totalStorageBytes() async {
    final dirs = await Future.wait([imagesDir(), audioDir(), filesDir()]);
    var total = 0;
    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) total += await entity.length();
      }
    }
    return total;
  }

  String _mimeForExt(String ext) {
    switch (ext.toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.heic':
        return 'image/heic';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
