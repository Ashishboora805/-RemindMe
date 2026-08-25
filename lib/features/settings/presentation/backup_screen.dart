import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../services/backup_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  String? _status;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final file = await ref.read(backupServiceProvider).exportBackup();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/zip')],
          text: 'Glass Notes backup',
        ),
      );
      if (!mounted) return;
      setState(() => _status = 'Backup exported successfully.');
    } catch (e) {
      if (mounted) setState(() => _status = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Choose a Glass Notes backup',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null) return;

    if (!mounted) return;
    final strategy = await _askStrategy();
    if (strategy == null || !mounted) return;

    setState(() {
      _busy = true;
      _status = null;
    });

    File? scratch;
    try {
      // Android's picker hands back a content:// URI with no filesystem path,
      // so the bytes are copied into a temp file the backup service can open.
      final bytes = await picked.readAsBytes();
      final tempDir = await getTemporaryDirectory();
      scratch = File(p.join(
        tempDir.path,
        'restore_${DateTime.now().millisecondsSinceEpoch}.zip',
      ));
      await scratch.writeAsBytes(bytes, flush: true);

      await ref
          .read(backupServiceProvider)
          .importBackup(scratch, strategy: strategy);
      if (mounted) setState(() => _status = 'Backup restored successfully.');
    } on BackupValidationException catch (e) {
      if (mounted) setState(() => _status = 'Restore failed: ${e.message}');
    } catch (e) {
      if (mounted) setState(() => _status = 'Restore failed: $e');
    } finally {
      if (scratch != null && await scratch.exists()) {
        await scratch.delete();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<RestoreStrategy?> _askStrategy() {
    return showCupertinoDialog<RestoreStrategy>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'Merge keeps your current data and adds anything new from the backup. '
          'Replace erases current data and restores exactly what is in the backup.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            child: const Text('Merge'),
            onPressed: () => Navigator.pop(ctx, RestoreStrategy.merge),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Replace'),
            onPressed: () => Navigator.pop(ctx, RestoreStrategy.replace),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Backup & Restore')),
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Export Backup',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: AppColors.textPrimary(brightness))),
                    const SizedBox(height: 6),
                    Text(
                      'Creates a ZIP with your database, images, and voice recordings that you can save or share.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary(brightness)),
                    ),
                    const SizedBox(height: 14),
                    GlassButton(
                      label: 'Export & Share',
                      icon: CupertinoIcons.share,
                      onPressed: _busy ? null : _export,
                      expand: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Import Backup',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: AppColors.textPrimary(brightness))),
                    const SizedBox(height: 6),
                    Text(
                      'Choose a previously exported .zip file to restore.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary(brightness)),
                    ),
                    const SizedBox(height: 14),
                    GlassButton(
                      label: 'Choose File…',
                      icon: CupertinoIcons.tray_arrow_down,
                      style: GlassButtonStyle.secondary,
                      onPressed: _busy ? null : _import,
                      expand: true,
                    ),
                  ],
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: 20),
                const Center(child: CupertinoActivityIndicator()),
              ],
              if (_status != null) ...[
                const SizedBox(height: 16),
                Text(_status!, style: TextStyle(color: AppColors.textPrimary(brightness))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
