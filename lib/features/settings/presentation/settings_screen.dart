import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/glass_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final themePref = ref.watch(themeModeProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SectionLabel('Appearance', brightness: brightness),
              GlassCard(
                child: Column(
                  children: [
                    CupertinoSlidingSegmentedControl<ThemeModePref>(
                      groupValue: themePref,
                      children: const {
                        ThemeModePref.system: Padding(
                            padding: EdgeInsets.symmetric(vertical: 6), child: Text('System')),
                        ThemeModePref.light: Padding(
                            padding: EdgeInsets.symmetric(vertical: 6), child: Text('Light')),
                        ThemeModePref.dark: Padding(
                            padding: EdgeInsets.symmetric(vertical: 6), child: Text('Dark')),
                      },
                      onValueChanged: (v) => ref
                          .read(themeModeProvider.notifier)
                          .set(v ?? ThemeModePref.system),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel('Data', brightness: brightness),
              _NavRow(
                icon: CupertinoIcons.archivebox,
                label: 'Backup & Restore',
                onTap: () => context.push('/settings/backup'),
              ),
              const SizedBox(height: 10),
              _NavRow(
                icon: CupertinoIcons.chart_pie,
                label: 'Storage',
                onTap: () => context.push('/settings/storage'),
              ),
              const SizedBox(height: 10),
              _NavRow(
                icon: CupertinoIcons.trash,
                label: 'Recently Deleted',
                onTap: () => context.push('/trash'),
              ),
              const SizedBox(height: 20),
              _SectionLabel('Privacy', brightness: brightness),
              _NavRow(
                icon: CupertinoIcons.lock_shield,
                label: 'Security',
                onTap: () => context.push('/settings/security'),
              ),
              const SizedBox(height: 20),
              _SectionLabel('About', brightness: brightness),
              GlassCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Version', style: TextStyle(color: AppColors.textSecondary(brightness))),
                    const Text('1.0.0'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.brightness});
  final String label;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(brightness))),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.textPrimary(brightness)),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Icon(CupertinoIcons.chevron_forward,
              size: 16, color: AppColors.textSecondary(brightness)),
        ],
      ),
    );
  }
}
