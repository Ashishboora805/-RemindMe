import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../database/database.dart';
import '../../providers/project_providers.dart';

class ProjectCard extends ConsumerWidget {
  const ProjectCard({super.key, required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final statsAsync = ref.watch(projectStatsProvider(project.id));
    final accent = Color(project.color);

    return GlassCard(
      accent: accent,
      onTap: () => context.push('/projects/${project.id}'),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(CupertinoIcons.folder_fill, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.textPrimary(brightness))),
                const SizedBox(height: 4),
                statsAsync.when(
                  data: (stats) => Text(
                    '${stats.notesCount} notes · ${stats.pendingReminders} pending',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary(brightness)),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_forward,
              size: 16, color: AppColors.textSecondary(brightness)),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.04, end: 0);
  }
}
