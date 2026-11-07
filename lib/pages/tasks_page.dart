import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';

String _fmtRemind(DateTime d) =>
    DateFormat('d MMM • h:mm a', Store.i.lang.value).format(d);

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
                e.note.toLowerCase().contains(q))
            .toList();
        // Completed tasks sink to the bottom.
        final items = [
          ...filtered.where((e) => !e.done),
          ...filtered.where((e) => e.done),
        ];

        Widget body;
        if (items.isEmpty) {
          body = EmptyState(
              Store.i.tasks.isEmpty ? t('no_tasks') : t('no_results'));
        } else {
          body = ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 170),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _TaskTile(
              task: items[i],
              onTap: () => _edit(items[i]),
            ),
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
  const _TaskTile({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final overdue = !task.done &&
        task.remind != null &&
        task.remind!.isBefore(DateTime.now());
    return Dismissible(
      key: ValueKey(task.id),
      background: _bg(Alignment.centerLeft),
      secondaryBackground: _bg(Alignment.centerRight),
      onDismissed: (_) => Store.i.deleteTask(task),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kCardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Store.i.toggleTask(task),
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
                      if (task.remind != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.alarm_rounded,
                                size: 15,
                                color:
                                    overdue ? Colors.redAccent : kOrange),
                            const SizedBox(width: 4),
                            Text(
                              _fmtRemind(task.remind!),
                              style: TextStyle(
                                fontSize: 12,
                                color: overdue ? Colors.redAccent : kOrange,
                              ),
                            ),
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
        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
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
  DateTime? _remind;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task?.title ?? '');
    _note = TextEditingController(text: widget.task?.note ?? '');
    _remind = widget.task?.remind;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _remind ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_remind ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() => _remind =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
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
        created: old?.created ?? DateTime.now(),
      ),
    );
  }

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
              decoration: InputDecoration(
                hintText: t('task_title'),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: t('task_note'),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.alarm_add_rounded, color: kOrange),
                    label: Text(
                      _remind == null
                          ? t('set_reminder')
                          : _fmtRemind(_remind!),
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kCardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                if (_remind != null)
                  IconButton(
                    tooltip: t('remove_reminder'),
                    onPressed: () => setState(() => _remind = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 16),
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
