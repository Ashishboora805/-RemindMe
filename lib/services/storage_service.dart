import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'attachment_service.dart';

class StorageBreakdown {
  final int databaseBytes;
  final int imageBytes;
  final int audioBytes;
  final int cacheBytes;
  int get totalBytes => databaseBytes + imageBytes + audioBytes + cacheBytes;

  const StorageBreakdown({
    required this.databaseBytes,
    required this.imageBytes,
    required this.audioBytes,
    required this.cacheBytes,
  });
}

class StorageService {
  StorageService(this._attachmentService);
  final AttachmentService _attachmentService;

  Future<StorageBreakdown> computeBreakdown() async {
    final docs = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(docs.path, 'glass_notes.sqlite'));
    final dbSize = await dbFile.exists() ? await dbFile.length() : 0;

    final imagesDir = await _attachmentService.imagesDir();
    final audioDir = await _attachmentService.audioDir();

    final imageBytes = await _dirSize(imagesDir);
    final audioBytes = await _dirSize(audioDir);

    final tempDir = await getTemporaryDirectory();
    final cacheBytes = await _dirSize(tempDir);

    return StorageBreakdown(
      databaseBytes: dbSize,
      imageBytes: imageBytes,
      audioBytes: audioBytes,
      cacheBytes: cacheBytes,
    );
  }

  Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> clearCache() async {
    final tempDir = await getTemporaryDirectory();
    if (await tempDir.exists()) {
      await for (final entity in tempDir.list()) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {
          // Some cache files may be locked/in-use; skip and continue.
        }
      }
    }
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
