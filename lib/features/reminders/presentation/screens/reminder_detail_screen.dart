import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/glass_bottom_sheet.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/reminders_table.dart';
import '../../providers/reminder_providers.dart';

class ReminderDetailScreen extends ConsumerWidget {
  const ReminderDetailScreen({super.key, required this.reminderId});
  final String reminderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final reminderAsync = ref.watch(reminderByIdProvider(reminderId));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Reminder'),
        trailing: GestureDetector(
          onTap: () => context.push('/reminder/$reminderId/edit'),
          child: const Icon(CupertinoIcons.pencil),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: reminderAsync.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (reminder) {
              if (reminder == null) {
                return const Center(child: Text('Reminder not found'));
              }
              final overdue = !reminder.isCompleted &&
                  reminder.scheduledAt.isBefore(DateTime.now());

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(reminder.title,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(brightness))),
                  const SizedBox(height: 8),
                  if (reminder.description.isNotEmpty)
                    Text(reminder.description,
                        style: TextStyle(color: AppColors.textSecondary(brightness))),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Row(
                          icon: CupertinoIcons.calendar,
                          label: DateFormat('EEEE, MMM d · h:mm a')
                              .format(reminder.scheduledAt),
                          color: overdue ? AppColors.danger : null,
                        ),
                        const SizedBox(height: 10),
                        _Row(
                          icon: CupertinoIcons.repeat,
                          label: _repeatLabel(ref, reminder),
                        ),
                        const SizedBox(height: 10),
                        _Row(
                          icon: reminder.isCompleted
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.circle,
                          label: reminder.isCompleted
                              ? 'Completed'
                              : (overdue ? 'Overdue' : 'Pending'),
                          color: overdue ? AppColors.danger : null,
                        ),
                        if (!reminder.isActive) ...[
                          const SizedBox(height: 10),
                          const _Row(
                            icon: CupertinoIcons.bell_slash,
                            label: 'Notifications turned off',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!reminder.isCompleted) ...[
                    GlassButton(
                      label: reminder.repeatType == RepeatType.none
                          ? 'Mark Complete'
                          : 'Complete This Occurrence',
                      icon: CupertinoIcons.checkmark_alt,
                      expand: true,
                      onPressed: () async {
                        await ref
                            .read(reminderActionsProvider)
                            .complete(reminderId);
                        if (context.mounted &&
                            reminder.repeatType == RepeatType.none) {
                          context.pop();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    GlassButton(
                      label: 'Snooze',
                      icon: CupertinoIcons.clock,
                      style: GlassButtonStyle.secondary,
                      expand: true,
                      onPressed: () => _showSnoozeSheet(context, ref),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    GlassButton(
                      label: 'Mark Not Complete',
                      icon: CupertinoIcons.arrow_uturn_left,
                      style: GlassButtonStyle.secondary,
                      expand: true,
                      onPressed: () =>
                          ref.read(reminderActionsProvider).uncomplete(reminderId),
                    ),
                    const SizedBox(height: 12),
                  ],
                  GlassButton(
                    label: 'Delete Reminder',
                    icon: CupertinoIcons.delete,
                    style: GlassButtonStyle.destructive,
                    expand: true,
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Reminder?'),
        content: const Text(
            'This cancels its notification and removes it permanently.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(reminderActionsProvider).delete(reminderId);
              if (context.mounted) context.pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSnoozeSheet(BuildContext context, WidgetRef ref) {
    final options = <String, Duration>{
      '5 minutes': const Duration(minutes: 5),
      '10 minutes': const Duration(minutes: 10),
      '15 minutes': const Duration(minutes: 15),
      '30 minutes': const Duration(minutes: 30),
      '1 hour': const Duration(hours: 1),
    };
    showGlassBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: options.entries
            .map((e) => GlassCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref
                        .read(reminderActionsProvider)
                        .snooze(reminderId, e.value);
                  },
                  child: Text(e.key),
                ))
            .toList(),
      ),
    );
  }

  String _repeatLabel(WidgetRef ref, Reminder reminder) {
    switch (reminder.repeatType) {
      case RepeatType.daily:
        return 'Repeats daily';
      case RepeatType.weekly:
        final days = ref.read(reminderServiceProvider).weekdaysFor(reminder);
        return 'Repeats weekly on ${days.map(_weekdayName).join(', ')}';
      case RepeatType.monthly:
        return 'Repeats monthly';
      case RepeatType.custom:
        return 'Custom repeat';
      default:
        return 'Does not repeat';
    }
  }

  static String _weekdayName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1).clamp(0, 6)];
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: color))),
      ],
    );
  }
}
