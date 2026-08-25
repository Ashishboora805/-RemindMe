import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'core/providers/core_providers.dart';
import 'features/trash/providers/trash_providers.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Wire the OS notification action handler (Complete/Snooze/Open) straight
  // into ReminderService, independent of whether any screen is open. Guarded:
  // if the notification subsystem is unavailable, the notes app itself must
  // still open — reminders are in SQLite either way.
  await _guard(() => NotificationService.instance.init(
        onAction: (actionId, payload) async {
          final reminderService = container.read(reminderServiceProvider);
          switch (actionId) {
            case NotificationActionIds.complete:
              await reminderService.complete(payload.reminderId);
              break;
            case NotificationActionIds.snooze:
              await reminderService.snooze(
                payload.reminderId,
                const Duration(minutes: 10),
              );
              break;
            case NotificationActionIds.open:
            default:
              // Deep-link handling: the root widget listens for this and
              // navigates once the router is ready — see app.dart.
              container.read(pendingDeepLinkProvider.notifier).state =
                  payload.noteId != null && payload.noteId!.isNotEmpty
                      ? '/note/${payload.noteId}'
                      : '/reminder/${payload.reminderId}';
              break;
          }
        },
      ));

  // Determine whether the lock screen should gate the very first frame. This
  // is the only boot step the first frame actually depends on.
  try {
    final appLockEnabled =
        await container.read(authenticationServiceProvider).isAppLockEnabled();
    container.read(needsUnlockProvider.notifier).state = appLockEnabled;
  } catch (_) {
    // Keychain unavailable (e.g. first run on a fresh simulator): stay unlocked
    // rather than locking the user out of their own offline data.
  }

  // Everything below touches disk and must never keep the app from starting.
  unawaited(_runBootTasks(container));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const GlassNotesApp(),
    ),
  );
}

/// Boot housekeeping that runs alongside the first frame. Each step is
/// independently guarded so one failure doesn't skip the rest.
Future<void> _runBootTasks(ProviderContainer container) async {
  // Actions the user took while the app process was dead (Android delivers
  // these to a background isolate that cannot touch our database).
  await _guard(() => NotificationService.instance.drainPendingActions());

  // Re-arm every active reminder's OS notification (covers device restarts /
  // reinstalls where the OS notification queue may be cleared). Idempotent.
  await _guard(
      () => container.read(reminderServiceProvider).rescheduleAllActiveOnBoot());

  // Enforce the 30-day trash retention policy.
  await _guard(() => container.read(trashControllerProvider).purgeExpired());

  // If the app was cold-launched by tapping a notification, act on it now that
  // the handler is registered.
  await _guard(
      () => NotificationService.instance.handleAppLaunchNotification());
}

Future<void> _guard(Future<void> Function() task) async {
  try {
    await task();
  } catch (error, stack) {
    debugPrint('Boot task failed: $error\n$stack');
  }
}
