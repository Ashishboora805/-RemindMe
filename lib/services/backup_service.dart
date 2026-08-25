import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show InsertMode;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/database.dart';
import 'attachment_service.dart';
import 'reminder_service.dart';

const int kBackupFormatVersion = 1;

enum RestoreStrategy { merge, replace }

class BackupValidationException implements Exception {
  final String message;
  BackupValidationException(this.message);
  @override
  String toString() => message;
}

/// Exports/imports a self-contained ZIP: database.json + backup_info.json +
/// attachments/ + audio/ (section 16). Restore never touches the live
/// database until the archive has been fully validated.
class BackupService {
  BackupService(this._db, this._attachmentService, this._reminderService);
  final AppDatabase _db;
  final AttachmentService _attachmentService;
  final ReminderService _reminderService;

  Future<File> exportBackup() async {
    final projects = await _db.select(_db.projects).get();
    final notes = await _db.select(_db.notes).get();
    final reminders = await _db.select(_db.reminders).get();
    final attachments = await _db.select(_db.attachments).get();
    final tags = await _db.select(_db.tags).get();
    final noteTags = await _db.select(_db.noteTags).get();

    final dbJson = {
      'projects': projects.map((r) => r.toJson()).toList(),
      'notes': notes.map((r) => r.toJson()).toList(),
      'reminders': reminders.map((r) => r.toJson()).toList(),
      'attachments': attachments.map((r) => r.toJson()).toList(),
      'tags': tags.map((r) => r.toJson()).toList(),
      'noteTags': noteTags.map((r) => r.toJson()).toList(),
    };

    final backupInfo = {
      'formatVersion': kBackupFormatVersion,
      'schemaVersion': kSchemaVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'appName': 'Glass Notes',
    };

    final archive = Archive();
    archive.addFile(_jsonEntry('database.json', dbJson));
    archive.addFile(_jsonEntry('backup_info.json', backupInfo));

    for (final a in attachments) {
      final file = File(a.filePath);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final folder = a.type == 'audio' ? 'audio' : 'attachments';
      archive.addFile(ArchiveFile('$folder/${a.fileName}', bytes.length, bytes));
    }

    final zipBytes = ZipEncoder().encode(archive);
    final outDir = await getApplicationDocumentsDirectory();
    final outFile = File(p.join(
      outDir.path,
      'GlassNotesBackup_${DateTime.now().millisecondsSinceEpoch}.zip',
    ));
    await outFile.writeAsBytes(zipBytes!);
    return outFile;
  }

  ArchiveFile _jsonEntry(String name, Object data) {
    final bytes = utf8.encode(jsonEncode(data));
    return ArchiveFile(name, bytes.length, bytes);
  }

  /// Validates + restores a backup ZIP. Caller must confirm merge/replace
  /// with the user BEFORE calling this (section 27: never overwrite without
  /// confirmation) — this method assumes that confirmation already happened.
  Future<void> importBackup(File zipFile, {required RestoreStrategy strategy}) async {
    final bytes = await zipFile.readAsBytes();
    late Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw BackupValidationException('This file is not a valid backup archive.');
    }

    final infoFile = archive.findFile('backup_info.json');
    final dbFile = archive.findFile('database.json');
    if (infoFile == null || dbFile == null) {
      throw BackupValidationException('Backup is missing required files.');
    }

    final info = jsonDecode(utf8.decode(infoFile.content as List<int>)) as Map<String, dynamic>;
    final formatVersion = info['formatVersion'] as int? ?? 0;
    if (formatVersion > kBackupFormatVersion) {
      throw BackupValidationException(
        'This backup was created by a newer app version and cannot be restored.',
      );
    }

    final dbJson = jsonDecode(utf8.decode(dbFile.content as List<int>)) as Map<String, dynamic>;
    for (final key in ['projects', 'notes', 'reminders', 'attachments', 'tags', 'noteTags']) {
      if (dbJson[key] == null) {
        throw BackupValidationException('Backup database section "$key" is missing.');
      }
    }

    // Restore attachment files first, to their permanent directories.
    final imagesDir = await _attachmentService.imagesDir();
    final audioDir = await _attachmentService.audioDir();
    for (final entry in archive.files) {
      if (entry.name.startsWith('audio/')) {
        final dest = File(p.join(audioDir.path, p.basename(entry.name)));
        await dest.writeAsBytes(entry.content as List<int>);
      } else if (entry.name.startsWith('attachments/')) {
        final dest = File(p.join(imagesDir.path, p.basename(entry.name)));
        await dest.writeAsBytes(entry.content as List<int>);
      }
    }

    await _db.transaction(() async {
      if (strategy == RestoreStrategy.replace) {
        await _db.delete(_db.noteTags).go();
        await _db.delete(_db.tags).go();
        await _db.delete(_db.attachments).go();
        await _db.delete(_db.reminders).go();
        await _db.delete(_db.notes).go();
        await _db.delete(_db.projects).go();
      }

      // Merge strategy: insertOrIgnore keeps existing rows and adds new
      // ones by primary key, avoiding ID collisions/duplication.
      final mode = strategy == RestoreStrategy.merge
          ? InsertMode.insertOrIgnore
          : InsertMode.insertOrReplace;

      for (final row in (dbJson['projects'] as List)) {
        await _db.into(_db.projects).insert(
              Project.fromJson(row as Map<String, dynamic>).toCompanion(true),
              mode: mode,
            );
      }
      for (final row in (dbJson['notes'] as List)) {
        await _db.into(_db.notes).insert(
              Note.fromJson(row as Map<String, dynamic>).toCompanion(true),
              mode: mode,
            );
      }
      for (final row in (dbJson['attachments'] as List)) {
        await _db.into(_db.attachments).insert(
              Attachment.fromJson(row as Map<String, dynamic>).toCompanion(true),
              mode: mode,
            );
      }
      for (final row in (dbJson['tags'] as List)) {
        await _db.into(_db.tags).insert(
              Tag.fromJson(row as Map<String, dynamic>).toCompanion(true),
              mode: mode,
            );
      }
      for (final row in (dbJson['noteTags'] as List)) {
        await _db.into(_db.noteTags).insert(
              NoteTag.fromJson(row as Map<String, dynamic>).toCompanion(true),
              mode: mode,
            );
      }
      for (final row in (dbJson['reminders'] as List)) {
        await _db.into(_db.reminders).insert(
              Reminder.fromJson(row as Map<String, dynamic>).toCompanion(true),
              mode: mode,
            );
      }
    });

    // Re-arm OS notifications for everything that came back active.
    await _reminderService.rescheduleAllActiveOnBoot();
  }
}
