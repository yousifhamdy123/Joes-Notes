import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'note_editor.dart';

String fmtDate(DateTime d) =>
    DateFormat('d MMM y • h:mm a', Store.i.lang.value).format(d);

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  String _q = '';

  void _open([Note? n]) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NoteEditorPage(note: n)),
      );

  Future<void> _confirmDelete(Note n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('delete_note_q')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('delete'),
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) await Store.i.deleteNote(n.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Store.i, Store.i.lang]),
      builder: (context, _) {
        final q = _q.trim().toLowerCase();
        final notes = Store.i.notes
            .where((n) => q.isEmpty || n.plain.toLowerCase().contains(q))
            .toList();

        Widget body;
        if (notes.isEmpty) {
          body = EmptyState(
              Store.i.notes.isEmpty ? t('no_notes') : t('no_results'));
        } else {
          body = GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 170),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: notes.length,
            itemBuilder: (_, i) => _NoteCard(
              note: notes[i],
              onTap: () => _open(notes[i]),
              onLongPress: () => _confirmDelete(notes[i]),
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
            AddFab(onPressed: () => _open()),
          ],
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                note.plain,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.5, height: 1.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              fmtDate(note.created),
              style: const TextStyle(fontSize: 11, color: kOrange),
            ),
          ],
        ),
      ),
    );
  }
}
