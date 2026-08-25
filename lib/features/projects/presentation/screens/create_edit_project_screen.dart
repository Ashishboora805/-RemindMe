import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/glass_text_field.dart';
import '../../../../database/database.dart';
import '../../providers/project_providers.dart';

class CreateEditProjectScreen extends ConsumerStatefulWidget {
  const CreateEditProjectScreen({super.key, this.projectId});
  final String? projectId;

  @override
  ConsumerState<CreateEditProjectScreen> createState() => _CreateEditProjectScreenState();
}

class _CreateEditProjectScreenState extends ConsumerState<CreateEditProjectScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _colorIndex = 0;
  Project? _editing;

  @override
  void initState() {
    super.initState();
    if (widget.projectId != null) {
      _load();
    }
  }

  Future<void> _load() async {
    final project = await ref.read(databaseProvider).projectsDao.getById(widget.projectId!);
    if (project != null && mounted) {
      setState(() {
        _editing = project;
        _nameCtrl.text = project.name;
        _descCtrl.text = project.description;
        _colorIndex = AppColors.projectAccents
            .indexWhere((c) => c.toARGB32() == project.color);
        if (_colorIndex < 0) _colorIndex = 0;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final controller = ref.read(projectControllerProvider);
    final color = AppColors.projectAccents[_colorIndex].toARGB32();

    if (_editing != null) {
      await controller.update(_editing!.copyWith(
        name: name,
        description: _descCtrl.text.trim(),
        color: color,
      ));
    } else {
      await controller.create(
        name: name,
        description: _descCtrl.text.trim(),
        color: color,
      );
    }
    if (mounted) context.pop();
  }

  Future<void> _toggleArchive() async {
    final project = _editing;
    if (project == null) return;
    await ref
        .read(projectControllerProvider)
        .archive(project.id, !project.isArchived);
    if (mounted) context.pop();
  }

  Future<void> _confirmDelete() async {
    final project = _editing;
    if (project == null) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Delete “${project.name}”?'),
        content: const Text(
          'Every note, reminder, and attachment in this project is deleted '
          'permanently. This cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = ref.read(databaseProvider);

    // Cancel the OS notifications first — a foreign-key cascade drops the
    // reminder rows but the scheduled notifications would survive it.
    final reminderService = ref.read(reminderServiceProvider);
    for (final reminder in await db.remindersDao.forProject(project.id)) {
      await reminderService.deleteReminder(reminder.id);
    }

    // Attachment files live on disk, outside the cascade's reach.
    final attachmentService = ref.read(attachmentServiceProvider);
    for (final note in await db.notesDao.allNotesForProject(project.id)) {
      await attachmentService.deleteAllAttachmentsForNote(note.id);
    }

    await ref.read(projectControllerProvider).delete(project.id);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_editing != null ? 'Edit Project' : 'New Project'),
      ),
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassTextField(controller: _nameCtrl, placeholder: 'Project name', autofocus: true),
              const SizedBox(height: 12),
              GlassTextField(
                controller: _descCtrl,
                placeholder: 'Description (optional)',
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Text('Accent color',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.textPrimary(brightness))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(AppColors.projectAccents.length, (i) {
                  final color = AppColors.projectAccents[i];
                  final selected = i == _colorIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _colorIndex = i),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: CupertinoColors.white, width: 3)
                            : null,
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 10)
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              GlassButton(label: 'Save Project', onPressed: _save, expand: true),
              if (_editing != null) ...[
                const SizedBox(height: 12),
                GlassButton(
                  label: _editing!.isArchived ? 'Unarchive' : 'Archive',
                  icon: CupertinoIcons.archivebox,
                  style: GlassButtonStyle.secondary,
                  expand: true,
                  onPressed: _toggleArchive,
                ),
                const SizedBox(height: 12),
                GlassButton(
                  label: 'Delete Project',
                  icon: CupertinoIcons.delete,
                  style: GlassButtonStyle.destructive,
                  expand: true,
                  onPressed: _confirmDelete,
                ),
                const SizedBox(height: 8),
                Text(
                  'Archiving hides a project from Home but keeps everything in '
                  'it. Deleting removes its notes, reminders, and attachments '
                  'permanently.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary(brightness)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
