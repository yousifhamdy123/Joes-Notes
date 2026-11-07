import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'notes_widgets.dart' show snack;

String _fmtRemind(DateTime d) =>
    DateFormat('d MMM • h:mm a', Store.i.lang.value).format(d);

const _priColors = <int, Color>{
  1: Color(0xFF64B5F6),
  2: Color(0xFFFFB74D),
  3: Color(0xFFE57373),
};

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String _q = '';

  Future<void> _edit([TaskItem? task]) async {
    final result = await showModalBottomSheet<TaskItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _TaskSheet(task: task),
    );
    if (result != null) await Store.i.upsertTask(result);
  }

  Future<void> _toggle(TaskItem task) async {
    final next = await Store.i.toggleTask(task);
    if (next != null && mounted) {
      snack(context, '${t('next_occurrence')}: ${_fmtRemind(next)}');
    }
  }

  int _cmp(TaskItem a, TaskItem b) {
    if (a.priority != b.priority) return b.priority.compareTo(a.priority);
    final ra = a.remind, rb = b.remind;
    if (ra != null && rb != null) return ra.compareTo(rb);
    if (ra != null) return -1;
    if (rb != null) return 1;
    return b.created.compareTo(a.created);
  }

  List<Widget> _section(
      String label, Color color, List<TaskItem> items, Widget Function(TaskItem) tile) {
    if (items.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(width: 8),
            Text('${items.length}',
                style: const TextStyle(fontSize: 12, color: Colors.white38)),
          ],
        ),
      ),
      for (final x in items) ...[tile(x), const SizedBox(height: 10)],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Store.i, Store.i.lang]),
      builder: (context, _) {
        final q = _q.trim().toLowerCase();
        final filtered = Store.i.tasks
            .where((e) =>
                q.isEmpty ||
                e.title.toLowerCase().contains(q) ||
                e.note.toLowerCase().contains(q) ||
                e.subtasks.any((s) => s.title.toLowerCase().contains(q)))
            .toList();

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final open = filtered.where((e) => !e.done).toList();
        final overdue = open
            .where((e) => e.remind != null && e.remind!.isBefore(now))
            .toList()
          ..sort(_cmp);
        final todayList = open
            .where((e) =>
                e.remind != null &&
                !e.remind!.isBefore(now) &&
                e.remind!.isBefore(tomorrow))
            .toList()
          ..sort(_cmp);
        final upcoming = open
            .where((e) => e.remind != null && !e.remind!.isBefore(tomorrow))
            .toList()
          ..sort(_cmp);
        final noDate = open.where((e) => e.remind == null).toList()
          ..sort(_cmp);
        final done = filtered.where((e) => e.done).toList();
        assert(today.isBefore(tomorrow));

        Widget tile(TaskItem x) => _TaskTile(
              task: x,
              onTap: () => _edit(x),
              onToggle: () => _toggle(x),
            );

        Widget body;
        if (filtered.isEmpty) {
          body = EmptyState(
              Store.i.tasks.isEmpty ? t('no_tasks') : t('no_results'));
        } else {
          body = ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 170),
            children: [
              ..._section(t('sec_overdue'), Colors.redAccent, overdue, tile),
              ..._section(t('sec_today'), kOrange, todayList, tile),
              ..._section(
                  t('sec_upcoming'), Colors.white70, upcoming, tile),
              ..._section(t('sec_nodate'), Colors.white54, noDate, tile),
              ..._section(t('completed'), Colors.white38, done, tile),
            ],
          );
        }

        return Stack(
          children: [
            Column(
              children: [
                AppSearchField(onChanged: (v) => setState(() => _q = v)),
                Expanded(child: body),
              ],
            ),
            AddFab(onPressed: () => _edit()),
          ],
        );
      },
    );
  }
}

class _TaskTile extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  const _TaskTile(
      {required this.task, required this.onTap, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final overdue = !task.done &&
        task.remind != null &&
        task.remind!.isBefore(DateTime.now());
    final pri = _priColors[task.priority];
    final subDone = task.subtasks.where((e) => e.done).length;
    return Dismissible(
      key: ValueKey(task.id),
      background: _bg(Alignment.centerLeft),
      secondaryBackground: _bg(Alignment.centerRight),
      onDismissed: (_) => Store.i.deleteTask(task),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: pri ?? kCardBorder, width: pri != null ? 1.4 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: task.done ? kOrange : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kOrange, width: 2),
                    ),
                    child: task.done
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: Colors.black)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: task.done ? 0.45 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          decoration:
                              task.done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (task.note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.note,
                          style: const TextStyle(
                              fontSize: 13.5, color: Colors.white60),
                        ),
                      ],
                      if (task.subtasks.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final st in task.subtasks)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              st.done = !st.done;
                              Store.i.saveTasks();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Icon(
                                    st.done
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    size: 19,
                                    color: st.done ? kOrange : Colors.white38,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      st.title,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: st.done
                                            ? Colors.white38
                                            : Colors.white70,
                                        decoration: st.done
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '$subDone/${task.subtasks.length}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white38),
                          ),
                        ),
                      ],
                      if (task.remind != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.alarm_rounded,
                                size: 15,
                                color: overdue ? Colors.redAccent : kOrange),
                            const SizedBox(width: 4),
                            Text(
                              _fmtRemind(task.remind!),
                              style: TextStyle(
                                fontSize: 12,
                                color: overdue ? Colors.redAccent : kOrange,
                              ),
                            ),
                            if (task.repeat != 'none') ...[
                              const SizedBox(width: 8),
                              Icon(Icons.repeat_rounded,
                                  size: 15, color: kOrange),
                              const SizedBox(width: 3),
                              Text(
                                t('rep_${task.repeat}'),
                                style: TextStyle(fontSize: 12, color: kOrange),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bg(Alignment a) => Container(
        alignment: a,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(18),
        ),
        child:
            const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
      );
}

class _TaskSheet extends StatefulWidget {
  final TaskItem? task;
  const _TaskSheet({this.task});

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  final TextEditingController _newStep = TextEditingController();
  late List<SubTask> _steps;
  DateTime? _remind;
  String _repeat = 'none';
  int _priority = 0;

  @override
  void initState() {
    super.initState();
    final o = widget.task;
    _title = TextEditingController(text: o?.title ?? '');
    _note = TextEditingController(text: o?.note ?? '');
    _remind = o?.remind;
    _repeat = o?.repeat ?? 'none';
    _priority = o?.priority ?? 0;
    _steps = [
      for (final s in o?.subtasks ?? <SubTask>[])
        SubTask(title: s.title, done: s.done),
    ];
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _newStep.dispose();
    super.dispose();
  }

  Future<bool> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _remind ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return false;
    final time = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(_remind ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return false;
    setState(() => _remind =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
    return true;
  }

  Future<void> _chooseRepeat(String r) async {
    if (r != 'none' && _remind == null) {
      if (!await _pickTime()) return;
    }
    setState(() => _repeat = r);
  }

  void _addStep() {
    final v = _newStep.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _steps.add(SubTask(title: v));
      _newStep.clear();
    });
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    _addStep();
    final old = widget.task;
    Navigator.pop(
      context,
      TaskItem(
        id: old?.id ?? Store.newId(),
        notifId: old?.notifId ?? Store.newNotifId(),
        title: title,
        note: _note.text.trim(),
        done: old?.done ?? false,
        remind: _remind,
        repeat: _remind == null ? 'none' : _repeat,
        priority: _priority,
        subtasks: _steps,
        created: old?.created ?? DateTime.now(),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(s,
            style: const TextStyle(fontSize: 12.5, color: Colors.white54)),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.task == null ? t('new_task') : t('edit_task'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: widget.task == null,
              textInputAction: TextInputAction.next,
              decoration: _dec(t('task_title')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              decoration: _dec(t('task_note')),
            ),
            _label(t('subtasks')),
            for (var i = 0; i < _steps.length; i++)
              Row(
                children: [
                  Checkbox(
                    value: _steps[i].done,
                    activeColor: kOrange,
                    checkColor: Colors.black,
                    onChanged: (v) =>
                        setState(() => _steps[i].done = v ?? false),
                  ),
                  Expanded(child: Text(_steps[i].title)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() => _steps.removeAt(i)),
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newStep,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addStep(),
                    decoration: _dec(t('add_subtask')),
                  ),
                ),
                IconButton(
                  onPressed: _addStep,
                  icon: Icon(Icons.add_circle_rounded, color: kOrange),
                ),
              ],
            ),
            _label(t('priority')),
            Wrap(
              spacing: 8,
              children: [
                for (final p in const [0, 1, 2, 3])
                  ChoiceChip(
                    label: Text(t('pri_$p')),
                    avatar: p == 0
                        ? null
                        : CircleAvatar(
                            radius: 6, backgroundColor: _priColors[p]),
                    selected: _priority == p,
                    selectedColor: kOrange.withValues(alpha: 0.35),
                    onSelected: (_) => setState(() => _priority = p),
                  ),
              ],
            ),
            _label(t('reminder')),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: Icon(Icons.alarm_add_rounded, color: kOrange),
                    label: Text(
                      _remind == null
                          ? t('set_reminder')
                          : _fmtRemind(_remind!),
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: kCardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                if (_remind != null)
                  IconButton(
                    tooltip: t('remove_reminder'),
                    onPressed: () => setState(() {
                      _remind = null;
                      _repeat = 'none';
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            _label(t('repeat')),
            Wrap(
              spacing: 8,
              children: [
                for (final r in const ['none', 'daily', 'weekly', 'monthly'])
                  ChoiceChip(
                    label: Text(t('rep_$r')),
                    selected: _repeat == r,
                    selectedColor: kOrange.withValues(alpha: 0.35),
                    onSelected: (_) => _chooseRepeat(r),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: kOrange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(t('save'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
