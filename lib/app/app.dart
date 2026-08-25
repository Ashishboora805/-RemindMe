import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/typography.dart';
import '../core/providers/core_providers.dart';

class GlassNotesApp extends ConsumerStatefulWidget {
  const GlassNotesApp({super.key});

  @override
  ConsumerState<GlassNotesApp> createState() => _GlassNotesAppState();
}

class _GlassNotesAppState extends ConsumerState<GlassNotesApp> {
  @override
  void initState() {
    super.initState();
    // A cold launch from a notification can set the deep link before this
    // widget ever builds, in which case ref.listen would never fire for it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeDeepLink());
  }

  void _consumeDeepLink() {
    final target = ref.read(pendingDeepLinkProvider);
    if (target == null) return;
    ref.read(pendingDeepLinkProvider.notifier).state = null;
    // Never navigate away from the lock screen while the app is locked; the
    // link is dropped rather than leaking content past authentication.
    if (ref.read(needsUnlockProvider)) return;
    ref.read(routerProvider).go(target);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themePref = ref.watch(themeModeProvider);

    ref.listen<String?>(pendingDeepLinkProvider, (previous, next) {
      if (next != null) _consumeDeepLink();
    });

    final mode = switch (themePref) {
      ThemeModePref.light => ThemeMode.light,
      ThemeModePref.dark => ThemeMode.dark,
      ThemeModePref.system => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'Glass Notes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      routerConfig: router,
      builder: (context, child) {
        // Every screen is a CupertinoPageScaffold. Unlike Material's Scaffold,
        // it installs no DefaultTextStyle, so without this each Text would
        // inherit DefaultTextStyle.fallback() — which renders with a yellow
        // double underline and no font family.
        return DefaultTextStyle(
          style: AppTypography.body(Theme.of(context).brightness),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
