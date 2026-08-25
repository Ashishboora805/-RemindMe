import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/projects/presentation/screens/home_screen.dart';
import '../features/projects/presentation/screens/create_edit_project_screen.dart';
import '../features/projects/presentation/screens/project_dashboard_screen.dart';
import '../features/notes/presentation/screens/text_note_editor_screen.dart';
import '../features/notes/presentation/screens/note_detail_screen.dart';
import '../features/notes/presentation/screens/voice_note_recorder_screen.dart';
import '../features/reminders/presentation/screens/reminder_editor_screen.dart';
import '../features/reminders/presentation/screens/reminder_detail_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/trash/presentation/trash_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/backup_screen.dart';
import '../features/settings/presentation/storage_screen.dart';
import '../features/settings/presentation/security_settings_screen.dart';
import 'lock_gate_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    // A stale deep link from a notification must never leave the user on a
    // red error screen.
    errorBuilder: (context, state) => RouteErrorScreen(location: state.uri.toString()),
    redirect: (context, state) {
      final locked = ref.read(needsUnlockProvider);
      final goingToLock = state.matchedLocation == '/lock';
      if (locked && !goingToLock) return '/lock';
      if (!locked && goingToLock) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/lock', builder: (context, state) => const LockGateScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/projects/create',
        builder: (context, state) => const CreateEditProjectScreen(),
      ),
      GoRoute(
        path: '/projects/:id/edit',
        builder: (context, state) =>
            CreateEditProjectScreen(projectId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/projects/:id',
        builder: (context, state) =>
            ProjectDashboardScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/note/create',
        builder: (context, state) => TextNoteEditorScreen(
          projectId: state.uri.queryParameters['projectId'],
        ),
      ),
      GoRoute(
        path: '/note/:id',
        builder: (context, state) => NoteDetailScreen(noteId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/note/:id/edit',
        builder: (context, state) =>
            TextNoteEditorScreen(noteId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/note/:id/voice',
        builder: (context, state) =>
            VoiceNoteRecorderScreen(noteId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/reminder/create',
        builder: (context, state) => ReminderEditorScreen(
          projectId: state.uri.queryParameters['projectId'],
          noteId: state.uri.queryParameters['noteId'],
        ),
      ),
      GoRoute(
        path: '/reminder/:id/edit',
        builder: (context, state) =>
            ReminderEditorScreen(reminderId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/reminder/:id',
        builder: (context, state) =>
            ReminderDetailScreen(reminderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(path: '/trash', builder: (context, state) => const TrashScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/settings/backup', builder: (context, state) => const BackupScreen()),
      GoRoute(path: '/settings/storage', builder: (context, state) => const StorageScreen()),
      GoRoute(
        path: '/settings/security',
        builder: (context, state) => const SecuritySettingsScreen(),
      ),
    ],
  );
});

/// True while the app is locked pending Face ID/passcode. Set at boot from
/// AuthenticationService.isAppLockEnabled(), cleared once authenticate()
/// succeeds (see LockGateScreen).
final needsUnlockProvider = StateProvider<bool>((ref) => false);

/// Shown when a route can't be matched — most often a deep link pointing at a
/// note or reminder that has since been deleted.
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key, required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Not found')),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.question_circle, size: 48),
                const SizedBox(height: 16),
                Text(
                  "We couldn't open “$location”.\n"
                  'It may have been deleted.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                CupertinoButton.filled(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
