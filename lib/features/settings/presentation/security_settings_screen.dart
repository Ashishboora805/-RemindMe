import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/glass_card.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _enabled = false;
  bool _supported = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authenticationServiceProvider);
    final supported = await auth.isDeviceSupported();
    final enabled = await auth.isAppLockEnabled();
    if (mounted) {
      setState(() {
        _supported = supported;
        _enabled = enabled;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    final auth = ref.read(authenticationServiceProvider);
    if (value) {
      final ok = await auth.authenticate();
      if (!ok) return; // don't enable if the confirming auth fails
    }
    await auth.setAppLockEnabled(value);
    setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Security')),
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: _loading
              ? const Center(child: CupertinoActivityIndicator())
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: GlassCard(
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.lock_shield),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('App Lock', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                _supported
                                    ? 'Require Face ID, Touch ID, or passcode to open the app.'
                                    : 'Biometric authentication is not available on this device.',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary(brightness)),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: _enabled,
                          onChanged: _supported ? _toggle : null,
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
