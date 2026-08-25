import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/colors.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../providers/trash_providers.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final trashedAsync = ref.watch(trashedNotesStreamProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Recently Deleted')),
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: trashedAsync.when(
            data: (notes) {
              if (notes.isEmpty) {
                return Center(
                  child: Text('Nothing in trash',
                      style: TextStyle(color: AppColors.textSecondary(brightness))),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: notes.length,
                itemBuilder: (context, i) {
                  final note = notes[i];
                  final daysLeft = note.deletedAt == null
                      ? 30
                      : 30 - DateTime.now().difference(note.deletedAt!).inDays;
                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note.title.isEmpty ? '(untitled note)' : note.title,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          'Deleted ${note.deletedAt != null ? DateFormat('MMM d').format(note.deletedAt!) : ''} · '
                          '$daysLeft days left',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary(brightness)),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GlassButton(
                                label: 'Restore',
                                style: GlassButtonStyle.secondary,
                                onPressed: () =>
                                    ref.read(trashControllerProvider).restore(note.id),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GlassButton(
                                label: 'Delete Forever',
                                style: GlassButtonStyle.destructive,
                                onPressed: () => _confirmPermanentDelete(context, ref, note.id),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ),
    );
  }

  void _confirmPermanentDelete(BuildContext context, WidgetRef ref, String noteId) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Forever?'),
        content: const Text('This cannot be undone. The note and its attachments will be permanently removed.'),
        actions: [
          CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(trashControllerProvider).permanentlyDelete(noteId);
            },
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }
}
