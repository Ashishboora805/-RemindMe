import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/colors.dart';
import '../../providers/reminder_providers.dart';

class AlarmScreen extends ConsumerWidget {
  const AlarmScreen({super.key, required this.reminderId});

  final String reminderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness =
        CupertinoTheme.of(context).brightness ?? Brightness.light;
    final reminderAsync = ref.watch(reminderByIdProvider(reminderId));

    return CupertinoPageScaffold(
      child: Container(
        decoration:
            BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: reminderAsync.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (error, _) => Center(child: Text('Alarm error: $error')),
            data: (reminder) {
              if (reminder == null) {
                return const Center(child: Text('Reminder not found'));
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.alarm_fill,
                          size: 72, color: AppColors.danger),
                      const SizedBox(height: 28),
                      Text(
                        reminder.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                      if (reminder.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(reminder.description, textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 40),
                      CupertinoButton.filled(
                        onPressed: () async {
                          await ref
                              .read(reminderActionsProvider)
                              .complete(reminderId);
                          if (context.mounted) context.go('/');
                        },
                        child: const Text('Stop alarm'),
                      ),
                      const SizedBox(height: 12),
                      CupertinoButton(
                        onPressed: () async {
                          await ref
                              .read(reminderActionsProvider)
                              .snooze(
                                reminderId,
                                const Duration(minutes: 10),
                              );
                          if (context.mounted) context.go('/');
                        },
                        child: const Text('Snooze 10 minutes'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
