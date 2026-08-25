import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:glass_notes/database/database.dart';
import 'package:glass_notes/services/attachment_service.dart';
import 'package:glass_notes/services/backup_service.dart';
import 'package:glass_notes/services/reminder_service.dart';

// path_provider has no real platform implementation in `flutter test`, so
// AttachmentService/BackupService calls that resolve app directories are
// stubbed to a temp folder for the duration of these tests.
void _stubPathProvider(Directory tempRoot) {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => tempRoot.path);
}

void main() {
  late Directory tempRoot;
  late AppDatabase db;
  late AttachmentService attachmentService;
  late BackupService backupService;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('glass_notes_backup_test');
    _stubPathProvider(tempRoot);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    attachmentService = AttachmentService(db);
    backupService = BackupService(db, attachmentService, ReminderService(db));

    final now = DateTime.now();
    await db.projectsDao.insertProject(ProjectsCompanion.insert(
      id: 'p1',
      name: 'Work',
      color: 0xFF6C63FF,
      createdAt: now,
      updatedAt: now,
    ));
  });

  tearDown(() async {
    await db.close();
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  test('export produces a non-empty zip file', () async {
    final file = await backupService.exportBackup();
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(0));
  });

  test('import rejects a file that is not a valid zip', () async {
    final badFile = File(p.join(tempRoot.path, 'not_a_backup.zip'));
    await badFile.writeAsBytes([1, 2, 3, 4]);

    expect(
      () => backupService.importBackup(badFile, strategy: RestoreStrategy.merge),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('export then import (replace) round-trips project data', () async {
    final file = await backupService.exportBackup();
    await db.delete(db.projects).go();
    expect(await db.projectsDao.getById('p1'), isNull);

    await backupService.importBackup(file, strategy: RestoreStrategy.replace);
    final restored = await db.projectsDao.getById('p1');
    expect(restored, isNotNull);
    expect(restored!.name, 'Work');
  });

  test('merge import does not duplicate an existing project row', () async {
    final file = await backupService.exportBackup();
    // Project 'p1' still exists locally; merge should insertOrIgnore it.
    await backupService.importBackup(file, strategy: RestoreStrategy.merge);
    final all = await db.select(db.projects).get();
    expect(all.where((p) => p.id == 'p1').length, 1);
  });
}
