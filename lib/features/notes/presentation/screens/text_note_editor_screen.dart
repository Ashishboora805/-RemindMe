import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/glass_text_field.dart';
import '../../../../database/database.dart';
import '../../providers/note_providers.dart';

class TextNoteEditorScreen extends ConsumerStatefulWidget {
  const TextNoteEditorScreen({super.key, this.noteId, this.projectId});
  final String? noteId; // editing existing note
  final String? projectId; // creating a new note in this project

  @override
  ConsumerState<TextNoteEditorScreen> createState() => _TextNoteEditorScreenState();
}

class _TextNoteEditorScreenState extends ConsumerState<TextNoteEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  Note? _note;
  Timer? _debounce;
  bool _loading = true;
  String? _error;

  /// True when this screen created the note row itself, so an untouched note
  /// can be discarded instead of littering the project with empty entries.
  bool _createdHere = false;
  bool _deleted = false;

  /// Captured in [initState] so the final flush in [dispose] doesn't have to
  /// touch `ref` after the widget is unmounted.
  late final NoteController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(noteControllerProvider);
    _init();
  }

  Future<void> _init() async {
    try {
      if (widget.noteId != null) {
        final note =
            await ref.read(databaseProvider).notesDao.getById(widget.noteId!);
        if (note == null) {
          _error = 'This note no longer exists.';
        } else {
          _note = note;
          _titleCtrl.text = note.title;
          _contentCtrl.text = note.content;
        }
      } else if (widget.projectId != null) {
        _note = await _controller.create(projectId: widget.projectId!);
        _createdHere = true;
      } else {
        _error = 'No note or project was specified.';
      }
    } catch (e) {
      _error = 'Could not open this note: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _autoSave);
  }

  Future<void> _autoSave() async {
    final note = _note;
    if (note == null) return;
    await _controller.autoSave(
      note.id,
      title: _titleCtrl.text,
      content: _contentCtrl.text,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Final flush save on the way out. Fire-and-forget: SQLite writes here are
    // single-row and the controller outlives this widget.
    final note = _note;
    final isBlank =
        _titleCtrl.text.trim().isEmpty && _contentCtrl.text.trim().isEmpty;
    if (note != null && !_deleted) {
      if (_createdHere && isBlank) {
        // Nothing was ever typed — drop the placeholder row we created on open.
        unawaited(_controller.permanentlyDelete(note.id));
      } else {
        unawaited(_controller.autoSave(
          note.id,
          title: _titleCtrl.text,
          content: _contentCtrl.text,
        ));
      }
    }
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;

    if (_loading) {
      return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text('Note')),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final note = _note;
    if (note == null) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('Note')),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(_error ?? 'Note not found', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Note'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                final newVal = !note.isFavorite;
                await _controller.toggleFavorite(note.id, newVal);
                if (mounted) {
                  setState(() => _note = note.copyWith(isFavorite: newVal));
                }
              },
              child: Icon(
                note.isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                color: CupertinoColors.systemPink,
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () async {
                final newVal = !note.isPinned;
                await _controller.togglePin(note.id, newVal);
                if (mounted) {
                  setState(() => _note = note.copyWith(isPinned: newVal));
                }
              },
              child: Icon(note.isPinned ? CupertinoIcons.pin_fill : CupertinoIcons.pin),
            ),
          ],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassTextField(
                controller: _titleCtrl,
                placeholder: 'Title',
                textStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(brightness)),
                onChanged: _onChanged,
              ),
              const SizedBox(height: 12),
              GlassTextField(
                controller: _contentCtrl,
                placeholder: 'Start writing…',
                maxLines: 16,
                onChanged: _onChanged,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      // Flush first so the reminder attaches to a saved note.
                      await _autoSave();
                      if (!context.mounted) return;
                      context.push(
                          '/reminder/create?projectId=${note.projectId}&noteId=${note.id}');
                    },
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.bell, size: 18),
                        SizedBox(width: 6),
                        Text('Add reminder'),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      _debounce?.cancel();
                      _deleted = true;
                      await _controller.softDelete(note.id);
                      if (context.mounted) context.pop();
                    },
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.delete, size: 18, color: CupertinoColors.systemRed),
                        SizedBox(width: 6),
                        Text('Delete', style: TextStyle(color: CupertinoColors.systemRed)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
