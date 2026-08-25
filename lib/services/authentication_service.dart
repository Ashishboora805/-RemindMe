import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Optional app-lock using the device's own biometrics/passcode (Face ID,
/// Touch ID, or device passcode as fallback). No custom password storage —
/// only the user's on/off preference is persisted, in the iOS Keychain via
/// flutter_secure_storage (section 18).
class AuthenticationService {
  final _localAuth = LocalAuthentication();
  final _secureStorage = const FlutterSecureStorage();
  static const _kAppLockEnabledKey = 'app_lock_enabled';

  Future<bool> isDeviceSupported() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isSupported = await _localAuth.isDeviceSupported();
    return canCheck || isSupported;
  }

  Future<bool> isAppLockEnabled() async {
    final value = await _secureStorage.read(key: _kAppLockEnabledKey);
    return value == 'true';
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    await _secureStorage.write(key: _kAppLockEnabledKey, value: enabled.toString());
  }

  /// Prompts Face ID / Touch ID / device passcode. Returns true only on a
  /// genuine successful authentication — never assume success.
  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock Glass Notes',
        options: const AuthenticationOptions(
          biometricOnly: false, // allows passcode fallback
          stickyAuth: true,
        ),
      );
    } on Exception {
      return false;
    }
  }
}
