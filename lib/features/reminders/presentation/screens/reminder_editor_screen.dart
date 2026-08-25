import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glass_text_field.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/reminders_table.dart';

/// Creates a new reminder, or edits an existing one when [reminderId] is set.
class ReminderEditorScreen extends ConsumerStatefulWidget {
  const ReminderEditorScreen({
    super.key,
    this.projectId,
    this.noteId,
    this.reminderId,
  }) : assert(projectId != null || reminderId != null,
            'Creating a reminder requires a projectId');

  final String? projectId;
  final String? noteId;
  final String? reminderId;

  @override
  ConsumerState<ReminderEditorScreen> createState() => _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends ConsumerState<ReminderEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = _defaultDate();
  String _repeat = RepeatType.none;
  final Set<int> _weekdays = {};
  int _customInterval = 2;
  String _customUnit = 'day';
  String? _error;
  bool _saving = false;
  bool _loading = false;
  Reminder? _editing;

  bool get _isEditing => widget.reminderId != null;

  static DateTime _defaultDate() {
    final next = DateTime.now().add(const Duration(hours: 1));
    // Snap to the minute so the picker and the stored value agree.
    return DateTime(next.year, next.month, next.day, next.hour, next.minute);
  }

  static const _repeatOptions = [
    RepeatType.none,
    RepeatType.daily,
    RepeatType.weekly,
    RepeatType.monthly,
    RepeatType.custom,
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loading = true;
      _load();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final reminder = await ref
        .read(databaseProvider)
        .remindersDao
        .getById(widget.reminderId!);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (reminder == null) {
        _error = 'This reminder no longer exists.';
        return;
      }
      _editing = reminder;
      _titleCtrl.text = reminder.title;
      _descCtrl.text = reminder.description;
      _date = reminder.scheduledAt;
      _repeat = reminder.repeatType;
      _weekdays
        ..clear()
        ..addAll(ref.read(reminderServiceProvider).weekdaysFor(reminder));
      final config = _decodeConfig(reminder.repeatValue);
      if (config != null) {
        _customUnit = config['unit'] as String? ?? 'day';
        _customInterval = (config['interval'] as num?)?.toInt() ?? 2;
      }
    });
  }

  Map<String, dynamic>? _decodeConfig(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDateTime() async {
    var temp = _date;
    // A reminder that already exists may legitimately sit in the past; only
    // clamp the picker when creating a new one.
    final minimum = _isEditing ? null : DateTime.now();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 260,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: minimum != null && _date.isBefore(minimum)
                    ? minimum
                    : _date,
                minimumDate: minimum,
                onDateTimeChanged: (v) => temp = v,
              ),
            ),
            CupertinoButton(
              child: const Text('Done'),
              onPressed: () {
                setState(() => _date = temp);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _buildConfig() {
    if (_repeat == RepeatType.weekly && _weekdays.isNotEmpty) {
      return {'weekdays': (_weekdays.toList()..sort())};
    }
    if (_repeat == RepeatType.custom) {
      return {'unit': _customUnit, 'interval': _customInterval};
    }
    return null;
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a title.');
      return;
    }
    final service = ref.read(reminderServiceProvider);
    final validationError =
        service.validate(scheduledAt: _date, repeatType: _repeat);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    final granted = await service.ensurePermission();
    final config = _buildConfig();

    try {
      if (_isEditing) {
        await service.updateReminder(
          reminderId: widget.reminderId!,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          scheduledAt: _date,
          repeatType: _repeat,
          repeatConfig: config,
          clearRepeatConfig: config == null,
        );
      } else {
        await service.createReminder(
          projectId: widget.projectId!,
          noteId: widget.noteId,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          scheduledAt: _date,
          repeatType: _repeat,
          repeatConfig: config,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this reminder: $e';
      });
      return;
    }

    if (!mounted) return;
    if (!granted) {
      // The reminder is safely stored either way; be honest that the OS will
      // not actually alert until notifications are enabled in Settings.
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Reminder saved'),
          content: const Text(
            'Notifications are turned off for Glass Notes, so this reminder '
            'will not alert you until you enable them in system Settings.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? 'Edit Reminder' : 'New Reminder'),
      ),
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: _loading
              ? const Center(child: CupertinoActivityIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    GlassTextField(
                      controller: _titleCtrl,
                      placeholder: 'Reminder title',
                      autofocus: !_isEditing,
                    ),
                    const SizedBox(height: 12),
                    GlassTextField(
                        controller: _descCtrl,
                        placeholder: 'Description',
                        maxLines: 3),
                    const SizedBox(height: 16),
                    GlassCard(
                      onTap: _pickDateTime,
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.calendar),
                          const SizedBox(width: 10),
                          Text(DateFormat('EEE, MMM d · h:mm a').format(_date)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Repeat',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(brightness))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _repeatOptions.map((r) {
                        final selected = _repeat == r;
                        return GestureDetector(
                          onTap: () => setState(() => _repeat = r),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.projectAccents.first
                                  : AppColors.glassFill(brightness),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _label(r),
                              style: TextStyle(
                                color: selected
                                    ? CupertinoColors.white
                                    : AppColors.textPrimary(brightness),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_repeat == RepeatType.weekly) ...[
                      const SizedBox(height: 14),
                      Text('On these days',
                          style:
                              TextStyle(color: AppColors.textSecondary(brightness))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: List.generate(7, (i) {
                          final weekday = i + 1;
                          final selected = _weekdays.contains(weekday);
                          return GestureDetector(
                            onTap: () => setState(() {
                              if (selected) {
                                _weekdays.remove(weekday);
                              } else {
                                _weekdays.add(weekday);
                              }
                            }),
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? AppColors.projectAccents.first
                                    : AppColors.glassFill(brightness),
                              ),
                              child: Text(
                                _weekdayLetter(weekday),
                                style: TextStyle(
                                  color: selected
                                      ? CupertinoColors.white
                                      : AppColors.textPrimary(brightness),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      if (_weekdays.isEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'No days picked — this repeats weekly on '
                          '${_fullWeekdayName(_date.weekday)}.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(brightness)),
                        ),
                      ],
                    ],
                    if (_repeat == RepeatType.custom) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text('Every',
                              style: TextStyle(
                                  color: AppColors.textSecondary(brightness))),
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => setState(() => _customInterval =
                                _customInterval > 1 ? _customInterval - 1 : 1),
                            child: const Icon(CupertinoIcons.minus_circle),
                          ),
                          Text('$_customInterval'),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => setState(() => _customInterval += 1),
                            child: const Icon(CupertinoIcons.plus_circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CupertinoSlidingSegmentedControl<String>(
                              groupValue: _customUnit,
                              children: const {
                                'day': Padding(
                                    padding: EdgeInsets.all(6), child: Text('Days')),
                                'week': Padding(
                                    padding: EdgeInsets.all(6), child: Text('Weeks')),
                              },
                              onValueChanged: (v) =>
                                  setState(() => _customUnit = v ?? 'day'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    ],
                    const SizedBox(height: 28),
                    GlassButton(
                      label: _saving
                          ? 'Saving…'
                          : (_isEditing ? 'Save Changes' : 'Save Reminder'),
                      onPressed:
                          _saving || (_isEditing && _editing == null) ? null : _save,
                      expand: true,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _label(String r) {
    switch (r) {
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthly:
        return 'Monthly';
      case RepeatType.custom:
        return 'Custom';
      case RepeatType.none:
      default:
        return 'Once';
    }
  }

  String _weekdayLetter(int weekday) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return letters[weekday - 1];
  }

  String _fullWeekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return names[weekday - 1];
  }
}
