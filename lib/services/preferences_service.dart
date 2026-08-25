import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small key/value store for user preferences that must survive a restart.
///
/// Backed by the same secure storage the app-lock flag uses (Keychain on iOS,
/// EncryptedSharedPreferences on Android) so the app needs no extra
/// persistence dependency for a handful of settings.
class PreferencesService {
  const PreferencesService();

  static const _storage = FlutterSecureStorage();
  static const _kThemeMode = 'theme_mode';

  Future<String?> readRaw(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      // Secure storage can be unavailable (locked keystore, first run on a
      // fresh emulator). A missing preference is not an error.
      return null;
    }
  }

  Future<void> writeRaw(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Preference simply won't persist; not worth failing the interaction.
    }
  }

  Future<String?> themeMode() => readRaw(_kThemeMode);

  Future<void> setThemeMode(String value) => writeRaw(_kThemeMode, value);
}
