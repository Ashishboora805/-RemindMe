import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../reminders/providers/reminder_providers.dart';
import '../../providers/project_providers.dart';
import '../widgets/project_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final projectsAsync = ref.watch(
        _showArchived ? archivedProjectsProvider : activeProjectsProvider);
    final todayAsync = ref.watch(todayRemindersProvider);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    return CupertinoPageScaffold(
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting,
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary(brightness))),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEEE, MMMM d').format(DateTime.now()),
                              style: TextStyle(color: AppColors.textSecondary(brightness)),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/settings'),
                        child: const GlassIconButton(icon: CupertinoIcons.gear),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: GestureDetector(
                    onTap: () => context.push('/search'),
                    child: GlassCard(
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.search, color: AppColors.textSecondary(brightness)),
                          const SizedBox(width: 10),
                          Text('Search notes, reminders, projects',
                              style: TextStyle(color: AppColors.textSecondary(brightness))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: todayAsync.when(
                    data: (reminders) {
                      if (reminders.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Today",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: AppColors.textPrimary(brightness))),
                          const SizedBox(height: 10),
                          ...reminders.take(4).map((r) => GlassCard(
                                margin: const EdgeInsets.only(bottom: 10),
                                onTap: () => context.push('/reminder/${r.id}'),
                                child: Row(
                                  children: [
                                    const Icon(CupertinoIcons.bell_fill, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(r.title,
                                          style: TextStyle(
                                              color: AppColors.textPrimary(brightness),
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    Text(DateFormat('h:mm a').format(r.scheduledAt),
                                        style: TextStyle(
                                            color: AppColors.textSecondary(brightness))),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_showArchived ? 'Archived' : 'Projects',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: AppColors.textPrimary(brightness))),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                setState(() => _showArchived = !_showArchived),
                            child: GlassIconButton(
                              icon: _showArchived
                                  ? CupertinoIcons.folder
                                  : CupertinoIcons.archivebox,
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => context.push('/projects/create'),
                            child: const GlassIconButton(icon: CupertinoIcons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              projectsAsync.when(
                data: (projects) {
                  if (projects.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            _showArchived
                                ? 'No archived projects.'
                                : 'No projects yet. Tap + to create your first one.',
                            style: TextStyle(color: AppColors.textSecondary(brightness)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    sliver: SliverList.separated(
                      itemCount: projects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => ProjectCard(project: projects[i]),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Could not load projects: $e'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    return GlassCard(
      borderRadius: 14,
      padding: const EdgeInsets.all(10),
      child: Icon(icon, size: 20, color: AppColors.textPrimary(brightness)),
    );
  }
}
