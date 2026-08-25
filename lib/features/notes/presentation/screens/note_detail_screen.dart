import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart' show PlayerState, ProcessingState;

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/attachments_and_tags_tables.dart';
import '../../../../services/image_service.dart';
import '../../providers/note_providers.dart';

class NoteDetailScreen extends ConsumerWidget {
  const NoteDetailScreen({super.key, required this.noteId});
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final noteAsync = ref.watch(noteByIdProvider(noteId));
    final attachmentsAsync = ref.watch(attachmentsForNoteProvider(noteId));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Note'),
        trailing: GestureDetector(
          onTap: () => context.push('/note/$noteId/edit'),
          child: const Icon(CupertinoIcons.pencil),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: noteAsync.when(
            data: (note) {
              if (note == null) return const Center(child: Text('Note not found'));
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(note.title.isEmpty ? '(untitled note)' : note.title,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(brightness))),
                  const SizedBox(height: 8),
                  if (note.content.isNotEmpty)
                    Text(note.content,
                        style: TextStyle(fontSize: 16, color: AppColors.textPrimary(brightness))),
                  const SizedBox(height: 20),
                  attachmentsAsync.when(
                    data: (attachments) {
                      final images = attachments.where((a) => a.type == AttachmentType.image).toList();
                      final audios = attachments.where((a) => a.type == AttachmentType.audio).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (images.isNotEmpty) ...[
                            Text('Images',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary(brightness))),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: images
                                  .map((a) => GestureDetector(
                                        onTap: () => _openFullScreen(context, a.filePath),
                                        onLongPress: () =>
                                            _confirmDeleteAttachment(context, ref, a),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Image.file(
                                            File(a.filePath),
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 100,
                                              height: 100,
                                              color: AppColors.glassFill(brightness),
                                              child: const Icon(CupertinoIcons.photo),
                                            ),
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (audios.isNotEmpty) ...[
                            Text('Voice recordings',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary(brightness))),
                            const SizedBox(height: 10),
                            ...audios.map((a) => _AudioAttachmentTile(
                                  attachment: a,
                                  onDelete: () =>
                                      _confirmDeleteAttachment(context, ref, a),
                                )),
                          ],
                          if (images.isNotEmpty || audios.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Long-press an image, or use the trash icon on a '
                              'recording, to remove it.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary(brightness)),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _addImage(context, ref),
                                child: const Row(children: [
                                  Icon(CupertinoIcons.photo_on_rectangle, size: 18),
                                  SizedBox(width: 6),
                                  Text('Add image'),
                                ]),
                              ),
                              const SizedBox(width: 20),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => context.push('/note/$noteId/voice'),
                                child: const Row(children: [
                                  Icon(CupertinoIcons.mic, size: 18),
                                  SizedBox(width: 6),
                                  Text('Record voice'),
                                ]),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () => const CupertinoActivityIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ),
    );
  }

  Future<void> _addImage(BuildContext context, WidgetRef ref) async {
    final source = await showCupertinoModalPopup<ImageSourceChoice>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Add image'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, ImageSourceChoice.camera),
            child: const Text('Take Photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, ImageSourceChoice.gallery),
            child: const Text('Choose from Library'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (source == null) return;

    final imageService = ref.read(imageServiceProvider);
    final attachmentService = ref.read(attachmentServiceProvider);
    try {
      final List<File> files;
      if (source == ImageSourceChoice.camera) {
        final shot = await imageService.pickFromCamera();
        files = shot == null ? const [] : [shot];
      } else {
        files = await imageService.pickFromGallery();
      }
      for (final f in files) {
        await attachmentService.saveImage(noteId: noteId, sourceFile: f);
      }
    } catch (e) {
      if (!context.mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Could not add image'),
          content: Text('$e'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    }
  }

  void _confirmDeleteAttachment(
      BuildContext context, WidgetRef ref, Attachment attachment) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Remove attachment?'),
        content: const Text(
            'The file is deleted from this device and cannot be recovered.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(attachmentServiceProvider)
                  .deleteAttachment(attachment);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _openFullScreen(BuildContext context, String path) {
    Navigator.of(context).push(CupertinoPageRoute(
      fullscreenDialog: true,
      builder: (_) => CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        child: Stack(
          children: [
            Center(child: Image.file(File(path))),
            SafeArea(
              child: CupertinoButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(CupertinoIcons.xmark_circle_fill, color: CupertinoColors.white),
              ),
            ),
          ],
        ),
      ),
    ));
  }

}

String _durationLabel(int? ms) {
  if (ms == null) return 'Recording';
  final seconds = (ms / 1000).round();
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// A voice recording with a real play/pause toggle driven by the player's own
/// state stream, rather than a play button that gives no feedback.
class _AudioAttachmentTile extends ConsumerStatefulWidget {
  const _AudioAttachmentTile({required this.attachment, required this.onDelete});
  final Attachment attachment;
  final VoidCallback onDelete;

  @override
  ConsumerState<_AudioAttachmentTile> createState() =>
      _AudioAttachmentTileState();
}

class _AudioAttachmentTileState extends ConsumerState<_AudioAttachmentTile> {
  StreamSubscription<PlayerState>? _sub;
  bool _isThisPlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(audioServiceProvider).playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing &&
          state.processingState != ProcessingState.completed &&
          ref.read(audioServiceProvider).currentPath == widget.attachment.filePath;
      if (playing != _isThisPlaying) setState(() => _isThisPlaying = playing);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    final audio = ref.read(audioServiceProvider);
    try {
      if (_isThisPlaying) {
        await audio.pausePlayback();
      } else {
        await audio.playFile(widget.attachment.filePath);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not play this recording.');
      debugPrint('Audio playback failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: _toggle,
      child: Row(
        children: [
          Icon(_isThisPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error ?? _durationLabel(widget.attachment.duration),
              style: TextStyle(
                color: _error != null
                    ? AppColors.danger
                    : AppColors.textPrimary(brightness),
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.onDelete,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(CupertinoIcons.delete,
                  size: 18, color: AppColors.textSecondary(brightness)),
            ),
          ),
        ],
      ),
    );
  }
}
