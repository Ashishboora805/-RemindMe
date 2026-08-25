import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../services/attachment_service.dart';
import '../../services/reminder_service.dart';
import '../../services/audio_service.dart';
import '../../services/image_service.dart';
import '../../services/authentication_service.dart';
import '../../services/storage_service.dart';
import '../../services/backup_service.dart';
import '../../services/preferences_service.dart';
import '../../services/search_service.dart';

/// Single AppDatabase instance for the app's lifetime.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  return AttachmentService(ref.watch(databaseProvider));
});

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(ref.watch(databaseProvider));
});

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});

final imageServiceProvider = Provider<ImageService>((ref) => ImageService());

final authenticationServiceProvider =
    Provider<AuthenticationService>((ref) => AuthenticationService());

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(attachmentServiceProvider));
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(databaseProvider),
    ref.watch(attachmentServiceProvider),
    ref.watch(reminderServiceProvider),
  );
});

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(ref.watch(databaseProvider));
});

/// Set by the notification tap handler when the app was backgrounded;
/// consumed by the root App widget to navigate once the router is ready.
final pendingDeepLinkProvider = StateProvider<String?>((ref) => null);

final preferencesServiceProvider =
    Provider<PreferencesService>((ref) => const PreferencesService());

enum ThemeModePref { system, light, dark }

/// Theme preference, restored from disk on first read so the user's choice
/// survives an app restart.
class ThemeModeController extends Notifier<ThemeModePref> {
  @override
  ThemeModePref build() {
    // Fire-and-forget restore: the app renders with the system theme for the
    // first frame or two, then settles on the stored preference.
    _restore();
    return ThemeModePref.system;
  }

  Future<void> _restore() async {
    final saved = await ref.read(preferencesServiceProvider).themeMode();
    if (saved == null) return;
    final match = ThemeModePref.values
        .where((v) => v.name == saved)
        .firstOrNull;
    if (match != null && match != state) state = match;
  }

  Future<void> set(ThemeModePref pref) async {
    state = pref;
    await ref.read(preferencesServiceProvider).setThemeMode(pref.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeModePref>(ThemeModeController.new);
