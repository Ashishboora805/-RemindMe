import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/notes_table.dart';
import '../../../notes/providers/note_providers.dart';

class NoteCard extends ConsumerWidget {
  const NoteCard({super.key, required this.note});
  final Note note;

  IconData get _typeIcon {
    switch (note.type) {
      case NoteType.image:
        return CupertinoIcons.photo;
      case NoteType.voice:
        return CupertinoIcons.mic_fill;
      case NoteType.mixed:
        return CupertinoIcons.square_stack_3d_up_fill;
      case NoteType.text:
      default:
        return CupertinoIcons.doc_text;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push('/note/${note.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_typeIcon, size: 18, color: AppColors.textSecondary(brightness)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (note.isPinned) ...[
                      const Icon(CupertinoIcons.pin_fill, size: 13),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        note.title.isEmpty ? '(untitled note)' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(brightness)),
                      ),
                    ),
                    if (note.isFavorite)
                      const Icon(CupertinoIcons.heart_fill, size: 14, color: CupertinoColors.systemPink),
                  ],
                ),
                if (note.content.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textSecondary(brightness), fontSize: 13),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  DateFormat('MMM d, h:mm a').format(note.updatedAt),
                  style: TextStyle(color: AppColors.textSecondary(brightness), fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await ref.read(noteControllerProvider).togglePin(note.id, !note.isPinned);
            },
            child: Icon(
              note.isPinned ? CupertinoIcons.pin_fill : CupertinoIcons.pin,
              size: 18,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ],
      ),
    );
  }
}
