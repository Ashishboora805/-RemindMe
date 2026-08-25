import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/core_providers.dart';
import '../core/widgets/glass_button.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class LockGateScreen extends ConsumerWidget {
  const LockGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    return CupertinoPageScaffold(
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.lock_shield, size: 64),
                  const SizedBox(height: 20),
                  Text(
                    'Glass Notes is locked',
                    style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Authenticate to view your notes and reminders.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  GlassButton(
                    label: 'Unlock',
                    icon: CupertinoIcons.lock_open_fill,
                    expand: true,
                    onPressed: () async {
                      final ok =
                          await ref.read(authenticationServiceProvider).authenticate();
                      if (ok) {
                        ref.read(needsUnlockProvider.notifier).state = false;
                        if (context.mounted) context.go('/');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
