import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/widgets/glass_bottom_sheet.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../database/tables/notes_table.dart';
import '../../../notes/providers/note_providers.dart';
import '../../../notes/presentation/widgets/note_card.dart';
import '../../../reminders/providers/reminder_providers.dart';
import '../../../reminders/presentation/widgets/reminder_card.dart';
import '../../providers/project_providers.dart';

enum _DashTab { all, notes, reminders, completed }

class ProjectDashboardScreen extends ConsumerStatefulWidget {
  const ProjectDashboardScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<ProjectDashboardScreen> createState() => _ProjectDashboardScreenState();
}

class _ProjectDashboardScreenState extends ConsumerState<ProjectDashboardScreen> {
  _DashTab _tab = _DashTab.all;

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final projectAsync = ref.watch(projectByIdProvider(widget.projectId));
    final statsAsync = ref.watch(projectStatsProvider(widget.projectId));
    final notesAsync = ref.watch(notesForProjectProvider(widget.projectId));
    final pendingAsync = ref.watch(pendingRemindersForProjectProvider(widget.projectId));
    final completedAsync = ref.watch(completedRemindersForProjectProvider(widget.projectId));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: projectAsync.when(
          data: (p) => Text(p?.name ?? ''),
          loading: () => const Text(''),
          error: (_, __) => const Text(''),
        ),
        trailing: GestureDetector(
          onTap: () => context.push('/projects/${widget.projectId}/edit'),
          child: const Icon(CupertinoIcons.ellipsis_circle),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: statsAsync.when(
                      data: (stats) => GlassCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _Stat(label: 'Notes', value: stats.notesCount, brightness: brightness),
                            _Stat(
                                label: 'Pending',
                                value: stats.pendingReminders,
                                brightness: brightness),
                            _Stat(
                                label: 'Completed',
                                value: stats.completedReminders,
                                brightness: brightness),
                          ],
                        ),
                      ),
                      loading: () => const SizedBox(height: 60),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: CupertinoSlidingSegmentedControl<_DashTab>(
                      groupValue: _tab,
                      children: const {
                        _DashTab.all: Padding(
                            padding: EdgeInsets.symmetric(vertical: 6), child: Text('All')),
                        _DashTab.notes: Padding(
                            padding: EdgeInsets.symmetric(vertical: 6), child: Text('Notes')),
                        _DashTab.reminders: Padding(
                            padding: EdgeInsets.symmetric(vertical: 6), child: Text('Reminders')),
                        _DashTab.completed: Padding(
                            padding: EdgeInsets.symmetric(vertical: 6), child: Text('Done')),
                      },
                      onValueChanged: (v) => setState(() => _tab = v ?? _DashTab.all),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      children: [
                        if (_tab == _DashTab.all || _tab == _DashTab.notes)
                          notesAsync.when(
                            data: (notes) =>
                                Column(children: notes.map((n) => NoteCard(note: n)).toList()),
                            loading: () => const CupertinoActivityIndicator(),
                            error: (e, _) => Text('Error: $e'),
                          ),
                        if (_tab == _DashTab.all || _tab == _DashTab.reminders)
                          pendingAsync.when(
                            data: (list) => Column(
                                children: list.map((r) => ReminderCard(reminder: r)).toList()),
                            loading: () => const CupertinoActivityIndicator(),
                            error: (e, _) => Text('Error: $e'),
                          ),
                        if (_tab == _DashTab.completed)
                          completedAsync.when(
                            data: (list) => Column(
                                children: list.map((r) => ReminderCard(reminder: r)).toList()),
                            loading: () => const CupertinoActivityIndicator(),
                            error: (e, _) => Text('Error: $e'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 20,
                bottom: 20,
                child: GestureDetector(
                  onTap: () => _showCreateSheet(context),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.projectAccents.first,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.projectAccents.first
                              .withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.add, color: CupertinoColors.white, size: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showGlassBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetOption(
            icon: CupertinoIcons.doc_text_fill,
            label: 'Text Note',
            onTap: () {
              Navigator.pop(ctx);
              context.push('/note/create?projectId=${widget.projectId}');
            },
          ),
          _SheetOption(
            icon: CupertinoIcons.photo_fill,
            label: 'Image Note',
            onTap: () async {
              Navigator.pop(ctx);
              final note =
                  await ref.read(noteControllerProvider).create(
                        projectId: widget.projectId,
                        type: NoteType.image,
                      );
              if (context.mounted) context.push('/note/${note.id}');
            },
          ),
          _SheetOption(
            icon: CupertinoIcons.mic_fill,
            label: 'Voice Note',
            onTap: () async {
              Navigator.pop(ctx);
              final note = await ref.read(noteControllerProvider).create(
                    projectId: widget.projectId,
                    type: NoteType.voice,
                  );
              if (context.mounted) context.push('/note/${note.id}/voice');
            },
          ),
          _SheetOption(
            icon: CupertinoIcons.bell_fill,
            label: 'Reminder',
            onTap: () {
              Navigator.pop(ctx);
              context.push('/reminder/create?projectId=${widget.projectId}');
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.brightness});
  final String label;
  final int value;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary(brightness))),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(brightness))),
      ],
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.textPrimary(brightness)),
          const SizedBox(width: 14),
          Text(label,
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary(brightness))),
        ],
      ),
    );
  }
}
