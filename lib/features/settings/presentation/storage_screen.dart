import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../services/storage_service.dart';

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  StorageBreakdown? _breakdown;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final breakdown = await ref.read(storageServiceProvider).computeBreakdown();
    if (!mounted) return;
    setState(() {
      _breakdown = breakdown;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final storage = ref.read(storageServiceProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Storage')),
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: _loading
              ? const Center(child: CupertinoActivityIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    GlassCard(
                      child: Column(
                        children: [
                          _row('Database', storage.formatBytes(_breakdown!.databaseBytes), brightness),
                          const SizedBox(height: 10),
                          _row('Images', storage.formatBytes(_breakdown!.imageBytes), brightness),
                          const SizedBox(height: 10),
                          _row('Audio', storage.formatBytes(_breakdown!.audioBytes), brightness),
                          const SizedBox(height: 10),
                          _row('Cache', storage.formatBytes(_breakdown!.cacheBytes), brightness),
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            color: AppColors.textSecondary(brightness)
                                .withValues(alpha: 0.2),
                          ),
                          _row('Total', storage.formatBytes(_breakdown!.totalBytes), brightness,
                              bold: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassButton(
                      label: 'Clear Cache',
                      icon: CupertinoIcons.trash,
                      style: GlassButtonStyle.secondary,
                      expand: true,
                      onPressed: () async {
                        await storage.clearCache();
                        await _load();
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, Brightness brightness, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: bold ? AppColors.textPrimary(brightness) : AppColors.textSecondary(brightness),
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
        Text(value,
            style: TextStyle(
                color: AppColors.textPrimary(brightness),
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
      ],
    );
  }
}
