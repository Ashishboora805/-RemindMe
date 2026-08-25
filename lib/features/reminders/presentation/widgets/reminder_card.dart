import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../database/database.dart';
import '../../providers/reminder_providers.dart';

class ReminderCard extends ConsumerWidget {
  const ReminderCard({super.key, required this.reminder});
  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final overdue = !reminder.isCompleted && reminder.scheduledAt.isBefore(DateTime.now());

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push('/reminder/${reminder.id}'),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ref.read(reminderActionsProvider).complete(reminder.id),
            child: Icon(
              reminder.isCompleted
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              size: 24,
              color: reminder.isCompleted
                  ? AppColors.success
                  : (overdue ? AppColors.danger : AppColors.textSecondary(brightness)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(brightness),
                    decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('MMM d, h:mm a').format(reminder.scheduledAt)}'
                  '${reminder.repeatType != 'none' ? ' · ${reminder.repeatType}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: overdue ? AppColors.danger : AppColors.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
          if (!reminder.isCompleted)
            GestureDetector(
              onTap: () => ref
                  .read(reminderActionsProvider)
                  .snooze(reminder.id, const Duration(minutes: 10)),
              child: Icon(CupertinoIcons.clock, size: 18, color: AppColors.textSecondary(brightness)),
            ),
        ],
      ),
    );
  }
}
